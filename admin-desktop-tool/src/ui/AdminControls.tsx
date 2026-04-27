import React, { useMemo } from "react";
import {
  adminButtonClass,
  adminButtonStyle,
  adminInputStyle,
  adminInlineActionStyle,
} from "../utils/adminUi";

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  busy?: boolean;
  variant?: "primary";
};

export function AdminButton({
  busy = false,
  variant = "primary",
  className,
  style,
  disabled,
  ...rest
}: ButtonProps) {
  const isDisabled = (disabled ?? busy) === true;

  const cls = useMemo(() => {
    const base = variant === "primary" ? adminButtonClass(busy) : "btn";
    return className ? `${base} ${className}` : base;
  }, [busy, variant, className]);

  const mergedStyle = useMemo<React.CSSProperties | undefined>(() => {
    const b = adminButtonStyle(busy) ?? {};
    const s = style ?? {};

    // HARD OVERRIDE: guarantees visible disabled state everywhere
    const overrideStyle: React.CSSProperties = isDisabled
      ? {
          backgroundImage: "none",
          backgroundColor: "#94a3b8",
          color: "#0f2432",
          boxShadow: "none",
          filter: "grayscale(0.25) brightness(0.98)",
          opacity: 1,
          cursor: "not-allowed",
          pointerEvents: "none",
        }
      : {};

    // Caller first → busy style → nuclear override (last wins)
    return { ...s, ...b, ...overrideStyle };
  }, [busy, style, isDisabled]);

  return (
    <button
      {...rest}
      data-admin="button"
      className={cls}
      style={mergedStyle}
      disabled={isDisabled}
    />
  );
}

type InputProps = React.InputHTMLAttributes<HTMLInputElement> & {
  busy?: boolean;
};

export function AdminInput({ busy = false, style, disabled, ...rest }: InputProps) {
  const isDisabled = (disabled ?? busy) === true;

  const mergedStyle = useMemo<React.CSSProperties | undefined>(() => {
    const b = adminInputStyle(busy) ?? {};
    const s = style ?? {};
    return { ...s, ...b };
  }, [busy, style]);

  return <input {...rest} data-admin="input" style={mergedStyle} disabled={isDisabled} />;
}

type TextareaProps = React.TextareaHTMLAttributes<HTMLTextAreaElement> & {
  busy?: boolean;
};

export function AdminTextarea({
  busy = false,
  style,
  disabled,
  ...rest
}: TextareaProps) {
  const isDisabled = (disabled ?? busy) === true;

  const mergedStyle = useMemo<React.CSSProperties | undefined>(() => {
    const b = adminInputStyle(busy) ?? {};
    const s = style ?? {};
    return { ...s, ...b };
  }, [busy, style]);

  return (
    <textarea
      {...rest}
      data-admin="textarea"
      style={mergedStyle}
      disabled={isDisabled}
    />
  );
}

type InlineActionProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  busy?: boolean;
  color?: string;
};

export function AdminInlineActionButton({
  busy = false,
  color,
  style,
  disabled,
  ...rest
}: InlineActionProps) {
  const isDisabled = (disabled ?? busy) === true;

  const mergedStyle = useMemo<React.CSSProperties>(() => {
    const base = adminInlineActionStyle(busy, color);
    const s = style ?? {};
    // Caller first, then base (base wins)
    return { ...s, ...base };
  }, [busy, color, style]);

  return (
    <button
      {...rest}
      data-admin="inline"
      type={rest.type ?? "button"}
      style={mergedStyle}
      disabled={isDisabled}
    />
  );
}