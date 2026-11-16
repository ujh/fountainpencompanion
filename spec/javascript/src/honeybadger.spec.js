import Honeybadger from "@honeybadger-io/js";
import { shouldNotify } from "honeybadger";

vi.mock("@honeybadger-io/js", () => ({
  default: { configure: vi.fn(), beforeNotify: vi.fn() }
}));

const ourFrame = {
  file: "https://www.fountainpencompanion.com/assets/application-abc.js",
  number: 2,
  method: "load"
};

const notice = (message, backtrace = [ourFrame]) => ({ message, backtrace });

describe("shouldNotify", () => {
  it("reports errors from our code", () => {
    expect(shouldNotify(notice("RangeError: Invalid time value"))).toBe(true);
  });

  it("reports notices without a message or backtrace", () => {
    expect(shouldNotify({})).toBe(true);
  });

  it("drops errors whose every frame comes from a browser extension", () => {
    const backtrace = [
      { file: "chrome-extension://abc/content.js" },
      { file: "moz-extension://abc/content.js" },
      { file: "safari-extension://abc/content.js" },
      { file: "webkit-masked-url://hidden/" }
    ];

    expect(shouldNotify(notice("TypeError: boom", backtrace))).toBe(false);
  });

  it("reports errors that pass through a browser extension and our code", () => {
    const backtrace = [{ file: "chrome-extension://abc/content.js" }, ourFrame];

    expect(shouldNotify(notice("TypeError: boom", backtrace))).toBe(true);
  });

  it.each([
    "UnhandledPromiseRejectionWarning: Unspecified reason",
    "UnhandledPromiseRejectionWarning: {}"
  ])("drops promise rejections without details: %s", (message) => {
    expect(shouldNotify(notice(message))).toBe(false);
  });

  it.each([
    "UnhandledPromiseRejectionWarning: TypeError: Failed to fetch",
    "UnhandledPromiseRejectionWarning: TypeError: NetworkError when attempting to fetch resource.",
    "UnhandledPromiseRejectionWarning: TypeError: Load failed",
    "UnhandledPromiseRejectionWarning: AbortError: The operation was aborted."
  ])("drops requests the browser could not complete: %s", (message) => {
    expect(shouldNotify(notice(message))).toBe(false);
  });

  it.each([
    "Error: TypeError: Failed to fetch the ink list: 500",
    "Error: TypeError: NetworkError when attempting to fetch resource. Status 500",
    "Error: TypeError: Load failed for ink 12",
    "Error: AbortError: The operation was aborted. Retry exhausted"
  ])("reports errors that only mention a network failure: %s", (message) => {
    expect(shouldNotify(notice(message))).toBe(true);
  });

  it.each([
    'UnhandledPromiseRejectionWarning: {"code":"NATIVE_TIMEOUT","requestId":"contentScriptVisibility"}',
    "UnhandledPromiseRejectionWarning: i: Failed to connect to MetaMask",
    'UnhandledPromiseRejectionWarning: Error: Permission denied to access property "then"'
  ])("drops errors raised by browser extensions: %s", (message) => {
    expect(shouldNotify(notice(message))).toBe(false);
  });
});

describe("configuration", () => {
  afterEach(() => {
    document.head.innerHTML = "";
    vi.resetModules();
  });

  it("filters notices with shouldNotify when an API key is present", async () => {
    document.head.innerHTML = '<meta name="honeybadger-api-key" content="key">';
    vi.resetModules();

    const module = await import("honeybadger");

    expect(Honeybadger.configure).toHaveBeenCalledWith(expect.objectContaining({ apiKey: "key" }));
    expect(Honeybadger.beforeNotify).toHaveBeenCalledWith(module.shouldNotify);
  });
});
