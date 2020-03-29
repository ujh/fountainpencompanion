let inBrandSelector = false;

export const keyDownListener = f => {
  const listener = e => {
    if (inBrandSelector) return;

    f(e);
  };
  document.addEventListener("keydown", listener);
  return () => {
    document.removeEventListener("keydown", listener);
  };
};
export const setInBrandSelector = value => {
  inBrandSelector = value;
};
