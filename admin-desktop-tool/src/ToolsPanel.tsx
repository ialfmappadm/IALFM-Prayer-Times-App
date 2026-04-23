// src/ToolsPanel.tsx
import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";

const CLEAR_SCRIPT = "announce/clear_announcements_force.js";

type Props = {
  navigate: (to: string) => void;
  appendLog: (line: string) => void;
  clearLogs: () => void;
};

export default function ToolsPanel({ navigate, appendLog, clearLogs }: Props) {
  const [clearing, setClearing] = useState(false);

  async function clearAnnouncements() {
    if (clearing) return;
    setClearing(true);

    try {
      appendLog("✅ EXECUTING ToolsPanel (Clear)");
      appendLog("Running clear_announcements_force.js…");

      const out = await invoke("run_node_script", {
        payload: {
          scriptPath: CLEAR_SCRIPT,
          args: [],
        },
      });

      appendLog(String(out));
      appendLog("✅ Announcements cleared");
    } catch (err) {
      appendLog(`❌ Clear failed: ${err}`);
    } finally {
      setClearing(false);
    }
  }

  return (
    <>
      <h3>Utility Tools</h3>

      <button onClick={clearAnnouncements} disabled={clearing}>
        {clearing ? "Clearing…" : "Clear Announcements"}
      </button>

      <button onClick={clearLogs}>Clear Logs</button>
      <button onClick={() => navigate("main")}>Back</button>
    </>
  );
}