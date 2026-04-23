import React, { useEffect, useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { invoke } from "@tauri-apps/api/core";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
};

const SECRETS_KEY = "ialfm_secrets_path";

export default function SetupTab({ appendLog, onBack }: Props) {
  const [secretsPath, setSecretsPath] = useState<string | null>(null);
  const [running, setRunning] = useState(false);

  useEffect(() => {
    try {
      const saved = localStorage.getItem(SECRETS_KEY);
      if (saved) setSecretsPath(saved);
    } catch {
      // ignore
    }
  }, []);

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

    try {
      localStorage.setItem(SECRETS_KEY, result);
    } catch {
      // ignore
    }

    appendLog("✅ Secrets JSON selected:");
    appendLog(result);
  };

  const checkNodeToolchain = async () => {
    setRunning(true);

    try {
      appendLog(">> Checking Node.js / npm…");

      const announceDir = await invoke<string>("get_announce_dir");
      appendLog(">> Announcement tools directory:");
      appendLog(announceDir);

      const output = await invoke<string>("check_node_toolchain");

      if (output) {
        appendLog(">> Toolchain check result:");
        appendLog(output);
      }

      appendLog("✅ Node.js / npm check completed.");
    } catch (err: any) {
      appendLog("❌ Node.js / npm check failed:");
      appendLog(String(err));
    } finally {
      setRunning(false);
    }
  };

  const runSetup = async () => {
    if (!secretsPath) {
      appendLog("❌ Please select the secrets JSON file.");
      return;
    }

    setRunning(true);

    try {
      const announceDir = await invoke<string>("get_announce_dir");

      appendLog(">> Running npm install in:");
      appendLog(announceDir);

      const output = await invoke<string>("run_npm_install");

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

  const clearSecrets = () => {
    setSecretsPath(null);
    try {
      localStorage.removeItem(SECRETS_KEY);
    } catch {
      // ignore
    }
    appendLog("✅ Secrets cleared from this device.");
  };

  return (
    <div className="vstack">
      <button
        className="btn btn--primary"
        onClick={checkNodeToolchain}
        disabled={running}
      >
        1. Check Node.js / npm
      </button>

      <button
        className="btn btn--primary"
        onClick={selectSecrets}
        disabled={running}
      >
        2. Select Secrets JSON
      </button>

      <button
        className="btn btn--primary"
        onClick={runSetup}
        disabled={!secretsPath || running}
      >
        3. Run Setup
      </button>

      <button
        className="btn btn--primary"
        onClick={clearSecrets}
        disabled={running}
      >
        4. Clear Secrets (optional)
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