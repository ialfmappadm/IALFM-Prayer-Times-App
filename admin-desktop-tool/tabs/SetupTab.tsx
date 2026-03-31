import React, { useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { invoke } from "@tauri-apps/api/core";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
};

export default function SetupTab({ appendLog, onBack }: Props) {
  const [toolsDir, setToolsDir] = useState<string | null>(null);
  const [secretsPath, setSecretsPath] = useState<string | null>(null);
  const [running, setRunning] = useState(false);

  // Step 1: pick tools directory
  const selectToolsDir = async () => {
    const result = await open({
      directory: true,
      multiple: false,
      title: "Select Announcement Tools Folder",
    });

    if (!result || Array.isArray(result)) {
      appendLog("❌ Tools directory selection cancelled.");
      return;
    }

    setToolsDir(result);
    appendLog("✅ Tools directory selected:");
    appendLog(result);
  };

  // Step 2: pick secrets JSON
  const selectSecrets = async () => {
    const result = await open({
      directory: false,
      multiple: false,
      filters: [{ name: "JSON", extensions: ["json"] }],
      title: "Select Firebase Service Account JSON",
    });

    if (!result || Array.isArray(result)) {
      appendLog("❌ Secrets selection cancelled.");
      return;
    }

    setSecretsPath(result);
    appendLog("✅ Secrets JSON selected:");
    appendLog(result);
  };

  // Step 3: run setup
  const runSetup = async () => {
    if (!toolsDir) {
      appendLog("❌ Please select the tools directory first.");
      return;
    }
    if (!secretsPath) {
      appendLog("❌ Please select the secrets JSON file.");
      return;
    }

    setRunning(true);

    try {
      appendLog(">> Saving setup configuration...");

      await invoke("save_config", {
        toolsDir,
        secretsPath,
        projectId: "ialfm-prayer-times",
      });

      appendLog("✅ Configuration saved.");

      appendLog(">> Running npm install in:");
      appendLog(toolsDir);

      const output = await invoke<string>("run_npm_install", {
        path: toolsDir,
      });

      if (output) {
        appendLog(">> npm install output:");
        appendLog(output);
      }

      appendLog("✅ Setup completed successfully.");
    } catch (err: any) {
      appendLog("❌ Setup failed:");
      appendLog(String(err));
    } finally {
      setRunning(false);
    }
  };

  return (
    <div className="vstack">
      <button
        className="btn btn--primary"
        onClick={selectToolsDir}
        disabled={running}
      >
        1. Select Tools Folder
      </button>

      <button
        className="btn btn--primary"
        onClick={selectSecrets}
        disabled={!toolsDir || running}
      >
        2. Select Secrets JSON
      </button>

      <button
        className="btn btn--primary"
        onClick={runSetup}
        disabled={!toolsDir || !secretsPath || running}
      >
        3. Run Setup
      </button>

      <button
        className="btn btn--primary"
        onClick={onBack}
        disabled={running}
      >
        Back
      </button>
    </div>
  );
}