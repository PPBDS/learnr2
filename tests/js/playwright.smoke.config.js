"use strict";
const { defineConfig, devices } = require("@playwright/test");

// Separate from playwright.config.js on purpose: this suite targets a real
// URL (SMOKE_URL, set by the caller) with no local dev server to manage --
// see deployed-smoke.spec.js and .github/workflows/tutorials.yaml's
// smoke-test job.
module.exports = defineConfig({
  testDir: ".",
  testMatch: "deployed-smoke.spec.js",
  timeout: 30000,
  fullyParallel: false,
  workers: 1,
  retries: 1,
  // The html reporter is what the workflow uploads on failure
  // (tests/js/playwright-report/); without it that artifact step always
  // warned "No files were found". `open: "never"` keeps it from trying to
  // launch a browser on CI.
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    trace: "retain-on-failure"
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }]
});
