// tools/announce/publish_and_notify.js
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function arg(name, def) { const hit = process.argv.find(a => a.startsWith(`--${name}=`)); return hit ? hit.split('=').slice(1).join('=') : def; }
function mustExist(p, label) { if (!fs.existsSync(p)) { console.error(`${label} not found: ${p}`); process.exit(2); } }

(async () => {
  ['SSL_CERT_FILE','CURL_CA_BUNDLE','SSL_CERT_DIR'].forEach(k => { if (process.env[k]) { console.warn(`Ignoring ${k}=${process.env[k]}`); delete process.env[k]; } });
  const cafile = arg('cafile', '');
  if (cafile) { const absCA = path.resolve(cafile); mustExist(absCA, 'CA file'); process.env.NODE_EXTRA_CA_CERTS = absCA; }
  const key = arg('key', process.env.GOOGLE_APPLICATION_CREDENTIALS || '');
  if (key) { const abs = path.resolve(key); mustExist(abs, 'Service account key'); const svc = require(abs); admin.initializeApp({ credential: admin.credential.cert(svc) }); }
  else { admin.initializeApp({ credential: admin.credential.applicationDefault() }); }

  const topic = arg('topic', 'allUsers');
  const file  = arg('file', '');

  // Build items[]
  let items = [];
  if (file) {
    const absFile = path.resolve(file); mustExist(absFile, 'Input file');
    const arr = JSON.parse(fs.readFileSync(absFile, 'utf8'));
    if (!Array.isArray(arr)) { console.error('Input file must be a JSON array of announcements.'); process.exit(2); }
    items = arr;
  } else {
    const title = arg('title', ''), text = arg('text', ''), publishedAt = arg('publishedAt', '');
    if (!title && !text && !publishedAt) { console.error('Provide --file=... OR --title/--text/--publishedAt.'); process.exit(2); }
    items = [{ id: arg('id', 'single-item'), title: String(title), text: String(text), published_at: String(publishedAt) }];
  }

  // Normalize & newest-first
  items = items.map((a, i) => ({
    id: (a.id || `item-${i}`).toString(),
    title: (a.title || '').toString(),
    text: (a.text || '').toString(),
    published_at: (a.published_at || '').toString(),
  })).sort((a, b) => (b.published_at || '').localeCompare(a.published_at || ''));

  const version = items[0]?.published_at || new Date().toISOString();

  // ---- Update Remote Config (clean overwrite semantics) ----
  const rc = admin.remoteConfig();
  const tpl = await rc.getTemplate();

  // Always set JSON list + version
  tpl.parameters = {
    ...(tpl.parameters || {}),
    'announcements_json':    { defaultValue: { value: JSON.stringify(items) } },
    'announcements_version': { defaultValue: { value: version } },
  };

  // Legacy single policy:
  //  - If exactly ONE item -> mirror it (back-compat)
  //  - Else (0 or >1)      -> disable legacy to avoid duplicate rendering on older clients
  if (items.length === 1) {
    tpl.parameters['announcement_active']       = { defaultValue: { value: 'true' } };
    tpl.parameters['announcement_title']        = { defaultValue: { value: items[0].title || '' } };
    tpl.parameters['announcement_text']         = { defaultValue: { value: items[0].text  || '' } };
    tpl.parameters['announcement_published_at'] = { defaultValue: { value: items[0].published_at || '' } };
  } else {
    tpl.parameters['announcement_active']       = { defaultValue: { value: 'false' } };
    tpl.parameters['announcement_title']        = { defaultValue: { value: '' } };
    tpl.parameters['announcement_text']         = { defaultValue: { value: '' } };
    tpl.parameters['announcement_published_at'] = { defaultValue: { value: '' } };
  }

  const { versionNumber } = await rc.publishTemplate(tpl);
  console.log(`Remote Config published (version ${versionNumber}); items=${items.length}`);

  // ---- Optional FCM "nudge" ----
  const id = await admin.messaging().send({
    topic,
    data: { newAnnouncement: 'true', announcement_version: version },
    apns: { headers: { 'apns-priority': '5', 'apns-push-type': 'background' }, payload: { aps: { 'content-available': 1 } } },
    android: { priority: 'high' }
  });
  console.log(`Sent FCM ping. Message ID: ${id}, topic=${topic}, version=${version}`);
  process.exit(0);
})().catch((e) => { console.error('Failed:', e); process.exit(1); });