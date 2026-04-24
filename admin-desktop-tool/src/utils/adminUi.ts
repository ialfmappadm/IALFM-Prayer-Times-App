import type React from "react";

export type SetBusy = React.Dispatch<React.SetStateAction<boolean>>;

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

/**
 * Runs async work while keeping the UI busy for at least `minMs`.
 * This prevents the disabled state from flashing too quickly on fast commands.
 */
export async function runAdminAction<T>(
  setBusy: SetBusy,
  work: () => Promise<T>,
  minMs = 700
): Promise<T> {
  const startedAt = Date.now();
  setBusy(true);

  try {
    return await work();
  } finally {
    const elapsed = Date.now() - startedAt;
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
 * Optional inline backup styling if you want an extra visible disabled look.
 * Safe even if CSS already styles .is-busy / :disabled.
 */
export function adminButtonStyle(busy: boolean): React.CSSProperties | undefined {
  if (!busy) return undefined;

  return {
    opacity: 1,
    filter: "none",
    cursor: "not-allowed",
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
  };
}