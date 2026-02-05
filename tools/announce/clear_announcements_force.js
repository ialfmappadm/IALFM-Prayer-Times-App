// tools/announce/clear_announcements_force.js
// One-click hard reset for announcements in Remote Config.
// - Wipes BOTH unprefixed and prefixed (e.g., ABC_) announcement keys.
// - Publishes a single placeholder ("No new announcements to display").
// - Sets announcements_json="[]" to avoid list rendering duplicates.
// - Optionally sends an FCM data message with ann_fp so devices refresh.
//
// Usage (from tools/announce):
//   node clear_announcements_force.js --tz=America/Chicago --stamp-via-shell --notify --topic=allUsers
//   node clear_announcements_force.js --prefix=ABC_ --tz=America/Chicago --stamp-via-shell
//   node clear_announcements_force.js --no-prefix         # only unprefixed keys
//   node clear_announcements_force.js --blank-card        # show nothing (active=false)
//   node clear_announcements_force.js --list-only         # just list matching keys
//
// Auth:
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secrets/ialfm-admin.json"
//   export GOOGLE_CLOUD_PROJECT="ialfm-prayer-times"
//
// Requirements (already present in this module): firebase-admin, commander, dotenv

import 'dotenv/config';
import { Command } from 'commander';
import admin from 'firebase-admin';
import fsSync from 'node:fs';
import { execFileSync } from 'node:child_process';

const program = new Command()
  .option('--project <id>', 'GCP/Firebase projectId', process.env.GOOGLE_CLOUD_PROJECT || '')
  .option('--prefix <pfx>', 'RC key prefix to also clean (e.g., ABC_)', 'ABC_')
  .option('--no-prefix', 'Do NOT touch the prefix space; only unprefixed keys', false)
  .option('--tz <tz>', 'IANA TZ for stamping NOW', 'America/Chicago')
  .option('--stamp-via-shell', 'Use TZ=<tz> date +%Y-%m-%dT%H:%M:%S%z', false)
  .option('--notify', 'Send FCM data (ann_fp) to devices after wipe', false)
  .option('--topic <t>', 'FCM topic', 'allUsers')
  .option('--blank-card', 'Publish no visible card (active=false, empty title/text)', false)
  .option('--list-only', 'Only list matching keys; do not publish', false)
  .option('--dry-run', 'Print actions; no publish and no FCM', false)
  .parse(process.argv);

const {
  project, prefix, noPrefix, tz, stampViaShell, notify, topic, blankCard, listOnly, dryRun,
} = program.opts();

// ---- Admin init (prefer SA JSON) ----
function initAdmin(projectId) {
  if (admin.apps.length) return;
  let credential;
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (saPath && fsSync.existsSync(saPath)) {
    try {
      const raw = JSON.parse(fsSync.readFileSync(saPath, 'utf8'));
      if (raw.type === 'service_account') credential = admin.credential.cert(raw);
    } catch (_) {}
  }
  if (!credential) credential = admin.credential.applicationDefault();
  admin.initializeApp({ credential, projectId: projectId || process.env.GOOGLE_CLOUD_PROJECT || undefined });
}

// ---- Time stamps ----
function shellStamp(tz) {
  const out = execFileSync('date', ['+%Y-%m-%dT%H:%M:%S%z'], { env: { ...process.env, TZ: tz } })
    .toString().trim();
  return out.replace(/([+-]\d{2})(\d{2})$/, '$1:$2'); // -0600 -> -06:00
}
function jsStampInTz(tz) {
  const now = new Date();
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  }).formatToParts(now).map(p => [p.type, p.value]));
  const y = +parts.year, m = +parts.month, d = +parts.day;
  const hh = +parts.hour, mm = +parts.minute, ss = +parts.second;
  const tzDate = new Date(Date.UTC(y, m - 1, d, hh, mm, ss));
  const diffMin = Math.round((tzDate.getTime() - now.getTime()) / 60000);
  const sign = diffMin >= 0 ? '+' : '-';
  const offH = String(Math.floor(Math.abs(diffMin) / 60)).padStart(2, '0');
  const offM = String(Math.abs(diffMin) % 60).padStart(2, '0');
  return `${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}T` +
         `${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}:${String(ss).padStart(2,'0')}` +
         `${sign}${offH}:${offM}`;
}
function nowStamp(tz, viaShell) {
  try { return viaShell ? shellStamp(tz) : jsStampInTz(tz); }
  catch { return new Date().toISOString(); }
}

