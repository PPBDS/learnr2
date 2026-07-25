"use strict";
const { test, expect, chromium } = require("@playwright/test");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { renderPage } = require("./fixtures");

// These tests specifically check survival across a *full browser restart*,
// not just a page reload -- the standard test() fixture gives every test a
// fresh, throwaway profile, which is the wrong tool for this. A real user
// quits and reopens the *same* installed browser (same profile on disk), so
// here we drive chromium.launchPersistentContext() by hand against one
// fixed profile directory, closing and relaunching it mid-test.
//
// A computer restart is not independently different from this as far as
// localStorage is concerned: it's always synchronously flushed to a
// disk-backed store (SQLite/LevelDB) inside the browser's profile
// directory, not held only in memory, so an OS reboot doesn't touch it any
// more than quitting the browser does.

async function withPersistentBrowser(profileDir, fn) {
  const context = await chromium.launchPersistentContext(profileDir, { headless: true });
  try {
    const page = context.pages()[0] || (await context.newPage());
    await fn(page);
  } finally {
    await context.close();
  }
}

test.describe("progress survives closing and reopening the browser", () => {
  test("served over http: answer survives a full browser close + relaunch", async () => {
    const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), "learnr2-profile-http-"));
    try {
      await withPersistentBrowser(profileDir, async (page) => {
        await page.goto("http://localhost:4321/single-choice");
        await page.locator("#single-choice-answer-0").check();
        await page.locator(".learnr2-submit").click();
        await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
      });

      // Same profile dir = same simulated "reopen the browser".
      await withPersistentBrowser(profileDir, async (page) => {
        await page.goto("http://localhost:4321/single-choice");
        await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
        await expect(page.locator("#single-choice-answer-0")).toBeChecked();
        await expect(page.locator(".learnr2-submit")).toBeHidden();
      });
    } finally {
      fs.rmSync(profileDir, { recursive: true, force: true });
    }
  });

  test("opened as a local file:// page (how run_tutorial() actually opens tutorials): answer survives a full browser close + relaunch", async () => {
    // Build a standalone static copy: the fixture HTML plus quiz.js/quiz.css
    // side by side, with server-relative asset paths rewritten to relative
    // ones, since there is no server for a file:// page.
    const pageDir = fs.mkdtempSync(path.join(os.tmpdir(), "learnr2-file-fixture-"));
    const quizSrcDir = path.join(__dirname, "..", "..", "inst", "extdata", "quiz");
    fs.copyFileSync(path.join(quizSrcDir, "quiz.js"), path.join(pageDir, "quiz.js"));
    fs.copyFileSync(path.join(quizSrcDir, "quiz.css"), path.join(pageDir, "quiz.css"));

    const html = renderPage("single-choice").replace(/\/quiz\//g, "./");
    const htmlPath = path.join(pageDir, "page.html");
    fs.writeFileSync(htmlPath, html);
    const fileUrl = "file://" + htmlPath.replace(/\\/g, "/");

    const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), "learnr2-profile-file-"));
    try {
      await withPersistentBrowser(profileDir, async (page) => {
        await page.goto(fileUrl);
        await page.locator("#single-choice-answer-0").check();
        await page.locator(".learnr2-submit").click();
        await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
      });

      await withPersistentBrowser(profileDir, async (page) => {
        await page.goto(fileUrl);
        await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
        await expect(page.locator("#single-choice-answer-0")).toBeChecked();
      });
    } finally {
      fs.rmSync(profileDir, { recursive: true, force: true });
      fs.rmSync(pageDir, { recursive: true, force: true });
    }
  });
});
