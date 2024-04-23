let inBrandSelector = false;

export const keyDownListener = (f) => {
  const listener = (e) => {
    if (inBrandSelector) return;
    if (e.ctrlKey || e.shiftKey || e.altKey || e.metaKey) return;

    f(e);
  };
  document.addEventListener("keydown", listener);
  return () => {
    document.removeEventListener("keydown", listener);
  };
};
export const setInBrandSelector = (value) => {
  inBrandSelector = value;
};
