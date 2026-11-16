import Honeybadger from "@honeybadger-io/js";

const NOISY_MESSAGES = [
  "UnhandledPromiseRejectionWarning: Unspecified reason",
  "UnhandledPromiseRejectionWarning: {}"
];

const NOISY_MESSAGE_PATTERNS = [
  /TypeError: Failed to fetch$/,
  /TypeError: NetworkError when attempting to fetch resource\.$/,
  /TypeError: Load failed$/,
  /AbortError: The operation was aborted\.$/,
  /"code":"NATIVE_TIMEOUT"/,
  /Failed to connect to MetaMask/,
  /Permission denied to access property "then"/
];

const isExtensionFrame = (frame) =>
  /^(chrome|moz|safari)-extension:\/\//.test(frame.file) ||
  frame.file === "webkit-masked-url://hidden/";

export const shouldNotify = (notice) => {
  if (notice.backtrace && notice.backtrace.every(isExtensionFrame)) return false;

  const message = notice.message ?? "";
  if (NOISY_MESSAGES.includes(message)) return false;
  if (NOISY_MESSAGE_PATTERNS.some((pattern) => pattern.test(message))) return false;

  return true;
};

const apiKey = document.querySelector('meta[name="honeybadger-api-key"]')?.content;
const environment = document.querySelector('meta[name="honeybadger-environment"]')?.content;
const revision = document.querySelector('meta[name="honeybadger-revision"]')?.content;

if (apiKey) {
  Honeybadger.configure({
    apiKey,
    environment: environment || "production",
    revision,
    enableUncaught: false
  });

  Honeybadger.beforeNotify(shouldNotify);
}

export default Honeybadger;
