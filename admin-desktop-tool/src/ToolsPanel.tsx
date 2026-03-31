// src/ToolsPanel.tsx
import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

const ANNOUNCE_DIR =
  "/Users/syed/AndroidStudioProjects/IALFM/prayer_times_app/tools/announce";
const CLEAR_JS = `${ANNOUNCE_DIR}/clear_announcements_force.js`;

type Props = {
  navigate: (to: string) => void;
  appendLog: (line: string) => void;
  clearLogs: () => void; // ✅ NEW
};

export default function ToolsPanel({ navigate, appendLog, clearLogs }: Props) {
  const [clearing, setClearing] = useState(false);

  async function clearAnnouncements() {
    if (clearing) return;        // hard guard in UI
    setClearing(true);
    try {
      appendLog(`[${now()}] Running script: clear_announcements_force.js`);
      const out = await invoke("run_node_script", {
        path: CLEAR_JS,
        args: ["--project", "ialfm-prayer-times"], // add more flags if your script needs them
      });
      appendLog(String(out));
      appendLog(`[${now()}] ✅ Clear completed.`);
      alert("Announcements cleared.");
    } catch (err) {
      appendLog(`[${now()}] ❌ Clear failed: ${err}`);
      alert(`Clear failed: ${err}`);
    } finally {
      setClearing(false);
    }
  }

  return (
    <div>
      <h3>Utility Tools</h3>

      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <button
          onClick={clearAnnouncements}
          disabled={clearing}
          aria-busy={clearing}
          style={{ opacity: clearing ? 0.6 : 1, cursor: clearing ? "not-allowed" : "pointer" }}
          title={clearing ? "Clearing in progress…" : "Clear remote announcements"}
        >
          {clearing ? "Clearing…" : "Clear Announcements"}
        </button>

        {/* ✅ NEW: Clear the UI log pane */}
        <button onClick={clearLogs} title="Clear the log pane">
          Clear Logs
        </button>
      </div>

      <button onClick={() => navigate("main")}>Back</button>
    </div>
  );
}

function now() {
  return new Date().toLocaleTimeString();
}