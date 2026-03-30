import React from "react";

export type TabKey = "setup" | "publish" | "utilities";

type Props = {
  active: TabKey;
  tabs: { key: TabKey; label: string }[];
  onSelect: (k: TabKey) => void;
};

export default function Tabs({ active, tabs, onSelect }: Props) {
  return (
    <div className="tabs">
      <div className="tabs__list tabs__list--left">
        {tabs.map(t => (
          <button
            key={t.key}
            className={`tabs__item ${active === t.key ? "is-active" : ""}`}
            onClick={() => onSelect(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>
    </div>
  );
}
