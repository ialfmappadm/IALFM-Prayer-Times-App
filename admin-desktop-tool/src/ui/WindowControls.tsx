// src/ui/WindowControls.tsx
import React from "react";
import { Minus, Square, X } from "lucide-react";
import { getCurrentWindow } from "@tauri-apps/api/window";

export default function WindowControls() {
  const win = getCurrentWindow();

  return (
    <div className="win-controls">
      <button
        className="icon-btn"
        title="Minimize"
        onClick={() => win.minimize()}
      >
        <Minus size={14} />
      </button>

      <button
        className="icon-btn"
        title="Maximize"
        onClick={() => win.toggleMaximize()}
      >
        <Square size={14} />
      </button>

      <button
        className="icon-btn"
        title="Close"
        onClick={() => win.close()}
      >
        <X size={14} />
      </button>
    </div>
  );
}