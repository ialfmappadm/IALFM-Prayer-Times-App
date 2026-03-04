// tools/announce/publish_and_notify.js
// Minimal, clean publisher: writes ONLY unprefixed announcements_json + ann_fp.
// - Auto-fills published_at (America/Chicago by default) when missing
// - Disables single-card fields (announcement_active=false)
// - Optional: FCM data push if --topic is given
//
// Usage:
//   node publish_and_notify.js \
//     --file tools/announce/single_announcement.json \
//     --project ialfm-prayer-times \
//     --tz America/Chicago \
//     --topic allUsers          # optional (sends FCM)
//
// Auth (recommended):
//   export GOOGLE_APPLICATION_CREDENTIALS="$PWD/tools/announce/ialfm-admin.json"
//   export GOOGLE_CLOUD_PROJECT="ialfm-prayer-times"

import { readFile } from 'node:fs/promises';
import crypto from 'node:crypto';
import process from 'node:process';

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getRemoteConfig } from 'firebase-admin/remote-config';
import { getMessaging } from 'firebase-admin/messaging';

// --- tiny arg helpers (no external deps) ---
function getArg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && i + 1 < process.argv.length ? process.argv[i + 1] : def;
}
const file    = getArg('file', '');
const project = getArg('project', process.env.GOOGLE_CLOUD_PROJECT || '');
const tz      = getArg('tz', 'America/Chicago');
const topic   = getArg('topic', ''); // optional

if (!file)    { console.error('[publish] Missing --file <path>'); process.exit(2); }
if (!project) { console.error('[publish] Missing --project <id> or $GOOGLE_CLOUD_PROJECT'); process.exit(2); }

// --- admin init (ADC: service-account JSON via env is preferred) ---
initializeApp({
  credential: applicationDefault(),
  projectId: project,
});

// --- time + fingerprint helpers ---
function nowStamp(tz) {
  try {
    const now = new Date();
    const fmt = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
    });
    const parts = Object.fromEntries(fmt.formatToParts(now).map(p => [p.type, p.value]));
    const y = +parts.year, m = +parts.month, d = +parts.day;
    const hh = +parts.hour, mm = +parts.minute, ss = +parts.second;
    // Build an ISO-like string with a best-effort offset (for display only)
    const tzDate = new Date(Date.UTC(y, m - 1, d, hh, mm, ss));
    const diffMin = Math.round((tzDate.getTime() - now.getTime()) / 60000);
    const sign = diffMin >= 0 ? '+' : '-';
    const offH = String(Math.floor(Math.abs(diffMin) / 60)).padStart(2, '0');
    const offM = String(Math.abs(diffMin) % 60).padStart(2, '0');
    return `${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}T${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}:${String(ss).padStart(2,'0')}${sign}${offH}:${offM}`;
  } catch {
    return new Date().toISOString();
  }
}
function fpFrom(obj) {
  const s = JSON.stringify(obj);
  return crypto.createHash('sha256').update(s).digest('hex').slice(0, 12);
}
function withPublishedAt(arr, stamp) {
  return arr.map((it) => {
    const obj = (it && typeof it === 'object') ? { ...it } : {};
    if (!obj.published_at || String(obj.published_at).trim() === '') {
      obj.published_at = stamp; // consistent batch time
    }
    return obj;
  });
}

// --- main ---
(async () => {
  // 1) Load the JSON array
  const raw = await readFile(file, 'utf8');
  let arr;
  try {
    arr = JSON.parse(raw);
  } catch (e) {
    console.error('[publish] JSON parse error:', e.message);
    process.exit(2);
  }
  if (!Array.isArray(arr) || arr.length === 0) {
    console.error('[publish] File must contain a non-empty JSON array:', file);
    process.exit(2);
  }

  // 2) Stamp missing published_at and fingerprint
  const stamp  = nowStamp(tz);
  const arrOut = withPublishedAt(arr, stamp);
  const annFp  = fpFrom(arrOut);

  // 3) Publish Remote Config parameters (ONLY the unprefixed keys your app reads)
  const rc = getRemoteConfig();
  let tpl  = await rc.getTemplate();
  const p  = tpl.parameters ?? {};

  p['announcements_json']        = { defaultValue: { value: JSON.stringify(arrOut) } };
  p['ann_fp']                    = { defaultValue: { value: annFp } };
  p['announcements_version']     = { defaultValue: { value: annFp } };
  p['announcement_active']       = { defaultValue: { value: 'false' } };
  p['announcement_title']        = { defaultValue: { value: '' } };
  p['announcement_text']         = { defaultValue: { value: '' } };
  p['announcement_published_at'] = { defaultValue: { value: stamp } };

  tpl.parameters = p;
  tpl = await rc.validateTemplate(tpl);
  const res = await rc.publishTemplate(tpl);
  const version = res?.versionNumber || res?.version?.versionNumber || '(unknown)';

  console.log(`[publish] RC published version=${version}; ann_fp=${annFp}`);
  console.log('[publish] announcements_json.length =', JSON.stringify(arrOut).length);

  // 4) Optional FCM notify (data-only, iOS background)
  if (topic) {
    const id = await getMessaging().send({
      topic,
      data: { ann_fp: String(annFp), ann_count: String(arrOut.length) },
      // iOS silent/background requirements:
      apns: {
        headers: {
          'apns-push-type': 'background',
          'apns-priority': '5'  // required for background on Apple platforms
        },
        payload: { aps: { 'content-available': 1 } }
      },
      // (Android side can ignore; you can add android config if you need)
    });
    console.log('[publish] FCM data sent →', id);
  }

  console.log('[publish] Done.');
})().catch(e => { console.error('[publish] ERROR:', e); process.exit(1); });