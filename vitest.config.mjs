import { readdirSync } from "node:fs";
import path from "node:path";
import { defineConfig } from "vitest/config";

const src = path.resolve(import.meta.dirname, "app/javascript/src");

// Specs import app modules by their path under src (e.g. "admin/...", "fetch").
const alias = readdirSync(src)
  .filter((entry) => !entry.includes(".spec."))
  .map((entry) => {
    const name = entry.replace(/\.jsx?$/, "");
    return { find: new RegExp(`^${name}(?=/|$)`), replacement: path.join(src, name) };
  });

export default defineConfig({
  resolve: { alias },
  test: {
    globals: true,
    environment: "jsdom",
    environmentOptions: { jsdom: { url: "http://fpc.invalid/" } },
    setupFiles: ["spec/javascript/support/setup.js"],
    include: ["{app,spec}/javascript/**/*.spec.{js,jsx}"],
    coverage: {
      enabled: true,
      include: ["app/javascript/**/*.{js,jsx}"],
      reporter: ["html", "lcov", "text-summary"]
    }
  }
});
