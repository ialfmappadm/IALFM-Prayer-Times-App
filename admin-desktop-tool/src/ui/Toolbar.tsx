import {
  Home,
  Trash2,
  PanelTop,
  PanelLeft,
  PanelRight,
} from "lucide-react";

type Layout = "top" | "left" | "right";

type Props = {
  layout: Layout;
  onHome: () => void;
  onClearConsole: () => void;
  onLayoutTop: () => void;
  onLayoutLeft: () => void;
  onLayoutRight: () => void;
};

export default function Toolbar({
  layout,
  onHome,
  onClearConsole,
  onLayoutTop,
  onLayoutLeft,
  onLayoutRight,
}: Props) {
  return (
    <div className="toolbar">
      {/* PRIMARY ACTIONS */}
      <div className="toolbar__section">
        <button className="icon-btn" onClick={onHome} title="Home">
          <Home size={18} />
        </button>

        <button
          className="icon-btn"
          onClick={onClearConsole}
          title="Clear Console"
        >
          <Trash2 size={18} />
        </button>
      </div>

      {/* LAYOUT TOGGLES */}
      <div className="toolbar__section">
        <button
          className={`icon-btn layout-btn ${
            layout === "top" ? "is-active" : ""
          }`}
          onClick={onLayoutTop}
          title="Top Layout"
        >
          <PanelTop size={16} />
        </button>

        <button
          className={`icon-btn layout-btn ${
            layout === "left" ? "is-active" : ""
          }`}
          onClick={onLayoutLeft}
          title="Left Layout"
        >
          <PanelLeft size={16} />
        </button>

        <button
          className={`icon-btn layout-btn ${
            layout === "right" ? "is-active" : ""
          }`}
          onClick={onLayoutRight}
          title="Right Layout"
        >
          <PanelRight size={16} />
        </button>
      </div>
    </div>
  );
}
