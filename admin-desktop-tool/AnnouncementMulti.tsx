import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

const FILE_MULTI = "announcements.json";

type Draft = {
  title: string;
  text: string;
};

function genIdFromTitle(title: string) {
  const t = title.trim();
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

      const payload = items
        .map((a, i) => ({
          id: genIdFromTitle(a.title),
          title: a.title.trim(),
          body: a.text.trim(),
          sort_by_id: i,
        }))
        .filter((a) => a.title && a.body);

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

      const out = await invoke<string>("run_node_script", {
        payload: {
          scriptPath: "publish_and_notify.js",
          args: [
            "--file",
            FILE_MULTI,
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
      appendLog("✅ Multi announcements posted!");
      alert("All announcements posted!");
    } catch (err) {
      appendLog(`❌ Failed: ${err}`);
      alert(`Failed: ${err}`);
    }
  }

  return (
    <div className="vstack">
      <h3>Post Multiple Announcements</h3>

      {items.map((a, i) => (
        <div key={i}>
          <input
            placeholder={`Title #${i + 1}`}
            value={a.title}
            onChange={(e) =>
              update(i, "title", e.target.value)
            }
          />

          <textarea
            placeholder="Announcement text"
            value={a.text}
            onChange={(e) =>
              update(i, "text", e.target.value)
            }
          />
        </div>
      ))}

      <button className="btn btn--secondary" onClick={addAnnouncement}>
        Add Another
      </button>

      <button className="btn btn--primary" onClick={postAll}>
        Post All
      </button>

      <button
        className="btn btn--secondary"
        onClick={() => navigate("main")}
        style={{ marginLeft: 8 }}
      >
        Back
      </button>
    </div>
  );
}