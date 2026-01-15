
// tools/announce/publish_and_notify.js
//
// Single item:
//   node tools/announce/publish_and_notify.js \
//     --title="Eid Mubarak" \
//     --text="Takbeerat at 8:00 AM Salah at 8:30 AM" \
//     --publishedAt="2026-01-15T14:35:59-0600" \
//     --topic=allUsers \
//     --key="$HOME/secrets/ialfm-admin.json"
//
// Multiple items:
//   node tools/announce/publish_and_notify.js \
//     --file=tools/announce/announcements.json \
//     --topic=allUsers \
//     --key="$HOME/secrets/ialfm-admin.json"
//
// Optional corporate CA if ever needed:
//   --cafile="$HOME/secrets/corp-root-ca.pem"
//
// Grants needed on the service account:
//   - roles/remoteconfig.admin
//   - roles/fcm.sender

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function arg(name, def) {
  const hit = process.argv.find(a => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : def;
}
function mustExist(p, label) {
  if (!fs.existsSync(p)) {
    console.error(`${label} not found: ${p}`);
    process.exit(2);
  }
}

(async () => {
  // ---- Neutralize problematic TLS env vars (bad CA paths) ----
  // These can point to non-existent ~/.ssl/cacert.pem and break TLS.
  ['SSL_CERT_FILE', 'CURL_CA_BUNDLE', 'SSL_CERT_DIR'].forEach(k => {
    if (process.env[k]) {
      console.warn(`Ignoring ${k}=${process.env[k]}`);
      delete process.env[k];
    }
  });

  // If you explicitly pass a CA file, honor it; otherwise let Node use its built-in CA bundle.
  const cafile = arg('cafile', '');
  if (cafile) {
    const absCA = path.resolve(cafile);
    mustExist(absCA, 'CA file');
    process.env.NODE_EXTRA_CA_CERTS = absCA;
  } else if (process.env.NODE_EXTRA_CA_CERTS) {
    // If it's set but the file is missing, unset it to avoid failures.
    try {
      const abs = path.resolve(process.env.NODE_EXTRA_CA_CERTS);
      if (!fs.existsSync(abs)) {
        console.warn(`NODE_EXTRA_CA_CERTS points to missing file: ${abs}; ignoring it.`);
        delete process.env.NODE_EXTRA_CA_CERTS;
      }
    } catch (_) {}
  }

  // ---- Init Admin SDK with explicit key (preferred) or ADC ----
  const key = arg('key', process.env.GOOGLE_APPLICATION_CREDENTIALS || '');
  if (key) {
    const abs = path.resolve(key);
    mustExist(abs, 'Service account key');
    const svc = require(abs);
    admin.initializeApp({ credential: admin.credential.cert(svc) });
  } else {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }

  const topic = arg('topic', 'allUsers');
  const file  = arg('file', '');

  // ---- Build items[] from file or single flags ----
  let items = [];
  if (file) {
    const absFile = path.resolve(file);
    mustExist(absFile, 'Input file');
    const raw = fs.readFileSync(absFile, 'utf8');
    const arr = JSON.parse(raw);
    if (!Array.isArray(arr)) {
      console.error('Input file must be a JSON array of announcements.');
      process.exit(2);
    }
    items = arr;
  } else {
    const title = arg('title', '');
    const text  = arg('text', '');
    const publishedAt = arg('publishedAt', '');
    if (!title && !text && !publishedAt) {
      console.error('Provide --file=... OR --title/--text/--publishedAt.');
      process.exit(2);
    }
    items = [{
      id: arg('id', 'single-item'),
      title: String(title),
      text: String(text),
      published_at: String(publishedAt),
    }];
  }

  // Normalize and sort newest first
  items = items.map((a, i) => ({
    id: (a.id || `item-${i}`).toString(),
    title: (a.title || '').toString(),
    text: (a.text || '').toString(),
    published_at: (a.published_at || '').toString(),
  })).sort((a, b) => (b.published_at || '').localeCompare(a.published_at || ''));

  const version = items[0]?.published_at || new Date().toISOString();

  // ---- Update Remote Config ----
  const rc = admin.remoteConfig();
  const tpl = await rc.getTemplate();

  tpl.parameters = {
    ...(tpl.parameters || {}),

    // New: list + version
    'announcements_json':    { defaultValue: { value: JSON.stringify(items) } },
    'announcements_version': { defaultValue: { value: version } },

    // Legacy single keys for backward compatibility (first item)
    'announcement_active':        { defaultValue: { value: String(items.length > 0) } },
    'announcement_title':         { defaultValue: { value: items[0]?.title || '' } },
    'announcement_text':          { defaultValue: { value: items[0]?.text  || '' } },
    'announcement_published_at':  { defaultValue: { value: items[0]?.published_at || '' } },
  };

  const { versionNumber } = await rc.publishTemplate(tpl);
  console.log(`Remote Config published (version ${versionNumber}); items=${items.length}`);

  // ---- One FCM ping to wake clients ----
  const id = await admin.messaging().send({
    topic,
    data: {
      newAnnouncement: 'true',
      announcement_version: version,
    },
    apns: {
      headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
      payload: { aps: { 'content-available': 1 } }
    },
    android: { priority: 'high' }
  });
  console.log(`Sent FCM ping. Message ID: ${id}, topic=${topic}, version=${version}`);
  process.exit(0);
})().catch((e) => {
  console.error('Failed:', e);
  process.exit(1);
});