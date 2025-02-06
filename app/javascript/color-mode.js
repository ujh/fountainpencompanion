/*!
 * Color mode toggler for Bootstrap's docs (https://getbootstrap.com/)
 * Copyright 2011-2023 The Bootstrap Authors
 * Licensed under the Creative Commons Attribution 3.0 Unported License.
 */
(() => {
  "use strict";

  const getPreferredTheme = () => {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  };

  const setTheme = (theme) => {
    document.documentElement.setAttribute("data-bs-theme", theme);
  };

  setTheme(getPreferredTheme());

  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    setTheme(getPreferredTheme());
  });
})();
