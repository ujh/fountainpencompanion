import React, { useState, useEffect } from "react";
import { createRoot } from "react-dom/client";

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("new_collected_ink");
  const el = document.getElementById("ink-search-hint");
  if (!form || !el) return;

  const root = createRoot(el);
  root.render(<InkSearchHint form={form} />);
});

const InkSearchHint = ({ form }) => {
  const [href, setHref] = useState("/brands");
  useEffect(() => {
    const inkInputs = [
      form.collected_ink_brand_name,
      form.collected_ink_line_name,
      form.collected_ink_ink_name,
    ];
    inkInputs.forEach((input) => {
      document.addEventListener("change", listener);
    });
    function listener() {
      const ink_string = inkInputs
        .map((input) => input.value)
        .join(" ")
        .trim();
      if (!ink_string) return;

      const search_string = encodeURIComponent(ink_string);
      setHref(`/inks?q=${search_string}`);
    }
    listener();
  }, []);
  return (
    <div className="fpc-hint alert alert-secondary">
      Did you know that you can add inks via the <a href={href}>ink search</a>{" "}
      for less manual entry?
    </div>
  );
};
