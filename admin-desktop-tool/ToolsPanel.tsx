import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

type Props = {
  navigate: (to: string) => void;
  appendLog: (line: string) => void;
  clearLogs: () => void;
};

const ANNOUNCE_DIR =
  "/Users/syed/AndroidStudioProjects/IALFM/prayer_times_app/tools/announce";

export default function ToolsPanel({ navigate, appendLog, clearLogs }: Props) {
  const [clearing, setClearing] = useState(false);

  async function clearAnnouncements() {
    if (clearing) return;
    setClearing(true);

    try {
      appendLog("Running clear_announcements_force.js …");

      const out = await invoke<string>("run_node_script", {
        payload: {
          scriptPath: "clear_announcements_force.js",
          args: [
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
      appendLog("✅ Clear completed.");
      alert("Announcements cleared.");
    } catch (err) {
      appendLog(`❌ Clear failed: ${err}`);
      alert(`Clear failed: ${err}`);
    } finally {
      setClearing(false);
    }
  }

  return (
    <div className="vstack">
      <button
        className="btn btn--primary"
        onClick={clearAnnouncements}
        disabled={clearing}
      >
        {clearing ? "Clearing…" : "Clear Announcements"}
      </button>

      <button
        className="btn btn--secondary"
        onClick={clearLogs}
      >
        Clear Logs
      </button>

      <button
        className="btn btn--secondary"
        onClick={() => navigate("main")}
      >
        Back
      </button>
    </div>
  );
}