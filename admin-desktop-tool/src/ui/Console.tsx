import React from "react";

type Props = {
  title?: string;
  lines?: string[];
};

export default function Console({ title = "Console", lines = [] }: Props) {
  return (
    <div className="console">
      <div className="console__head">{title}</div>
      <div className="console__body">
        {lines.length ? lines.join("\n") : " "}
      </div>
    </div>
  );
}