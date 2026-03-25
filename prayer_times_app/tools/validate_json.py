#!/usr/bin/env python3
"""
validate_json.py — IALFM schedule validator (Python 3.7+)

Validates local JSON schedule files (and optional Firebase Storage file).
Checks:
  • JSON structure: array of day objects with "date" and "prayers"
  • Date format: YYYY-MM-DD, duplicates, rough ordering & span
  • Prayer keys: fajr, dhuhr, asr, maghrib, isha; each has "begin"/"iqamah"
  • Time format: strictly HH:mm (24h)
  • Plausible begin-time windows per prayer (configurable)
  • iqamah >= begin; and iqamah not excessively delayed
  • Empty iqamah: WARN (or ERROR with --no-empty-iqamah)
  • "Obviously wrong" times (00:00, 24:00), and suspicious 12:00
  • Optional: fetch & validate remote file from Firebase Storage
"""

import sys, json, re, os, shutil, subprocess, tempfile
from datetime import datetime

GREEN = "\033[92m"; YELLOW = "\033[93m"; RED = "\033[91m"; DIM = "\033[2m"; RESET = "\033[0m"
PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
TIME_RE = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")  # strict HH:mm

# Plausible begin-time windows (minutes after midnight)
PRAYER_WINDOWS = {
    "fajr":    (240,   8*60 + 10),  # 04:00–08:10
    "dhuhr":   (11*60, 14*60 + 30), # 11:00–14:30
    "asr":     (14*60, 19*60),      # 14:00–19:00
    "maghrib": (16*60, 22*60),      # 16:00–22:00
    "isha":    (18*60, 24*60 - 1),  # 18:00–23:59
}

# Maximum allowed delay from adhan (begin) to iqamah (minutes)
MAX_DELAY_MIN = {
    "fajr": 120, "dhuhr": 120, "asr": 150, "maghrib": 45, "isha": 180,
}

def eprint(*a): print(*a, file=sys.stderr)
def ok(msg): print(f"{GREEN}✔{RESET} {msg}")
def warn(msg): print(f"{YELLOW}• WARN{RESET} {msg}")
def fail(msg): eprint(f"{RED}✖ FAIL{RESET} {msg}")

def parse_date(s):
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except Exception:
        return None

def is_time_strict(hhmm): return bool(TIME_RE.match(hhmm))
def to_minutes(hhmm): h, m = hhmm.split(":"); return int(h)*60 + int(m)
def in_window(prayer, hhmm):
    mins = to_minutes(hhmm); lo, hi = PRAYER_WINDOWS[prayer]; return lo <= mins <= hi

