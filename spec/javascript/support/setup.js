import "@testing-library/jest-dom/vitest";
import process from "node:process";
import { afterEach } from "vitest";

// jsdom does not implement the canvas API; chart components call getContext.
// Stub it so suites that render charts don't emit "Not implemented:
// HTMLCanvasElement.prototype.getContext" errors.
HTMLCanvasElement.prototype.getContext = () => null;

// jsdom cannot navigate. fetch.js redirects via window.location.href on a 401,
// which jsdom reports as a "Not implemented: navigation" error.
// window.location and its href setter are both non-configurable so the
// assignment can't be stubbed; instead drop only this known, benign jsdom
// message. jsdom writes it to the console it was created with, before Vitest
// replaced globalThis.console, so filter it where it reaches process.stderr.
const originalStderrWrite = process.stderr.write.bind(process.stderr);
process.stderr.write = (chunk, ...rest) => {
  if (String(chunk).includes("Not implemented: navigation")) return true;
  return originalStderrWrite(chunk, ...rest);
};

// fetch.js logs "Retrying" via console.log when a GET fails (no server in unit
// tests). Drop those benign debug logs.
const originalConsoleLog = console.log;
console.log = (...args) => {
  const message = String(args[0] ?? "");
  if (message.startsWith("Retrying")) return;
  originalConsoleLog(...args);
};

afterEach(() => {
  window.history.replaceState(null, "", "/");
});
