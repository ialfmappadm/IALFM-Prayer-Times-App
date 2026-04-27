import React, { useMemo, useState } from "react";
import { invoke } from "@tauri-apps/api/core";

import {
  AdminButton,
  AdminInput,
  AdminTextarea,
  AdminInlineActionButton,
} from "../ui/AdminControls";

import { runAdminAction } from "../utils/adminUi";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
  busy: boolean;
  setBusy: React.Dispatch<React.SetStateAction<boolean>>;
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

/**
 * NotificationTab
 * - Multi announcement publish to Remote Config + FCM
 * - Utility actions (clear/prune) colocated under publishing
 * - Uses shared AdminControls so visuals & busy behavior stay identical across tabs
 */
export default function NotificationTab({
  appendLog,
  onBack,
  busy,
  setBusy,
}: Props) {
  const [items, setItems] = useState<Announcement[]>([{ title: "", body: "" }]);

  /**
   * UseMemo for shared input style objects so we don't recreate them on every render.
   * This keeps the code long/explicit AND avoids needless churn.
   */
  const titleInputStyle = useMemo<React.CSSProperties>(
    () => ({
      width: "100%",
      marginBottom: 8,
      padding: "8px",
      borderRadius: "4px",
      border: "1px solid #ccc",
    }),
    []
  );

  const bodyTextareaStyle = useMemo<React.CSSProperties>(
    () => ({
      width: "100%",
      minHeight: 80,
      padding: "8px",
      borderRadius: "4px",
      border: "1px solid #ccc",
    }),
    []
  );

  const update = (index: number, field: keyof Announcement, value: string) => {
    if (busy) return;

    const next = [...items];
    next[index] = { ...next[index], value };
    setItems(next);
  };

  const addAnnouncement = () => {
    if (busy) return;
    setItems([...items, { title: "", body: "" }]);
  };

  const removeAnnouncement = (index: number) => {
    if (busy) return;

    const next = items.filter((_, i) => i !== index);

    // Keep at least one row to avoid an empty page.
    if (next.length === 0) {
      setItems([{ title: "", body: "" }]);
      return;
    }

    setItems(next);
  };

  /**
   * Shared runner for Clear / Prune scripts.
   * runAdminAction ensures the busy visuals are visible even for fast scripts.
   */
  const runUtility = async (
    scriptPath: string,
    args: string[],
    successLabel: string
  ) => {
    const secretsPath = getSecretsPath();
    if (!secretsPath) {
      appendLog("❌ Missing Secrets JSON. Please run Setup first.");
      alert("Missing Secrets JSON. Please run Setup first.");
      return;
    }

    await runAdminAction(setBusy, async () => {
      try {
        const announceDir = await invoke<string>("get_announce_dir");

        appendLog(">> Announcement tools directory:");
        appendLog(announceDir);

        appendLog(">> Running script from:");
        appendLog(`${announceDir}/${scriptPath}`);

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
    });
  };

  /**
   * Publish announcements
   * - Validates that every card is filled
   * - Writes JSON to announce tooling directory
   * - Executes publish_and_notify.js
   */
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

    await runAdminAction(setBusy, async () => {
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

        const announceDir = await invoke<string>("get_announce_dir");

        appendLog(">> Announcement tools directory:");
        appendLog(announceDir);

        appendLog(">> Writing file:");
        appendLog(`${announceDir}/${file}`);

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
      }
    });
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
                  <AdminInlineActionButton
                    busy={busy}
                    onClick={() => removeAnnouncement(idx)}
                  >
                    Remove
                  </AdminInlineActionButton>
                )}
              </div>

              <AdminInput
                busy={busy}
                style={titleInputStyle}
                placeholder="Title"
                value={item.title}
                onChange={(e) => update(idx, "title", e.target.value)}
              />

              <AdminTextarea
                busy={busy}
                style={bodyTextareaStyle}
                placeholder="Message..."
                value={item.body}
                onChange={(e) => update(idx, "body", e.target.value)}
              />
            </div>
          ))}
        </div>
      </div>

      {/* RIGHT SIDE: action sidebar */}
      <div className="tab-actions">
        <AdminButton busy={busy} onClick={addAnnouncement}>
          + Add New
        </AdminButton>

        <AdminButton busy={busy} onClick={publish}>
          Publish All
        </AdminButton>

        <AdminButton
          busy={busy}
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
        >
          Clear Notifications
        </AdminButton>

        <AdminButton
          busy={busy}
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
        >
          Prune Expired
        </AdminButton>

        <div style={{ marginTop: "auto" }}>
          <AdminButton busy={busy} onClick={onBack}>
            Back
          </AdminButton>
        </div>
      </div>
    </div>
  );
}