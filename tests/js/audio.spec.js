"use strict";
const { test, expect } = require("@playwright/test");
const { canonicalSubmission, sha256 } = require("./helpers");

// The voice-recording tests need a browser that answers getUserMedia().
// Playwright's default headless shell never does (the promise hangs), so
// these run on the full Chromium build in its new headless mode, with the
// fake microphone (a tone) and the permission granted up front so no prompt
// appears. quiz.spec.js stays on the default browser.
test.use({
  channel: "chromium",
  permissions: ["microphone"],
  launchOptions: { args: ["--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream"] }
});

test.describe("voice recording (allow_audio)", () => {
  const savedState = (page) => page.evaluate(() => {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key.startsWith("learnr2-")) continue;
      try { return JSON.parse(localStorage.getItem(key)); } catch (e) {}
    }
    return null;
  });

  test("Record, Stop and Submit store the recording as a data URL, which survives a reload behind Edit Answer", async ({ page }) => {
    await page.goto("/reflection-audio");
    await expect(page.locator("textarea")).toBeHidden();
    await expect(page.locator(".learnr2-audio-hint")).toContainText("up to 1:00");
    await expect(page.locator(".learnr2-audio-notice")).toHaveCount(0);
    const button = page.locator(".learnr2-audio-record");
    await expect(button).toHaveText("Record");

    await button.click();
    await expect(button).toHaveText("Stop");
    await expect(button).toHaveClass(/learnr2-audio-recording/);
    await expect(page.locator(".learnr2-audio-timer")).toContainText("Recording");
    await page.waitForTimeout(600);
    await button.click();

    await expect(page.locator(".learnr2-audio-player")).toBeVisible();
    await expect(button).toHaveText("Record again");
    await expect(page.locator(".learnr2-audio-timer")).toContainText("Recorded: 0:01");
    expect(await savedState(page)).toBeNull();

    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-submit")).toBeHidden();
    await expect(page.locator(".learnr2-model-answer")).toContainText("A model answer.");
    await expect(page.locator(".learnr2-image-edit")).toHaveText("Edit Answer");
    await expect(button).toBeHidden();
    const state = await savedState(page);
    expect(state.submitted).toBe(true);
    expect(state.value).toBe("");
    expect(state.audio).toMatch(/^data:audio\/webm/);
    expect(state.seconds).toBeGreaterThan(0);

    await page.reload();
    await expect(page.locator(".learnr2-audio-player")).toBeVisible();
    await expect(page.locator(".learnr2-audio-player")).toHaveAttribute("src", /^data:audio\/webm/);
    await expect(page.locator(".learnr2-image-edit")).toBeVisible();
    await expect(page.locator(".learnr2-audio-record")).toBeHidden();
  });

  test("recording stops by itself at max_seconds, and a recording hides the text box", async ({ page }) => {
    await page.goto("/reflection-audio-short");
    await expect(page.locator("textarea")).toBeVisible();
    await page.locator(".learnr2-audio-record").click();
    await expect(page.locator(".learnr2-audio-record")).toHaveText("Stop");
    await expect(page.locator(".learnr2-audio-player")).toBeVisible({ timeout: 5000 });
    await expect(page.locator(".learnr2-audio-record")).toHaveText("Record again");
    await expect(page.locator("textarea")).toBeHidden();
  });

  test("a voice-only question refuses Submit without a recording", async ({ page }) => {
    await page.goto("/reflection-audio");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-feedback")).toHaveText("Record an answer before submitting.");
    await expect(page.locator(".learnr2-submit")).toBeVisible();
  });

  test("Edit Answer reopens only the recorder, and a new recording replaces the old one", async ({ page }) => {
    await page.goto("/reflection-audio");
    const button = page.locator(".learnr2-audio-record");
    await button.click();
    await page.waitForTimeout(400);
    await button.click();
    await expect(page.locator(".learnr2-audio-player")).toBeVisible();
    await page.locator(".learnr2-submit").click();
    const first = (await savedState(page)).audio;

    await page.locator(".learnr2-image-edit").click();
    await expect(page.locator(".learnr2-submit")).toBeVisible();
    await expect(page.locator(".learnr2-editing-note")).toHaveText("Click Record again to replace your recording, then Submit.");
    await expect(page.locator("textarea")).toBeHidden();
    expect((await savedState(page)).editing).toBe(true);
    await expect(button).toHaveText("Record again");

    await button.click();
    await page.waitForTimeout(800);
    await button.click();
    await expect(button).toHaveText("Record again");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-image-edit")).toBeVisible();
    const state = await savedState(page);
    expect(state.editing).toBeUndefined();
    expect(state.audio).toMatch(/^data:audio\/webm/);
    expect(state.audio).not.toBe(first);
  });

  test("the download records the recording as the answer, and Load Answers brings one back", async ({ page }) => {
    await page.goto("/reflection-audio-download");
    await page.fill("#learnr2-info-student-info-name", "Ada Lovelace");
    await page.fill("#learnr2-info-student-info-email", "ada@example.com");
    await page.locator(".learnr2-info .learnr2-submit").click();
    const button = page.locator(".learnr2-audio-record");
    await button.click();
    await page.waitForTimeout(400);
    await button.click();
    await expect(page.locator(".learnr2-audio-player")).toBeVisible();
    await page.locator(".learnr2-question .learnr2-submit").click();

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    const download = await downloadPromise;
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    expect(contents.answers).toHaveLength(1);
    expect(contents.answers[0].id).toBe("reflection-audio");
    expect(contents.answers[0].answer).toMatch(/^data:audio\/webm/);
    expect(contents.fingerprint).toBe(sha256(canonicalSubmission(contents)));

    // A file holding a recording restores it as a submitted answer.
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.locator(".learnr2-audio-player")).toBeHidden();
    await page.locator(".learnr2-load-answers-input").setInputFiles({
      name: "voice.json", mimeType: "application/json",
      buffer: Buffer.from(JSON.stringify({ tutorial: "voice-tutorial", info: contents.info, answers: contents.answers, metadata: {}, time: "abc" }))
    });
    await Promise.all([page.waitForLoadState(), page.locator(".learnr2-confirm-dialog-confirm").click()]);
    await expect(page.locator(".learnr2-audio-player")).toBeVisible();
    await expect(page.locator(".learnr2-audio-player")).toHaveAttribute("src", contents.answers[0].answer);
    await expect(page.locator(".learnr2-image-edit")).toBeVisible();
    const state = await page.evaluate(() => JSON.parse(localStorage.getItem("learnr2-" + location.href.split("#")[0] + "#reflection-audio")));
    expect(state).toEqual({ value: "", audio: contents.answers[0].answer, submitted: true });
  });

  test("a browser that cannot record gets a note in place of Record, and a notice at the top of the page", async ({ page }) => {
    await page.addInitScript(() => { delete window.MediaRecorder; });
    await page.goto("/reflection-audio");
    await expect(page.locator(".learnr2-audio-record")).toHaveCount(0);
    await expect(page.locator(".learnr2-audio-unsupported")).toContainText("works in Chrome or Edge");
    await expect(page.locator(".learnr2-audio-notice")).toContainText("record only in Chrome or Edge");
    await expect(page.locator(".learnr2-submit")).toBeVisible();
  });

  test("a page with no voice question gets no notice, even where recording is unsupported", async ({ page }) => {
    await page.addInitScript(() => { delete window.MediaRecorder; });
    await page.goto("/reflection-image");
    await expect(page.locator(".learnr2-audio-notice")).toHaveCount(0);
  });

  test("a denied microphone is reported, and the question stays open", async ({ page }) => {
    await page.addInitScript(() => {
      navigator.mediaDevices.getUserMedia = () => Promise.reject(Object.assign(new Error("denied"), { name: "NotAllowedError" }));
    });
    await page.goto("/reflection-audio");
    await page.locator(".learnr2-audio-record").click();
    await expect(page.locator(".learnr2-audio-error")).toContainText("microphone is blocked");
    await expect(page.locator(".learnr2-audio-record")).toHaveText("Record");
  });

  test("the recorder is a labelled group and the timer is a live region", async ({ page }) => {
    await page.goto("/reflection-audio");
    await expect(page.locator(".learnr2-audio")).toHaveAttribute("role", "group");
    await expect(page.locator(".learnr2-audio")).toHaveAttribute("aria-label", "Voice recording");
    await expect(page.locator(".learnr2-audio-timer")).toHaveAttribute("aria-live", "polite");
  });
});
