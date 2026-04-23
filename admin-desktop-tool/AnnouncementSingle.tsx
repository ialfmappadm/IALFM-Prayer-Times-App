import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

const ANNOUNCE_DIR =
  "/Users/syed/AndroidStudioProjects/IALFM/prayer_times_app/tools/announce";

const FILE_SINGLE = "single_announcement.json";

function genIdFromTitle(title: string) {
  const t = title.trim();
  return t.length ? t : `item-${Date.now()}`;
}

export default function AnnouncementSingle({ navigate, appendLog }) {
  const [title, setTitle] = useState("");
  const [text, setText] = useState("");

  async function postAnnouncement() {
    try {
      if (!title.trim() || !text.trim()) {
        alert("Please enter both Title and Text.");
        return;
      }

      appendLog("Preparing single announcement…");

      const payload = [
        {
          id: genIdFromTitle(title),
          title: title.trim(),
          body: text.trim(),
          sort_by_id: 0,
        },
      ];

      appendLog(`Writing ${FILE_SINGLE}…`);
      await invoke("write_json", {
        path: FILE_SINGLE,
        data: JSON.stringify(payload, null, 2),
      });

      appendLog("Running publish script…");

      const out = await invoke<string>("run_node_script", {
        payload: {
          scriptPath: "publish_and_notify.js",
          args: [
            "--file",
            FILE_SINGLE,
            "--project",
            "ialfm-prayer-times",
            "--tz",
            "America/Chicago",
            "--topic",
            "allUsers",
          ],
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
    <div className="vstack">
      <h3>Post Single Announcement</h3>

      <input
        placeholder="System Test Broadcast"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
      />

      <textarea
        placeholder="Announcement text"
        value={text}
        onChange={(e) => setText(e.target.value)}
      />

      <div>
        <button className="btn btn--primary" onClick={postAnnouncement}>
          Post Announcement
        </button>

        <button
          className="btn btn--secondary"
          onClick={() => navigate("main")}
          style={{ marginLeft: 8 }}
        >
          Back
        </button>
      </div>
    </div>
  );
}