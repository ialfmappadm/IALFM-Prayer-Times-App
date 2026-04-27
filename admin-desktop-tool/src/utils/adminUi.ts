import type React from "react";

export type SetBusy = React.Dispatch<React.SetStateAction<boolean>>;

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

/**
 * Wait until the browser has had a chance to render + paint the busy state.
 * Two RAFs is a reliable way to ensure the visual disabled state is actually shown.
 */
function nextPaint(): Promise<void> {
  return new Promise((resolve) => {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => resolve());
    });
  });
}

/**
 * Runs async work while keeping the UI visibly busy long enough to be perceived.
 *
 * Behavior:
 * 1. set busy=true
 * 2. wait for paint so buttons/inputs visually grey out
 * 3. run async work
 * 4. keep busy=true for at least minMs total after the painted state
 *
 * This prevents fast commands from flashing so quickly that the user sees no feedback.
 */
export async function runAdminAction<T>(
  setBusy: SetBusy,
  work: () => Promise<T>,
  minMs = 1100
): Promise<T> {
  setBusy(true);

  // Let React commit and the browser paint the disabled/busy visuals first.
  await nextPaint();

  const startedAt = performance.now();

  try {
    return await work();
  } finally {
    const elapsed = performance.now() - startedAt;
    if (elapsed < minMs) {
      await sleep(minMs - elapsed);
    }
    setBusy(false);
  }
}

/**
 * Shared class helper for primary action buttons.
 */
export function adminButtonClass(busy: boolean) {
  return busy ? "btn btn--primary is-busy" : "btn btn--primary";
}

/**
 * Authoritative inline busy style for big action buttons.
 * This guarantees the button goes grey even if CSS specificity changes later.
 */
export function adminButtonStyle(
  busy: boolean
): React.CSSProperties | undefined {
  if (!busy) return undefined;

  return {
    opacity: 1,
    background: "#94a3b8",
    color: "#e2e8f0",
    boxShadow: "none",
    filter: "grayscale(0.45) brightness(0.92)",
    cursor: "not-allowed",
    pointerEvents: "none",
  };
}

/**
 * Shared disabled styling for inputs and textareas.
 */
export function adminInputStyle(
  busy: boolean
): React.CSSProperties | undefined {
  if (!busy) return undefined;

  return {
    opacity: 1,
    background: "#e2e8f0",
    color: "#64748b",
    cursor: "not-allowed",
  };
}

/**
 * Shared style for tiny inline actions like Remove.
 */
export function adminInlineActionStyle(
  busy: boolean,
  color = "#b91c1c"
): React.CSSProperties {
  return {
    all: "unset",
    cursor: busy ? "not-allowed" : "pointer",
    fontSize: "12px",
    fontWeight: 600,
    color,
    opacity: busy ? 0.5 : 1,
    filter: busy ? "grayscale(0.25)" : "none",
    pointerEvents: busy ? "none" : "auto",
  };
}