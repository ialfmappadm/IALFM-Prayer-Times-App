// tools/announce/rc_prune_and_lock.js  (ES Module)
//
// PURPOSE
// • Delete all announcement-related RC params except the minimal allow-list.
// • Keep only: announcement_active/title/text/published_at + ann_fp (unprefixed).
// • Remove *all* prefixed (e.g., ABC_...) and list keys (announcements_*).
// • Optionally send an FCM data push with ann_fp to refresh devices immediately.
//
// USAGE (from tools/announce):
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secrets/ialfm-admin.json"
//   export GOOGLE_CLOUD_PROJECT="ialfm-prayer-times"
//   node rc_prune_and_lock.js --tz=America/Chicago --stamp-via-shell --notify --topic=allUsers
//
// OPTIONS
//   --project <id>          override project; else uses GOOGLE_CLOUD_PROJECT
//   --tz <tz>               default America/Chicago
//   --stamp-via-shell       use TZ=<tz> `date +%Y-%m-%dT%H:%M:%S%z`
//   --notify --topic=<t>    send FCM data with ann_fp
//   --dry-run               show changes but do not publish nor notify
//   --list-only             list what would be deleted/kept, then exit

import 'dotenv/config';
import { Command } from 'commander';
import admin from 'firebase-admin';
import fsSync from 'node:fs';
import { execFileSync } from 'node:child_process';

const program = new Command()
  .option('--project <id>', 'Project ID', process.env.GOOGLE_CLOUD_PROJECT || '')
  .option('--tz <tz>', 'IANA time zone', 'America/Chicago')
  .option('--stamp-via-shell', 'Use shell date', false)
  .option('--notify', 'Send FCM data push with ann_fp', false)
  .option('--topic <t>', 'FCM topic', 'allUsers')
  .option('--list-only', 'List keys only, do not write', false)
  .option('--dry-run', 'Do not publish nor notify', false)
  .parse(process.argv);

const { project, tz, stampViaShell, notify, topic, listOnly, dryRun } = program.opts();

function initAdmin(projectId) {
  if (admin.apps.length) return;
  let credential;
  const sa = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (sa && fsSync.existsSync(sa)) {
    try {
      const raw = JSON.parse(fsSync.readFileSync(sa, 'utf8'));
      if (raw.type === 'service_account') credential = admin.credential.cert(raw);
    } catch {}
  }
  if (!credential) credential = admin.credential.applicationDefault();
  admin.initializeApp({ credential, projectId: projectId || process.env.GOOGLE_CLOUD_PROJECT || undefined });
}

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
  const offH = String(Math.floor(Math.abs(diffMin) / 60)).padStart(2,'0');
  const offM = String(Math.abs(diffMin) % 60).padStart(2,'0');
  return `${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}T` +
         `${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}:${String(ss).padStart(2,'0')}` +
         `${sign}${offH}:${offM}`;
}
function nowStamp(tz, viaShell) {
  try { return viaShell ? shellStamp(tz) : jsStampInTz(tz); }
  catch { return new Date().toISOString(); }
}

const ALLOW = new Set([
  'announcement_active',
  'announcement_title',
  'announcement_text',
  'announcement_published_at',
  'ann_fp',
]);

// Any announcement-ish key (unprefixed or prefixed) should be deleted unless in ALLOW.
const MATCHERS = [
  /^announcement_/i,
  /^announcements_/i,
  /^ann_fp$/i,
  /^.*_announcement_/i,
  /^.*_announcements_/i,
  /^.*_ann_fp$/i,
];

function shouldDelete(name) {
  if (ALLOW.has(name)) return false;
  return MATCHERS.some(rx => rx.test(name));
}

function getVal(params, key) {
  const p = params[key];
  if (!p || !p.defaultValue) return '';
  return String(p.defaultValue.value ?? '');
}

async function sendFcm(annFp, topic) {
  const id = await admin.messaging().send({
    topic,
    data: { ann_fp: String(annFp) },
    android: { priority: 'high' },
    apns: { headers: { 'apns-push-type': 'background' }, payload: { aps: { 'content-available': 1 } } },
  });
  console.log(`[prune] FCM data sent → ${id} (topic=${topic}, ann_fp=${annFp})`);
}

(async function main() {
  initAdmin(project);
  const stamp = nowStamp(tz, stampViaShell);
  const rc = admin.remoteConfig();

  let tpl = await rc.getTemplate();
  const params = tpl.parameters ?? {};
  const names = Object.keys(params);

  // What would be deleted
  const toDelete = names.filter(shouldDelete);
  const toKeep = names.filter(n => !shouldDelete(n));

  console.log(`[prune] Project=${project || process.env.GOOGLE_CLOUD_PROJECT || '(ADC)'} tz=${tz} dryRun=${!!dryRun}`);
  console.log(`[prune] Will delete (${toDelete.length}): ${toDelete.length ? toDelete.join(', ') : '(none)'}`);
  console.log(`[prune] Will keep   (${toKeep.length}): ${toKeep.length ? toKeep.join(', ') : '(none)'}`);

  if (program.opts().listOnly) {
    console.log('[prune] --list-only set; exiting.');
    return;
  }

  // Gather current single-card (prefer unprefixed; otherwise fallback to any existing)
  const current = {
    active: getVal(params, 'announcement_active') || 'true',
    title:  getVal(params, 'announcement_title')  || 'No new announcements to display',
    text:   getVal(params, 'announcement_text')   || '',
    ts:     getVal(params, 'announcement_published_at') || stamp,
    fp:     getVal(params, 'ann_fp') || `clear-${stamp.replace(/[^0-9T:-]/g,'')}`,
  };

  // Delete everything matched
  let removed = 0;
  for (const k of toDelete) { delete params[k]; removed++; }

  // Rebuild ONLY the minimal keys
  const put = (k, v) => { params[k] = { defaultValue: { value: String(v) } }; };
  put('announcement_active', current.active);
  put('announcement_title',  current.title);
  put('announcement_text',   current.text);
  put('announcement_published_at', current.ts);
  put('ann_fp', current.fp);

  tpl.parameters = params;

  if (dryRun) {
    console.log(`[prune] (dry-run) Would remove ${removed} keys & publish ann_fp=${current.fp}`);
    return;
  }

  tpl = await rc.validateTemplate(tpl);
  const res = await rc.publishTemplate(tpl);
  console.log(`[prune] RC removed=${removed}; published version=${res.versionNumber}; ann_fp=${current.fp}`);

  if (notify) await sendFcm(current.fp, topic);
  console.log('[prune] Done.');
})().catch(e => { console.error('[prune] ERROR:', e); process.exit(1); });