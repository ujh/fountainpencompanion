let inBrandSelector = false;

export const keyDownListener = f => {
  const listener = e => {
    if (inBrandSelector) return;
    console.log(e);
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
