import React, { useMemo, useState } from "react";
import Toolbar from "./ui/Toolbar";
import TitleStrip from "./ui/TitleStrip";
import Tabs, { TabKey } from "./ui/Tabs";
import SetupTab from "./tabs/SetupTab";
import NotificationTab from "./tabs/NotificationTab";
import UtilityTab from "./tabs/UtilityTab";
import Console from "./ui/Console";

/* ---------- App ---------- */
type Layout = "top" | "left" | "right";

export default function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("setup");
  const [layout, setLayout] = useState<Layout>("top");
  const [consoleLines, setConsoleLines] = useState<string[]>([
    ">> Console attached.",
  ]);

  /**
   * Global busy flag:
   * - shared by SetupTab + NotificationTab
   * - keeps controls greyed out while async work is running
   */
  const [busy, setBusy] = useState(false);

  const appendLog = (msg: string) =>
    setConsoleLines((prev) => [...prev, msg]);

  const clearConsole = () => setConsoleLines([]);

  const shellClass = useMemo(() => {
    if (layout === "left") return "app-shell toolbar-left";
    if (layout === "right") return "app-shell toolbar-right";
    return "app-shell";
  }, [layout]);

  return (
    <div className={shellClass}>
      {/* Toolbar */}
      <Toolbar
        onHome={() => {
          if (!busy) setActiveTab("setup");
        }}
        onClearConsole={() => {
          if (!busy) clearConsole();
        }}
        onLayoutTop={() => {
          if (!busy) setLayout("top");
        }}
        onLayoutLeft={() => {
          if (!busy) setLayout("left");
        }}
        onLayoutRight={() => {
          if (!busy) setLayout("right");
        }}
      />

      {/* Title */}
      <TitleStrip title="IALFM Desktop Admin Tool" />

      {/* Content */}
      <main className="content-wrap">
        <Tabs
          active={activeTab}
          tabs={[
            { key: "setup", label: "Setup" },
            { key: "publish", label: "Notifications" },
            { key: "utilities", label: "Utilities" },
          ]}
          onSelect={(nextTab) => {
            if (!busy) setActiveTab(nextTab);
          }}
        />

        <section className="content-inner">
          {activeTab === "setup" && (
            <SetupTab
              appendLog={appendLog}
              onBack={() => setActiveTab("publish")}
              busy={busy}
              setBusy={setBusy}
            />
          )}

          {activeTab === "publish" && (
            <NotificationTab
              appendLog={appendLog}
              onBack={() => setActiveTab("setup")}
              busy={busy}
              setBusy={setBusy}
            />
          )}

          {activeTab === "utilities" && (
            <UtilityTab
              appendLog={appendLog}
              onBack={() => setActiveTab("setup")}
            />
          )}
        </section>
      </main>

      {/* Console */}
      <Console title="Console" lines={consoleLines} />
    </div>
  );
}