def validate_file(path, treat_empty_iqamah_as_error=False, expect_full_year=True):
    try:
        data = json.load(open(path, "r", encoding="utf-8"))
    except Exception as ex:
        fail(f"{path}: invalid JSON: {ex}"); return False

    if not isinstance(data, list) or not data:
        fail(f"{path}: expected a non-empty array of day objects"); return False

    dates, seen = [], set()
    errors = warns = blanks = 0

    for idx, day in enumerate(data, 1):
        date = day.get("date")
        if not isinstance(date, str):
            errors += 1; fail(f"{path}: record #{idx} missing 'date' string"); continue
        d = parse_date(date)
        if not d:
            errors += 1; fail(f"{path}: bad 'date' at #{idx}: {date} (YYYY-MM-DD)"); continue
        if date in seen:
            errors += 1; fail(f"{path}: duplicate date {date}")
        seen.add(date); dates.append(d)

        prayers = day.get("prayers", {})
        if not isinstance(prayers, dict):
            errors += 1; fail(f"{path}: 'prayers' must be an object for {date}"); continue

        for p in PRAYERS:
            item = prayers.get(p, {})
            if not isinstance(item, dict):
                errors += 1; fail(f"{path}: 'prayers.{p}' must be an object for {date}"); continue
            begin = item.get("begin", ""); iqamah = item.get("iqamah", "")

            if begin == "" or not is_time_strict(begin):
                errors += 1; fail(f"{path}: {date} '{p}.begin' invalid or empty (HH:mm)")
            if iqamah != "" and not is_time_strict(iqamah):
                errors += 1; fail(f"{path}: {date} '{p}.iqamah' invalid '{iqamah}' (HH:mm)")

            if begin in ("00:00", "24:00"): errors += 1; fail(f"{path}: {date} '{p}.begin'={begin} not plausible")
            if iqamah in ("00:00", "24:00"): errors += 1; fail(f"{path}: {date} '{p}.iqamah'={iqamah} not plausible")

            if begin == "12:00" and p != "dhuhr":
                warns += 1; warn(f"{path}: {date} '{p}.begin' = 12:00 looks suspicious")

            if is_time_strict(begin) and not in_window(p, begin):
                errors += 1; fail(f"{path}: {date} '{p}.begin'={begin} outside plausible window for {p}")

            if iqamah == "":
                blanks += 1
                if treat_empty_iqamah_as_error:
                    errors += 1; fail(f"{path}: {date} '{p}.iqamah' empty (blocked by --no-empty-iqamah)")
                else:
                    warns += 1; warn(f"{path}: {date} '{p}.iqamah' empty (allowed; unset)")
            else:
                if is_time_strict(begin) and is_time_strict(iqamah):
                    b, q = to_minutes(begin), to_minutes(iqamah)
                    if q < b:
                        errors += 1; fail(f"{path}: {date} '{p}.iqamah'({iqamah}) earlier than begin({begin})")
                    else:
                        if (q - b) > MAX_DELAY_MIN[p]:
                            warns += 1; warn(f"{path}: {date} '{p}.iqamah'({iqamah}) {q-b} min after begin({begin}); "
                                             f"exceeds typical {MAX_DELAY_MIN[p]} for {p}")

    if dates:
        sorted_dates = sorted(dates)
        if dates != sorted_dates: warns += 1; warn(f"{path}: dates not strictly sorted; consider sorting")
        year = sorted_dates[0].year
        if expect_full_year:
            if not all(d.year == year for d in dates):
                warns += 1; warn(f"{path}: mixed years detected (first year={year})")
            if sorted_dates[0].month > 1 or sorted_dates[-1].month < 12:
                warns += 1; warn(f"{path}: does not span roughly a full year (first={sorted_dates[0]}, last={sorted_dates[-1]})")

    if errors == 0:
        ok(f"{path}: PASSED — structure & times look good")
        if blanks > 0: print(f"{DIM}   info: {blanks} blank iqamah values (treated as unset){RESET}")
        return True
    else:
        fail(f"{path}: FAILED — {errors} error(s){' and ' + str(warns) + ' warn(s)' if warns else ''}")
        return False


# -------- Remote fetch (gsutil or firebase-tools) --------

def which(cmd): return shutil.which(cmd)

def download_from_storage(bucket, obj, dest):
    obj = re.sub(r"/{2,}", "/", obj.strip("/"))
    gs = which("gsutil")
    if gs:
        try:
            subprocess.run([gs, "cp", f"gs://{bucket}/{obj}", dest],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception:
            pass
    fb = which("firebase")
    if fb:
        try:
            subprocess.run([fb, "storage:download", "--bucket", bucket, obj, dest],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception:
            pass
    return False


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Validate local and (optionally) Firebase Storage schedule JSON.")
    parser.add_argument("--local", nargs="*", help="Local JSON file(s) (e.g., assets/data/prayer_times_2026.json)")
    parser.add_argument("--bucket", help="Firebase Storage bucket (e.g., ialfm-prayer-times.firebasestorage.app)")
    parser.add_argument("--year", type=int, help="Year for remote canary (e.g., 2026)")
    parser.add_argument("--object", help="Override remote object path (default: prayer_times/<YEAR>.json)")
    parser.add_argument("--no-empty-iqamah", action="store_true", help="Treat empty iqamah as ERROR instead of WARN")
    args = parser.parse_args()

    passed = True

    # Local checks
    if args.local:
        for path in args.local:
            if not os.path.isfile(path):
                fail(f"Local file not found: {path}"); passed = False
            else:
                if not validate_file(path, treat_empty_iqamah_as_error=args.no_empty_iqamah):
                    passed = False
    else:
        warn("No --local files supplied")

    # Remote (optional)
    if args.bucket and (args.year or args.object):
        obj = args.object if args.object else f"prayer_times/{args.year}.json"
        tmpdir = tempfile.mkdtemp(prefix="validate_json_")
        dest = os.path.join(tmpdir, f"remote_{os.path.basename(obj)}")
        print(f"{DIM}Attempting remote fetch: gs://{args.bucket}/{obj}{RESET}")
        if download_from_storage(args.bucket, obj, dest) and os.path.isfile(dest):
            ok(f"Downloaded remote: gs://{args.bucket}/{obj}")
            if not validate_file(dest, treat_empty_iqamah_as_error=args.no_empty_iqamah):
                passed = False
        else:
            warn(f"Remote not found or cannot download (OK if canary is optional): gs://{args.bucket}/{obj}")
    elif args.bucket or args.year or args.object:
        warn("Remote check requested but missing --bucket or --year/--object; skipping")

    sys.exit(0 if passed else 1)

if __name__ == "__main__":
    main()