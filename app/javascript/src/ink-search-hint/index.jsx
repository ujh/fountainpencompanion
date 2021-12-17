import React, { useState, useEffect } from "react";
import ReactDOM from "react-dom";

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("new_collected_ink");
  const el = document.getElementById("ink-search-hint");
  if (!form || !el) return;

  ReactDOM.render(<InkSearchHint form={form} />, el);
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
    <div className="hint">
      Did you know that you can add inks via the <a href={href}>ink search?</a>
    </div>
  );
};
