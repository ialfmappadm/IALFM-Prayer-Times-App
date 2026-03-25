// tools/cloud-functions-rc/index.js
// Cloud Functions v2 trigger: fires when someone clicks "Publish" in Remote Config (GUI/API).
import { remoteConfig } from "firebase-functions/v2";   // <-- use aggregate v2 entrypoint
import * as logger from "firebase-functions/logger";
import admin from "firebase-admin";

admin.initializeApp();

export const rcAnnounceOnPublish = remoteConfig.onConfigUpdated(async (event) => {
  try {
    const topic = "allUsers";                 // app subscribes to this
    const data  = { newAnnouncement: "true" };// app checks this in onMessage

    const id = await admin.messaging().send({
      topic,
      data,
      android: { priority: "high" }
      // (APNs optional; data-only is enough for your bell-dot UI)
    });

    logger.info("Sent FCM ping on RC publish", {
      messageId: id,
      updateType: event.updateType,          // INCREMENTAL_UPDATE / FORCED_UPDATE / ROLLBACK
      versionNumber: event.versionNumber
    });
  } catch (e) {
    logger.error("FCM ping failed on RC publish", e);
    throw e;
  }
});