// ---- Matchers for announcement-ish keys ----
function buildMatchers(pfx) {
  const unpref = [
    /^announcement_/i,
    /^announcements_/i,
    /^ann_fp$/i,
    /^announcements_version$/i,
  ];
  const withPfx = [
    new RegExp(`^${pfx}announcement_`, 'i'),
    new RegExp(`^${pfx}announcements_`, 'i'),
    new RegExp(`^${pfx}ann_fp$`, 'i'),
    new RegExp(`^${pfx}announcements_version$`, 'i'),
  ];
  return { unpref, withPfx };
}
function isMatch(name, sets, includePrefixed) {
  if (sets.unpref.some(rx => rx.test(name))) return true;
  if (includePrefixed && sets.withPfx.some(rx => rx.test(name))) return true;
  return false;
}

// ---- List / Wipe / Set ----
async function listMatches(rc, sets, includePrefixed) {
  const tpl = await rc.getTemplate();
  const names = Object.keys(tpl.parameters ?? {});
  const hits = names.filter(n => isMatch(n, sets, includePrefixed));
  return { names, hits };
}

async function wipeAndSet(rc, sets, includePrefixed, stamp) {
  let tpl = await rc.getTemplate();
  const params = tpl.parameters ?? {};
  const before = Object.keys(params).length;

  // Remove all matching keys
  let removed = 0;
  for (const k of Object.keys(params)) {
    if (isMatch(k, sets, includePrefixed)) {
      delete params[k];
      removed++;
    }
  }

  // Build placeholder (single-card) + empty list
  const put = (k, v) => { params[k] = { defaultValue: { value: String(v) } }; };
  const fp = `clear-${stamp.replace(/[^0-9T:-]/g,'')}`;

  // Unprefixed
  put('announcements_json', '[]');
  put('announcements_version', fp);
  put('ann_fp', fp);
  if (blankCard) {
    put('announcement_active', 'false');
    put('announcement_title', '');
    put('announcement_text',  '');
    put('announcement_published_at', stamp);
  } else {
    put('announcement_active', 'true');
    put('announcement_title', 'No new announcements to display');
    put('announcement_text',  '');
    put('announcement_published_at', stamp);
  }

  // Prefixed (optional)
  if (includePrefixed) {
    put(`${prefix}announcements_json`, '[]');
    put(`${prefix}announcements_version`, fp);
    put(`${prefix}ann_fp`, fp);
    if (blankCard) {
      put(`${prefix}announcement_active`, 'false');
      put(`${prefix}announcement_title`, '');
      put(`${prefix}announcement_text`,  '');
      put(`${prefix}announcement_published_at`, stamp);
    } else {
      put(`${prefix}announcement_active`, 'true');
      put(`${prefix}announcement_title`, 'No new announcements to display');
      put(`${prefix}announcement_text`,  '');
      put(`${prefix}announcement_published_at`, stamp);
    }
  }

  tpl.parameters = params;

  if (dryRun) {
    return { removed, fp, version: 'dry-run' };
  }
  tpl = await rc.validateTemplate(tpl);
  const res = await rc.publishTemplate(tpl);
  return { removed, fp, version: res.versionNumber };
}

async function notifyDevices(annFp, topic) {
  const id = await admin.messaging().send({
    topic,
    data: { ann_fp: String(annFp), clear: 'true' },
    android: { priority: 'high' },
    apns: { headers: { 'apns-push-type': 'background' },
            payload: { aps: { 'content-available': 1 } } },
  });
  console.log(`[clear] FCM data sent → ${id} (topic=${topic}, ann_fp=${annFp})`);
}

// ---- main ----
(async function main() {
  initAdmin(project);
  const stamp = nowStamp(tz, stampViaShell);
  const includePrefixed = !noPrefix;

  console.log(`[clear] Project=${project || process.env.GOOGLE_CLOUD_PROJECT || '(from ADC)'} ` +
              `prefix="${prefix}" includePrefixed=${includePrefixed} blankCard=${!!blankCard} dryRun=${!!dryRun}`);

  const rc = admin.remoteConfig();
  const sets = buildMatchers(prefix);

  // 1) List what matches (so you can see which keys are present)
  const { hits } = await listMatches(rc, sets, includePrefixed);
  console.log(`[clear] Matching keys (${hits.length}): ${hits.length ? hits.join(', ') : '(none)'}`);

  if (listOnly) {
    console.log('[clear] --list-only set; exiting.');
    return;
  }

  // 2) Wipe & set placeholder
  const { removed, fp, version } = await wipeAndSet(rc, sets, includePrefixed, stamp);
  console.log(`[clear] RC removed=${removed}; published version=${version}; ann_fp=${fp}`);

  // 3) Optional notify
  if (notify && !dryRun) {
    await notifyDevices(fp, topic);
  }

  console.log('[clear] Done.');
})().catch(e => { console.error('[clear] ERROR:', e); process.exit(1); });