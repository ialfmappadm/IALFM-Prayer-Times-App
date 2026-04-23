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

const SECRETS_KEY = "ialfm_secrets_path";
const PROJECT_ID = "ialfm-prayer-times";

function getSecretsPath(): string | null {
  try {
    return localStorage.getItem(SECRETS_KEY);
  } catch {
    return null;
  }
}

export default function NotificationTab({ appendLog, onBack }: Props) {
  const [items, setItems] = useState<Announcement[]>([{ title: "", body: "" }]);
  const [publishing, setPublishing] = useState(false);

  const update = (index: number, field: keyof Announcement, value: string) => {
    const next = [...items];
    next[index] = { ...next[index], [field]: value };
    setItems(next);
  };

  const addAnnouncement = () => {
    setItems([...items, { title: "", body: "" }]);
  };

  const removeAnnouncement = (index: number) => {
    const next = items.filter((_, i) => i !== index);

    // Keep at least one row so the screen never becomes blank
    if (next.length === 0) {
      setItems([{ title: "", body: "" }]);
      return;
    }

    setItems(next);
  };

  const runUtility = async (scriptPath: string, args: string[], successLabel: string) => {
    const secretsPath = getSecretsPath();
    if (!secretsPath) {
      appendLog("❌ Missing Secrets JSON. Please run Setup first.");
      alert("Missing Secrets JSON. Please run Setup first.");
      return;
    }

    try {
      appendLog(`>> Running ${scriptPath}…`);

      const out = await invoke<string>("run_node_script", {
        payload: {
          scriptPath,
          args,
          secrets_path: secretsPath,
          project_id: PROJECT_ID,
        },
      });

      if (out) appendLog(out);
      appendLog(successLabel);
    } catch (e: any) {
      appendLog(`❌ Failed: ${String(e)}`);
    }
  };

  const publish = async () => {
    const invalid = items
      .map((a, i) => (!a.title.trim() || !a.body.trim() ? i + 1 : null))
      .filter((v): v is number => v !== null);

    if (invalid.length > 0) {
      appendLog(
        `❌ Please fill Title and Message for announcement(s): ${invalid.join(", ")}`
      );
      return;
    }

    const secretsPath = getSecretsPath();
    if (!secretsPath) {
      appendLog("❌ Missing Secrets JSON. Please run Setup first.");
      alert("Missing Secrets JSON. Please run Setup first.");
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
        payload.length === 1 ? "single_announcement.json" : "announcements.json";

      appendLog(`>> Writing ${file}`);
      appendLog(JSON.stringify(payload, null, 2));

      await invoke("write_json", {
        path: file,
        data: JSON.stringify(payload, null, 2),
      });

      appendLog(">> Publishing announcements…");

      const output = await invoke<string>("run_node_script", {
        payload: {
          scriptPath: "publish_and_notify.js",
          args: [
            "--file",
            file,
            "--project",
            PROJECT_ID,
            "--tz",
            "America/Chicago",
            "--topic",
            "allUsers",
          ],
          secrets_path: secretsPath,
          project_id: PROJECT_ID,
        },
      });

      if (output) appendLog(output);
      appendLog("✅ Publish completed successfully.");
    } catch (err: any) {
      appendLog("❌ Publish failed:");
      appendLog(String(err));
    } finally {
      setPublishing(false);
    }
  };

  return (
    <div className="notif-root">
      {/* LEFT SIDE: Scrollable List */}
      <div className="notif-scroll">
        <div
          className="vstack"
          style={{ width: "100%", maxWidth: "450px", alignItems: "stretch" }}
        >
          <h3 style={{ margin: "0 0 15px 0", fontSize: "16px" }}>
            Announcements
          </h3>

          {items.map((item, idx) => (
            <div key={idx} style={{ width: "100%", marginBottom: "20px" }}>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  marginBottom: 6,
                }}
              >
                <label
                  style={{
                    fontSize: "11px",
                    fontWeight: "bold",
                    color: "#64748b",
                  }}
                >
                  #{idx + 1}
                </label>

                {items.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeAnnouncement(idx)}
                    disabled={publishing}
                    style={{
                      all: "unset",
                      cursor: "pointer",
                      fontSize: "12px",
                      fontWeight: 600,
                      color: "#b91c1c",
                    }}
                  >
                    Remove
                  </button>
                )}
              </div>

              <input
                style={{
                  width: "100%",
                  marginBottom: 8,
                  padding: "8px",
                  borderRadius: "4px",
                  border: "1px solid #ccc",
                }}
                placeholder="Title"
                value={item.title}
                onChange={(e) => update(idx, "title", e.target.value)}
                disabled={publishing}
              />

              <textarea
                style={{
                  width: "100%",
                  minHeight: 80,
                  padding: "8px",
                  borderRadius: "4px",
                  border: "1px solid #ccc",
                }}
                placeholder="Message..."
                value={item.body}
                onChange={(e) => update(idx, "body", e.target.value)}
                disabled={publishing}
              />
            </div>
          ))}
        </div>
      </div>

      {/* RIGHT SIDE: action sidebar */}
      <div className="tab-actions">
        <button
          className="btn btn--primary"
          onClick={addAnnouncement}
          disabled={publishing}
        >
          + Add New
        </button>

        <button
          className="btn btn--primary"
          onClick={publish}
          disabled={publishing}
        >
          Publish All
        </button>

        <button
          className="btn btn--primary"
          onClick={() =>
            runUtility(
              "clear_announcements_force.js",
              [
                "--tz",
                "America/Chicago",
                "--stamp-via-shell",
                "--blank-card",
                "--notify",
                "--topic",
                "allUsers",
              ],
              "✅ Clear completed."
            )
          }
          disabled={publishing}
        >
          Clear Notifications
        </button>

        <button
          className="btn btn--primary"
          onClick={() =>
            runUtility(
              "rc_prune_and_lock.js",
              [
                "--tz",
                "America/Chicago",
                "--stamp-via-shell",
                "--notify",
                "--topic",
                "allUsers",
                "--project",
                PROJECT_ID,
              ],
              "✅ Prune completed."
            )
          }
          disabled={publishing}
        >
          Prune Expired
        </button>

        <div style={{ marginTop: "auto" }}>
        <button
          className="btn btn--primary"
          onClick={onBack}
          disabled={publishing}
        >
          Back
        </button>
        </div>
      </div>
    </div>
  );
}