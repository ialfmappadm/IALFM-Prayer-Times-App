import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

const ANNOUNCE_DIR =
  "/Users/syed/AndroidStudioProjects/IALFM/prayer_times_app/tools/announce"; // consider moving to a Setup screen
const FILE_SINGLE = `${ANNOUNCE_DIR}/single_announcement.json`;
const PUBLISH_JS  = `${ANNOUNCE_DIR}/publish_and_notify.js`;

function genIdFromTitle(title: string) {
  const t = (title || "").trim();
  // keep it simple; you can slugify later if needed
  return t.length ? t : `item-${Date.now()}`;
}

export default function AnnouncementSingle({ navigate, appendLog }) {
  const [title, setTitle] = useState("");
  const [text,  setText]  = useState("");

  async function postAnnouncement() {
    try {
      if (!title.trim() || !text.trim()) {
        alert("Please enter both Title and Text.");
        return;
      }

      appendLog("Preparing single announcement…");

      // IMPORTANT: the publish script expects an ARRAY, even for a single
      const row = {
        id: genIdFromTitle(title),
        title: title.trim(),
        text: text.trim(),
        sort_by_id: 0
      };
      const payload = [row];

      appendLog(`Writing ${FILE_SINGLE}…`);
      await invoke("write_json", {
        path: FILE_SINGLE,
        data: JSON.stringify(payload, null, 2),
      });

      console.log("🔥 USING PAYLOAD INVOKE", {
                payload: {
                  scriptPath: PUBLISH_JS,
                  args,
      });

      appendLog("Running publish script…");
      const args = [
        "--file", FILE_SINGLE,
        "--project", "ialfm-prayer-times",
        "--tz", "America/Chicago",
        "--topic", "allUsers",
      ];
      const out = await invoke("run_node_script", {
        payload: {
          scriptPath: PUBLISH_JS,
          args,
        },
      });

      appendLog(String(out));
      appendLog("✅ Single announcement posted!");
      alert("Announcement posted!");
    } catch (err) {
      appendLog(`❌ Failed: ${err}`);
      alert(`Failed: ${err}`);
    }
  }

  return (
    <div>
      <h3>Post Single Announcement</h3>

      <div style={{ marginBottom: 8 }}>
        <label>Title</label>
        <input
          style={{ width: "100%" }}
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="System Test Broadcast"
        />
      </div>

      <div style={{ marginBottom: 8 }}>
        <label>Text</label>
        <textarea
          style={{ width: "100%", minHeight: 140 }}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="This is a test of the IALFM broadcast system. No action is required."
        />
      </div>

      <button onClick={postAnnouncement}>Post Announcement</button>
      <button onClick={() => navigate("main")} style={{ marginLeft: 8 }}>
        Back
      </button>
    </div>
  );
}