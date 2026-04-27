import React, { useEffect, useMemo, useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { invoke } from "@tauri-apps/api/core";

import { AdminButton } from "../ui/AdminControls";
import { runAdminAction } from "../utils/adminUi";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
  busy: boolean;
  setBusy: React.Dispatch<React.SetStateAction<boolean>>;
};

const SECRETS_KEY = "ialfm_secrets_path";

/**
 * SetupTab
 * - Admin-visible setup for toolchain + secrets + announce tooling deps
 * - Uses the shared AdminControls so all buttons look/behave consistently
 */
export default function SetupTab({ appendLog, onBack, busy, setBusy }: Props) {
  const [secretsPath, setSecretsPath] = useState<string | null>(null);

  /**
   * Restore secrets path for convenience. This is admin tooling: visibility matters.
   */
  useEffect(() => {
    try {
      const saved = localStorage.getItem(SECRETS_KEY);
      if (saved) setSecretsPath(saved);
    } catch {
      // ignore localStorage issues
    }
  }, []);

  /**
   * A derived "UI busy" state for the Run Setup button:
   * - If secretsPath is missing, treat the button as disabled/greyed.
   * - This keeps visuals consistent with the rest of the app.
   */
  const setupBlocked = useMemo(() => !secretsPath, [secretsPath]);

  /**
   * Step 2: Select secrets JSON (stored locally for later actions).
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
      // ignore write failures
    }

    appendLog("✅ Secrets JSON selected:");
    appendLog(result);
  };

  /**
   * Step 1: Check Node/npm presence and versions.
   * Uses runAdminAction to ensure busy visuals are perceivable.
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
   * Step 3: Run npm install in announce tooling folder.
   * Requires secrets to be selected first.
   */
  const runSetup = async () => {
    if (!secretsPath) {
      appendLog("❌ Please select the secrets JSON file.");
      return;
    }

    await runAdminAction(setBusy, async () => {
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
      }
    });
  };

  /**
   * Optional convenience step: clear locally saved secrets path.
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
      <AdminButton busy={busy} onClick={checkNodeToolchain}>
        1. Check Node.js / npm
      </AdminButton>

      <AdminButton busy={busy} onClick={selectSecrets}>
        2. Select Secrets JSON
      </AdminButton>

    <AdminButton busy={busy || setupBlocked} onClick={runSetup}>
        3. Run Setup
      </AdminButton>

      <AdminButton busy={busy} onClick={clearSecrets}>
        4. Clear Secrets (optional)
      </AdminButton>

      <AdminButton busy={busy} onClick={onBack}>
        Back
      </AdminButton>
    </div>
  );
}