"use strict";
const { defineConfig, devices } = require("@playwright/test");

module.exports = defineConfig({
  testDir: ".",
  // deployed-smoke.spec.js targets a real deployed URL via
  // playwright.smoke.config.js instead -- it has no use for (and would
  // needlessly wait on) the local webServer below.
  testIgnore: "deployed-smoke.spec.js",
  timeout: 15000,
  fullyParallel: true,
  // Keep this modest: many concurrent Chromium instances hitting the one
  // dev server on a constrained machine causes flaky navigation failures
  // that have nothing to do with the code under test.
  workers: 2,
  reporter: [["list"]],
  use: {
    baseURL: "http://localhost:4321",
    trace: "retain-on-failure"
  },
  webServer: {
    command: "node server.js",
    port: 4321,
    reuseExistingServer: !process.env.CI
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }]
});
