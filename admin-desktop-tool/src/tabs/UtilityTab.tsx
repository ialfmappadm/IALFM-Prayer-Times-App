import React from "react";

type Props = {
  appendLog: (msg: string) => void;
  onBack: () => void;
};

export default function UtilityTab({ onBack }: Props) {
  return (
    <div className="vstack" style={{ width: "100%", maxWidth: 480 }}>
      <h3 style={{ margin: 0 }}>Utilities</h3>

      <div
        style={{
          width: "100%",
          padding: "16px",
          border: "1px solid #dbe3ec",
          borderRadius: "8px",
          background: "#ffffff",
          color: "#475569",
        }}
      >
        This tab is reserved for future admin tools.
      </div>

      <button className="btn btn--primary" onClick={onBack}>
        Back
      </button>
    </div>
  );
}