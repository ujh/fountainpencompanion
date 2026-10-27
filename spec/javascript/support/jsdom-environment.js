const JSDOMEnvironment = require("jest-environment-jsdom").default;

// jsdom lacks the Fetch API and the streams msw needs, so take them from Node.
const NODE_GLOBALS = [
  "AbortController",
  "AbortSignal",
  "BroadcastChannel",
  "Headers",
  "ReadableStream",
  "Request",
  "Response",
  "TextDecoder",
  "TextDecoderStream",
  "TextEncoder",
  "TextEncoderStream",
  "TransformStream",
  "WritableStream",
  "clearImmediate",
  "setImmediate",
  "structuredClone"
];

class MswJSDOMEnvironment extends JSDOMEnvironment {
  constructor(config, context) {
    super(config, context);
    this.customExportConditions = [""];
    for (const name of NODE_GLOBALS) this.global[name] = globalThis[name];
    this.global.fetch = this.fetch.bind(this);
    this.pageClosed = new AbortController();
  }

  // Node's fetch has no document, so resolve relative URLs like a browser. Requests
  // still in flight when the test file ends never settle, as on a closed page.
  fetch(input, init = {}) {
    const url = typeof input === "string" ? new URL(input, this.global.location.href) : input;
    const { signal } = this.pageClosed;
    const request = fetch(url, {
      ...init,
      signal: init.signal ? AbortSignal.any([init.signal, signal]) : signal
    });
    return new Promise((resolve, reject) => {
      request.then(
        (response) => signal.aborted || resolve(response),
        (error) => signal.aborted || reject(error)
      );
    });
  }

  async teardown() {
    this.pageClosed.abort();
    await super.teardown();
  }
}

module.exports = MswJSDOMEnvironment;
