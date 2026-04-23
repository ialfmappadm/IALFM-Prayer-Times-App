import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
};

type Announcement = {
  title: string;
  body: string;
};

export default function NotificationTab({ appendLog, onBack }: Props) {
  const [items, setItems] = useState<Announcement[]>([
    { title: "", body: "" },
  ]);
  const [publishing, setPublishing] = useState(false);

  const update = (
    index: number,
    field: keyof Announcement,
    value: string
  ) => {
    const next = [...items];
    next[index] = { ...next[index], [field]: value };
    setItems(next);
  };

  const addAnnouncement = () => {
    setItems([...items, { title: "", body: "" }]);
  };

  const publish = async () => {
    const invalid = items
      .map((a, i) =>
        !a.title.trim() || !a.body.trim() ? i + 1 : null
      )
      .filter((v): v is number => v !== null);

    if (invalid.length > 0) {
      appendLog(
        `❌ Please fill Title and Message for announcement(s): ${invalid.join(
          ", "
        )}`
      );
      return;
    }

    setPublishing(true);

    try {
      const payload = items.map((a, idx) => ({
        id: `announcement-${idx}`,
        title: a.title,
        body: a.body,
        sort_by_id: idx,
      }));

      const file =
        payload.length === 1
          ? "single_announcement.json"
          : "announcements.json";

      appendLog(`>> Writing ${file}`);
      appendLog(JSON.stringify(payload, null, 2));

      await invoke("write_json", {
        path: file,
        data: JSON.stringify(payload, null, 2),
      });

      appendLog(">> Publishing announcements…");

      const out = await invoke<string>("run_node_script", {
        payload: {
          scriptPath: "publish_and_notify.js",
          args: [
            "--file",
            file,
            "--project",
            "ialfm-prayer-times",
            "--tz",
            "America/Chicago",
            "--topic",
            "allUsers",
          ],
        },
      });

      if (out) appendLog(out);
      appendLog("✅ Publish completed successfully.");
    } catch (err: any) {
      appendLog("❌ Publish failed:");
      appendLog(String(err));
    } finally {
      setPublishing(false);
    }
  };

  return (
    <div className="vstack" style={{ width: "100%" }}>
      <div className="tab-scroll">
        <div className="vstack" style={{ width: 420 }}>
          {items.map((item, idx) => (
            <div key={idx} style={{ width: "100%" }}>
              <input
                style={{ width: "100%", marginBottom: 8 }}
                placeholder={`Title ${idx + 1}`}
                value={item.title}
                onChange={(e) =>
                  update(idx, "title", e.target.value)
                }
                disabled={publishing}
              />

              <textarea
                style={{ width: "100%", minHeight: 90 }}
                placeholder={`Message ${idx + 1}`}
                value={item.body}
                onChange={(e) =>
                  update(idx, "body", e.target.value)
                }
                disabled={publishing}
              />
            </div>
          ))}
        </div>
      </div>

      <button
        className="btn btn--primary"
        onClick={addAnnouncement}
        disabled={publishing}
      >
        + Add Announcement
      </button>

      <button
        className="btn btn--primary"
        onClick={publish}
        disabled={publishing}
      >
        Publish
      </button>

      <button
        className="btn btn--primary"
        onClick={onBack}
        disabled={publishing}
      >
        Back
      </button>
    </div>
  );
}