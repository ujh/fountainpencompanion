import "@testing-library/jest-dom";
import "regenerator-runtime/runtime";

// jsdom does not implement the canvas API; chart components call getContext.
// Stub it so suites that render charts don't emit "Not implemented:
// HTMLCanvasElement.prototype.getContext" errors.
HTMLCanvasElement.prototype.getContext = () => null;

// jsdom cannot navigate. Components redirect via window.location.href on a 401
// (e.g. the background /account sync in useHiddenFields when unauthenticated),
// which jsdom reports as an "Not implemented: navigation" error on
// console.error. window.location and its href setter are both non-configurable
// so the assignment can't be stubbed; instead drop only this known, benign
// jsdom message and let every other console.error through. The error object
// originates in jsdom's realm, so match on its message rather than instanceof.
const originalConsoleError = console.error;
console.error = (...args) => {
  const message = String(args[0]?.message ?? args[0] ?? "");
  if (message.includes("Not implemented: navigation")) return;
  originalConsoleError(...args);
};

// The same background /account sync logs retry messages via console.log when
// the request fails (no server in unit tests). Drop those benign debug logs.
const originalConsoleLog = console.log;
console.log = (...args) => {
  const message = String(args[0] ?? "");
  if (message.startsWith("Retrying")) return;
  originalConsoleLog(...args);
};
