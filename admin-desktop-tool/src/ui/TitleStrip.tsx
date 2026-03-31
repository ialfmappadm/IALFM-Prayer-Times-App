import React from "react";

export default function TitleStrip({ title }: { title: string }) {
  return (
    <div className="title-strip">
      {title}
    </div>
  );
}