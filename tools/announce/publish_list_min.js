// tools/announce/publish_list_min.js
// Minimal publisher: writes ONLY unprefixed announcements_json + ann_fp.
// No prefix namespace, no single-card enabled, no fancy options.
//
// Usage:
//   node publish_list_min.js --file announcements.json \
//     --project ialfm-prayer-times \
//     --tz America/Chicago \
//     --topic allUsers        # (optional) FCM notify
//
// Auth (recommended):
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secrets/ialfm-admin.json"
//   export GOOGLE_CLOUD_PROJECT="ialfm-prayer-times"

import admin from 'firebase-admin';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';

// --- simple arg parser ---
function getArg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  if (i >= 0 && i + 1 < process.argv.length) return process.argv[i + 1];
  return def;
}
function hasFlag(name) {
  return process.argv.includes(`--${name}`);
}

const file    = getArg('file', '');
const project = getArg('project', process.env.GOOGLE_CLOUD_PROJECT || '');
const tz      = getArg('tz', 'America/Chicago');
const topic   = getArg('topic', ''); // optional

if (!file) {
  console.error('[min] Missing --file <path>');
  process.exit(2);
}
if (!project) {
  console.error('[min] Missing --project <id> or $GOOGLE_CLOUD_PROJECT');
  process.exit(2);
}

// --- admin init ---
function initAdmin(projectId) {
  let credential;
  const sa = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (sa) {
    // Try to treat it as a service-account file; if not present, fallback to ADC
    try {
      const raw = JSON.parse(require('node:fs').readFileSync(sa, 'utf8'));
      if (raw.type === 'service_account') {
        credential = admin.credential.cert(raw);
      }
    } catch (_) {}
  }
  if (!credential) credential = admin.credential.applicationDefault();
  admin.initializeApp({ credential, projectId });
}

// --- time & fp helpers ---
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
    // derive offset like -06:00
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

// --- main ---
(async () => {
  initAdmin(project);

  // 1) Read & validate file
  const raw = await fs.readFile(file, 'utf8');
  let arr;
  try {
    arr = JSON.parse(raw);
  } catch (e) {
    console.error('[min] JSON parse error:', e.message);
    process.exit(2);
  }
  if (!Array.isArray(arr) || arr.length === 0) {
    console.error('[min] File must contain a non-empty JSON array:', file);
    process.exit(2);
  }

  // 2) Compute fingerprint + stamp (for placeholder single fields)
  const annFp = fpFrom(arr);
  const stamp = nowStamp(tz);

  // 3) Write RC (ONLY unprefixed keys)
  const rc = admin.remoteConfig();
  let tpl = await rc.getTemplate();
  const params = tpl.parameters ?? {};

  // Overwrite exactly these keys:
  params['announcements_json']        = { defaultValue: { value: JSON.stringify(arr) } };
  params['ann_fp']                    = { defaultValue: { value: annFp } };
  params['announcements_version']     = { defaultValue: { value: annFp } };

  // Disable single card explicitly
  params['announcement_active']       = { defaultValue: { value: 'false' } };
  params['announcement_title']        = { defaultValue: { value: '' } };
  params['announcement_text']         = { defaultValue: { value: '' } };
  params['announcement_published_at'] = { defaultValue: { value: stamp } };

  tpl.parameters = params;
  tpl = await rc.validateTemplate(tpl);
  const res = await rc.publishTemplate(tpl);
  const version = res?.versionNumber || res?.version?.versionNumber || '(unknown)';
  console.log(`[min] RC published version=${version}; ann_fp=${annFp}`);
  console.log('[min] RC wrote announcements_json.length =', JSON.stringify(arr).length);

  // 4) Optional FCM notify
  if (topic) {
    const id = await admin.messaging().send({
      topic,
      data: { ann_fp: String(annFp), ann_count: String(arr.length) },
      android: { priority: 'high' },
      apns: { headers: { 'apns-push-type': 'background' }, payload: { aps: { 'content-available': 1 } } },
    });
    console.log('[min] FCM data sent →', id);
  }

  console.log('[min] Done.');
})().catch(e => { console.error('[min] ERROR:', e); process.exit(1); });