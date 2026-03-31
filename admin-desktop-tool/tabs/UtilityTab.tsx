import React from "react";
import { invoke } from "@tauri-apps/api/core";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
};

export default function UtilityTab({ appendLog, onBack }: Props) {
  const run = async (scriptPath: string, args: string[]) => {
    try {
      appendLog(`>> Running ${scriptPath}…`);

      const out = await invoke<string>("run_node_script", {
        payload: {
          scriptPath,
          args,
        },
      });

      if (out) appendLog(out);
      appendLog("✅ Done.");
    } catch (e: any) {
      appendLog(`❌ Failed: ${String(e)}`);
    }
  };

  return (
    <div className="vstack">
      <button
        className="btn btn--primary"
        onClick={() =>
          run("clear_announcements_force.js", [
            "--tz", "America/Chicago",
            "--stamp-via-shell",
            "--blank-card",
            "--notify",
            "--topic", "allUsers",
          ])
        }
      >
        Clear Notifications (Mobile App)
      </button>

      <button
        className="btn btn--primary"
        onClick={() =>
          run("rc_prune_and_lock.js", [
            "--tz", "America/Chicago",
            "--stamp-via-shell",
            "--notify",
            "--topic", "allUsers",
            "--project", "ialfm-prayer-times",
          ])
        }
      >
        Prune Expired Notifications
      </button>

      <button
        className="btn btn--primary"
        onClick={onBack}
      >
        Back
      </button>
    </div>
  );
}