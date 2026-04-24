import React, { useEffect, useMemo, useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { invoke } from "@tauri-apps/api/core";
import {
  runAdminAction,
  adminButtonClass,
  adminButtonStyle,
} from "../utils/adminUi";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
  busy: boolean;
  setBusy: React.Dispatch<React.SetStateAction<boolean>>;
};

const SECRETS_KEY = "ialfm_secrets_path";

export default function SetupTab({
  appendLog,
  onBack,
  busy,
  setBusy,
}: Props) {
  const [secretsPath, setSecretsPath] = useState<string | null>(null);

  /**
   * Restore any previously selected secrets file from localStorage.
   * This keeps the admin workflow smoother across app restarts.
   */
  useEffect(() => {
    try {
      const saved = localStorage.getItem(SECRETS_KEY);
      if (saved) {
        setSecretsPath(saved);
      }
    } catch {
      // ignore localStorage failures
    }
  }, []);

  /**
   * Reusable visual fallback for busy/disabled buttons.
   * CSS should already be doing most of the work, but this makes the
   * disabled state more obvious even if CSS is still being tuned.
   */
  const disabledButtonStyle = useMemo<React.CSSProperties | undefined>(() => {
    return adminButtonStyle(busy);
  }, [busy]);

  /**
   * Step 1: Choose the Firebase Admin / service-account JSON file.
   */
  const selectSecrets = async () => {
    if (busy) return;

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
      // ignore storage failure
    }

    appendLog("✅ Secrets JSON selected:");
    appendLog(result);
  };

  /**
   * Step 2: Check whether node and npm are available on this machine.
   * Also prints the announce tools directory for visibility.
   */
  const checkNodeToolchain = async () => {
    await runAdminAction(setBusy, async () => {
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
      }
    });
  };

  /**
   * Step 3: Run npm install in the announce tools folder.
   * Requires a selected secrets file first.
   */
  const runSetup = async () => {
    if (!secretsPath) {
      appendLog("❌ Please select the secrets JSON file.");
      return;
    }

    await runAdminAction(setBusy, async () => {
      try {
        const announceDir = await invoke<string>("get_announce_dir");

        //await new Promise((resolve) => setTimeout(resolve, 2000)); delay to make button look disabled

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
      }
    });
  };

  /**
   * Optional convenience action:
   * forget the saved secrets path from this device.
   */
  const clearSecrets = () => {
    if (busy) return;

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
        className={adminButtonClass(busy)}
        onClick={checkNodeToolchain}
        disabled={busy}
        style={disabledButtonStyle}
      >
        1. Check Node.js / npm
      </button>

      <button
        className={adminButtonClass(busy)}
        onClick={selectSecrets}
        disabled={busy}
        style={disabledButtonStyle}
      >
        2. Select Secrets JSON
      </button>

      <button
        className={adminButtonClass(busy || !secretsPath)}
        onClick={runSetup}
        disabled={!secretsPath || busy}
        style={busy || !secretsPath ? disabledButtonStyle : undefined}
      >
        3. Run Setup
      </button>

      <button
        className={adminButtonClass(busy)}
        onClick={clearSecrets}
        disabled={busy}
        style={disabledButtonStyle}
      >
        4. Clear Secrets (optional)
      </button>

      <button
        className={adminButtonClass(busy)}
        onClick={onBack}
        disabled={busy}
        style={disabledButtonStyle}
      >
        Back
      </button>
    </div>
  );
}