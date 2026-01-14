
// tools/fcm/send_refresh.js
const admin = require('firebase-admin');

// Loads credentials from GOOGLE_APPLICATION_CREDENTIALS automatically
admin.initializeApp({ credential: admin.credential.applicationDefault() });

const topic = process.argv.find(a => a.startsWith('--topic='))?.split('=')[1] ?? 'allUsers';
const year  = process.argv.find(a => a.startsWith('--year=' ))?.split('=')[1] ?? `${new Date().getFullYear()}`;

(async () => {
  try {
    const messageId = await admin.messaging().send({
      topic,
      data: { updatePrayerTimes: 'true', year },
      // iOS silent/background refresh:
      apns: {
        headers: { 'apns-push-type': 'background', 'apns-priority': '5' },
        payload: { aps: { 'content-available': 1 } }
      },
      // Android: high priority to deliver promptly
      android: { priority: 'high' }
    });

    console.log(`Sent message ID: ${messageId} (topic=${topic}, year=${year})`);
    process.exit(0);
  } catch (err) {
    console.error('Failed to send:', err);
    process.exit(1);
  }
})();