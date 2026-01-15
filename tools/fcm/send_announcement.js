
// tools/fcm/send_announcement.js
// Usage:
//   node tools/fcm/send_announcement.js --topic=allUsers --version=2026-01-15T14:35:59-0600
//
// Notes:
// - GOOGLE_APPLICATION_CREDENTIALS must point to a service-account JSON with
//   "Firebase Admin" permissions (FCM: send).
// - "version" can be your announcement_published_at value (or any unique string).

const admin = require('firebase-admin');

// Loads credentials from GOOGLE_APPLICATION_CREDENTIALS automatically
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

function argValue(name, def) {
  return process.argv.find(a => a.startsWith(`--${name}=`))?.split('=')[1] ?? def;
}

(async () => {
  const topic = argValue('topic', 'allUsers');
  // Use published_at as a semantic version so clients can dedupe.
  const version = argValue('version', new Date().toISOString());

  // Data-only message (no "notification" object).
  // iOS background delivery hints included. Android set to high priority.
  const message = {
    topic,
    data: {
      newAnnouncement: 'true',
      announcement_version: version
    },
    apns: {
      headers: {
        'apns-priority': '5',           // background update
        'apns-push-type': 'background'  // required for iOS 13+
      },
      payload: {
        aps: { 'content-available': 1 }
      }
    },
    android: { priority: 'high' }
  };

  try {
    const id = await admin.messaging().send(message);
    console.log(`Sent announcement ping. Message ID: ${id} (topic=${topic}, version=${version})`);
    process.exit(0);
  } catch (err) {
    console.error('Failed to send announcement ping:', err);
    process.exit(1);
  }
})();