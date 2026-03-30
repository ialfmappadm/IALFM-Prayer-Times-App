import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

const ANNOUNCE_DIR =
  "/Users/syed/AndroidStudioProjects/IALFM/prayer_times_app/tools/announce"; // TODO: move to Setup env
const FILE_MULTI = `${ANNOUNCE_DIR}/announcements.json`;
const PUBLISH_JS = `${ANNOUNCE_DIR}/publish_and_notify.js`;

type Draft = { title: string; text: string };

function genIdFromTitle(title: string) {
  const t = (title || "").trim();
  return t.length ? t : `item-${Date.now()}`;
}

export default function AnnouncementMulti({ navigate, appendLog }) {
  const [items, setItems] = useState<Draft[]>([
    { title: "", text: "" },
  ]);

  function update(i: number, field: keyof Draft, value: string) {
    const copy = [...items];
    copy[i] = { ...copy[i], [field]: value };
    setItems(copy);
  }

  function addAnnouncement() {
    setItems([...items, { title: "", text: "" }]);
  }

  async function postAll() {
    try {
      appendLog("Preparing announcements…");

      // Transform drafts → required shape with id/sort_by_id
      const payload = items
        .map((a, i) => ({
          id: genIdFromTitle(a.title),
          title: (a.title || "").trim(),
          text: (a.text || "").trim(),
          sort_by_id: i, // order of list → sort key
        }))
        // filter out empties
        .filter((a) => a.title.length && a.text.length);

      if (!payload.length) {
        alert("Please fill at least one Title and Text.");
        return;
      }

      appendLog(`Writing ${FILE_MULTI}…`);
      await invoke("write_json", {
        path: FILE_MULTI,
        data: JSON.stringify(payload, null, 2),
      });

      appendLog("Running publish script…");
      const args = [
        "--file", FILE_MULTI,
        "--project", "ialfm-prayer-times",
        "--tz", "America/Chicago",
        "--topic", "allUsers",
      ];
      const out = await invoke("run_node_script", {
        path: PUBLISH_JS,
        args,
      });

      appendLog(String(out));
      appendLog("✅ Multi announcements posted!");
      alert("All announcements posted!");
    } catch (err) {
      appendLog(`❌ Failed: ${err}`);
      alert(`Failed: ${err}`);
    }
  }

  return (
    <div>
      <h3>Post Multiple Announcements</h3>

      {items.map((a, i) => (
        <div key={i} style={{ border: "1px solid #ddd", padding: 12, marginBottom: 12 }}>
          <div style={{ marginBottom: 8 }}>
            <label>Title #{i + 1}</label>
            <input
              style={{ width: "100%" }}
              value={a.title}
              onChange={(e) => update(i, "title", e.target.value)}
              placeholder="Eid ul Fitr"
            />
          </div>

          <div style={{ marginBottom: 8 }}>
            <label>Text</label>
            <textarea
              style={{ width: "100%", minHeight: 120 }}
              value={a.text}
              onChange={(e) => update(i, "text", e.target.value)}
              placeholder="Enter announcement text…"
            />
          </div>
        </div>
      ))}

      <button onClick={addAnnouncement}>Add Another</button>
      <button onClick={postAll} style={{ marginLeft: 8 }}>Post All</button>
      <button onClick={() => navigate("main")} style={{ marginLeft: 8 }}>Back</button>
    </div>
  );
}