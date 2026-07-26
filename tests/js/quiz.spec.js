"use strict";
const { test, expect } = require("@playwright/test");
const nodeCrypto = require("crypto");

const TINY_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
const TINY_GIF_BASE64 = "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBTAA7";

// Writes to the real OS/browser clipboard via the Async Clipboard API, for
// tests that then send a genuine Control+V keypress -- the most realistic
// check available, exercising the actual native paste path a reader's
// browser uses. Chromium only accepts a handful of well-known types here
// (notably image/png) and validates that the bytes actually decode as that
// type, so this can't be used to simulate a wrong-type or corrupt paste.
async function writeImageToClipboard(page, base64, type) {
  await page.evaluate(
    async ({ base64, type }) => {
      const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
      const blob = new Blob([bytes], { type: type });
      await navigator.clipboard.write([new ClipboardItem({ [type]: blob })]);
    },
    { base64: base64, type: type }
  );
}

// For invalid-input cases the real clipboard API refuses to hold (wrong
// MIME type, corrupt/undecodable image bytes), dispatch a synthetic `paste`
// DOM event directly instead. This bypasses the OS clipboard entirely, so
// it's only used where the real clipboard can't represent the scenario --
// the happy-path tests above use the real clipboard + real keypress.
async function dispatchSyntheticPaste(page, selector, bytesOrLength, type, filename) {
  await page.evaluate(
    ({ selector, bytesOrLength, type, filename }) => {
      const el = document.querySelector(selector);
      const bytes =
        typeof bytesOrLength === "number"
          ? new Uint8Array(bytesOrLength)
          : Uint8Array.from(atob(bytesOrLength), (c) => c.charCodeAt(0));
      const file = new File([bytes], filename, { type: type });
      const dt = new DataTransfer();
      dt.items.add(file);
      const event = new ClipboardEvent("paste", { clipboardData: dt, bubbles: true, cancelable: true });
      el.dispatchEvent(event);
    },
    { selector: selector, bytesOrLength: bytesOrLength, type: type, filename: filename }
  );
}

test.describe("single-choice questions", () => {
  test("the correct answer shows positive feedback and hides submit", async ({ page }) => {
    await page.goto("/single-choice");
    await page.locator("#single-choice-answer-0").check();
    await page.locator(".learnr2-submit").click();

    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
    await expect(page.locator(".learnr2-feedback")).toHaveText("Correct!");
    await expect(page.locator(".learnr2-submit")).toBeHidden();
  });

  test("an incorrect answer with allow_retry shows Try Again, which resets the question", async ({ page }) => {
    await page.goto("/single-choice");
    await page.locator("#single-choice-answer-1").check();
    await page.locator(".learnr2-submit").click();

    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-incorrect/);
    await expect(page.locator(".learnr2-try-again")).toBeVisible();

    await page.locator(".learnr2-try-again").click();
    await expect(page.locator(".learnr2-submit")).toBeVisible();
    await expect(page.locator("#single-choice-answer-1")).not.toBeChecked();
  });
});

test.describe("multiple-choice questions", () => {
  test("a partial selection is graded incorrect", async ({ page }) => {
    await page.goto("/multiple-choice");
    await page.locator("#multiple-choice-answer-0").check();
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-incorrect/);
  });

  test("selecting exactly the correct answers is graded correct", async ({ page }) => {
    await page.goto("/multiple-choice");
    await page.locator("#multiple-choice-answer-0").check();
    await page.locator("#multiple-choice-answer-2").check();
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
  });
});

test.describe("text questions", () => {
  test("grading trims whitespace and ignores case", async ({ page }) => {
    await page.goto("/text");
    await page.locator(".learnr2-text-input").fill("  paris  ");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
  });

  test("a wrong answer is graded incorrect", async ({ page }) => {
    await page.goto("/text");
    await page.locator(".learnr2-text-input").fill("London");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-incorrect/);
  });
});

test.describe("reflection questions", () => {
  test("locked type: submitting reveals the model answer and disables the response", async ({ page }) => {
    await page.goto("/reflection-locked");
    await page.locator("textarea").fill("My own explanation.");
    await page.locator(".learnr2-submit").click();

    await expect(page.locator(".learnr2-model-answer")).toBeVisible();
    await expect(page.locator(".learnr2-model-answer")).toContainText("Rayleigh scattering.");
    await expect(page.locator("textarea")).toBeDisabled();
    await expect(page.locator(".learnr2-submit")).toBeHidden();
  });

  test("locked type: state survives a reload", async ({ page }) => {
    await page.goto("/reflection-locked");
    await page.locator("textarea").fill("Persisted answer.");
    await page.locator(".learnr2-submit").click();

    await page.reload();
    await expect(page.locator("textarea")).toHaveValue("Persisted answer.");
    await expect(page.locator("textarea")).toBeDisabled();
    await expect(page.locator(".learnr2-model-answer")).toBeVisible();
  });

  test("editable type: stays editable and can be resubmitted with a revision", async ({ page }) => {
    await page.goto("/reflection-editable");
    await page.locator("textarea").fill("First draft.");
    await page.locator(".learnr2-submit").click();

    await expect(page.locator("textarea")).toBeEnabled();
    await expect(page.locator(".learnr2-submit")).toBeVisible();

    await page.locator("textarea").fill("Revised answer.");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator("textarea")).toHaveValue("Revised answer.");
    await expect(page.locator("textarea")).toBeEnabled();
  });
});

test.describe("image paste (allow_image)", () => {
  test.beforeEach(async ({ context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  });

  test("pasting into the response textarea captures the image", async ({ page }) => {
    // Regression test: paste handling originally lived only on the small
    // box below the textarea. A reader naturally clicks the textarea (the
    // obvious input) and pastes there; that must work too.
    await page.goto("/reflection-image");
    await writeImageToClipboard(page, TINY_PNG_BASE64, "image/png");

    await page.locator("textarea").click();
    await page.keyboard.press("Control+V");

    await expect(page.locator(".learnr2-image-paste-preview")).toBeVisible();
    const src = await page.locator(".learnr2-image-paste-preview").getAttribute("src");
    expect(src).toMatch(/^data:image\/png;base64,/);
  });

  test("plain text pasted into the textarea is unaffected", async ({ page }) => {
    await page.goto("/reflection-image");
    await page.evaluate(async () => {
      await navigator.clipboard.writeText("just some notes");
    });

    await page.locator("textarea").click();
    await page.keyboard.press("Control+V");

    await expect(page.locator("textarea")).toHaveValue("just some notes");
    await expect(page.locator(".learnr2-image-paste-error")).toBeHidden();
  });

  test("pasting directly into the dedicated box also works", async ({ page }) => {
    await page.goto("/reflection-image");
    await writeImageToClipboard(page, TINY_PNG_BASE64, "image/png");

    await page.locator(".learnr2-image-paste").click();
    await page.keyboard.press("Control+V");

    await expect(page.locator(".learnr2-image-paste-preview")).toBeVisible();
  });

  test("a non-PNG image is rejected with an error", async ({ page }) => {
    await page.goto("/reflection-image");
    await dispatchSyntheticPaste(page, ".learnr2-image-paste", TINY_GIF_BASE64, "image/gif", "photo.gif");

    await expect(page.locator(".learnr2-image-paste-error")).toBeVisible();
    await expect(page.locator(".learnr2-image-paste-error")).toContainText("Please paste a PNG image");
    await expect(page.locator(".learnr2-image-paste-preview")).toBeHidden();
  });

  test("an oversized image is rejected with an error", async ({ page }) => {
    await page.goto("/reflection-image");
    // 2MB + 100 bytes, just over quiz.js's MAX_BYTES cap.
    await dispatchSyntheticPaste(
      page,
      ".learnr2-image-paste",
      2 * 1024 * 1024 + 100,
      "image/png",
      "huge.png"
    );

    await expect(page.locator(".learnr2-image-paste-error")).toContainText("too large");
  });

  test("submitting saves text and image together and both survive a reload", async ({ page }) => {
    await page.goto("/reflection-image");
    await writeImageToClipboard(page, TINY_PNG_BASE64, "image/png");

    await page.locator("textarea").fill("Here is my plot.");
    await page.locator("textarea").click();
    await page.keyboard.press("Control+V");
    await expect(page.locator(".learnr2-image-paste-preview")).toBeVisible();

    await page.locator(".learnr2-submit").click();
    await expect(page.locator("textarea")).toBeDisabled();

    await page.reload();
    await expect(page.locator("textarea")).toHaveValue("Here is my plot.");
    await expect(page.locator(".learnr2-image-paste-preview")).toBeVisible();
    const src = await page.locator(".learnr2-image-paste-preview").getAttribute("src");
    expect(src).toMatch(/^data:image\/png;base64,/);
    await expect(page.locator(".learnr2-image-paste")).toHaveClass(/learnr2-image-paste-disabled/);
  });
});

test.describe("student info form", () => {
  test("fields auto-save on blur and are restored on reload", async ({ page }) => {
    await page.goto("/student-info");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    // Blur the last field to force a save without waiting on the debounce.
    await page.locator("body").click();

    await page.reload();
    await expect(page.locator("#learnr2-info-student-info-name")).toHaveValue("Ada Lovelace");
    await expect(page.locator("#learnr2-info-student-info-email")).toHaveValue("ada@example.com");
  });

  test("Submit button confirms a complete entry, and flags a missing required field", async ({ page }) => {
    await page.goto("/student-info");

    const submit = page.locator(".learnr2-info .learnr2-submit");
    const feedback = page.locator(".learnr2-info .learnr2-feedback");

    // Required fields still blank -- Submit should flag it, not silently succeed.
    await submit.click();
    await expect(feedback).toBeVisible();
    await expect(feedback).toHaveClass(/learnr2-feedback-incorrect/);
    await expect(
      page.locator("#learnr2-info-student-info-name")
        .locator("xpath=../div[contains(@class,'learnr2-info-error')]")
    ).toBeVisible();

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await submit.click();
    await expect(feedback).toHaveClass(/learnr2-feedback-correct/);

    // Unlike a graded question(), the form stays editable after Submit --
    // this is data entry, not something to lock.
    await expect(page.locator("#learnr2-info-student-info-name")).toBeEditable();
  });

  test("required fields (name, email) are marked with * and show an inline error when left blank", async ({ page }) => {
    await page.goto("/student-info");

    await expect(page.locator("label[for='learnr2-info-student-info-name']")).toContainText("*");
    await expect(page.locator("label[for='learnr2-info-student-info-email']")).toContainText("*");
    await expect(page.locator("label[for='learnr2-info-student-info-id']")).not.toContainText("*");

    const nameInput = page.locator("#learnr2-info-student-info-name");
    const nameError = nameInput.locator("xpath=../div[contains(@class,'learnr2-info-error')]");

    await nameInput.click();
    await page.locator("body").click(); // blur while still empty
    await expect(nameError).toBeVisible();

    await nameInput.fill("Ada Lovelace");
    await expect(nameError).toBeHidden();
  });
});

test.describe("download answers button", () => {
  test("downloads a JSON file with student info and question answers", async ({ page }) => {
    await page.goto("/download-answers");

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    // Answer the single-choice question correctly, leave the reflection one
    // untouched to confirm unanswered questions are reported as such.
    const singleChoiceQuestion = page.locator(".learnr2-question", {
      has: page.locator("#single-choice-answer-0")
    });
    await singleChoiceQuestion.locator("#single-choice-answer-0").check();
    await singleChoiceQuestion.locator(".learnr2-submit").click();
    await expect(singleChoiceQuestion.locator(".learnr2-feedback")).toBeVisible();

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    const download = await downloadPromise;

    expect(download.suggestedFilename()).toMatch(/^class-101-.*\.json$/);

    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) {
      chunks.push(chunk);
    }
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));

    expect(contents.info).toEqual({ name: "Ada Lovelace", email: "ada@example.com", id: null });
    expect(contents.answers).toHaveLength(2);

    const choiceAnswer = contents.answers.find((a) => a.question === "What is 6 times 7?");
    expect(choiceAnswer.answered).toBe(true);
    expect(choiceAnswer.correct).toBe(true);
    expect(choiceAnswer.yourAnswer).toEqual(["42"]);

    const reflectionAnswer = contents.answers.find((a) => a.question.indexOf("sky is blue") !== -1);
    expect(reflectionAnswer.answered).toBe(false);
    expect(reflectionAnswer.yourAnswer).toBeNull();

    // Integrity block: independently recompute SHA-256 with Node's own
    // crypto module (not our own JS's sha256Hex) as a cross-check that the
    // browser's Web Crypto digest is correct, not just internally
    // self-consistent.
    expect(contents.integrity.algorithm).toBe("sha256");
    const expectedHash = nodeCrypto
      .createHash("sha256")
      .update(contents.integrity.hashedContent, "utf8")
      .digest("hex");
    expect(contents.integrity.hash).toBe(expectedHash);

    // hashedContent must be an exact stringified copy of the visible fields.
    const reparsed = JSON.parse(contents.integrity.hashedContent);
    expect(reparsed).toEqual({
      page: contents.page,
      downloadedAt: contents.downloadedAt,
      info: contents.info,
      answers: contents.answers,
      metadata: contents.metadata
    });

    // metadata: what a browser can actually expose (no computer name/username).
    expect(contents.metadata.deviceId).toMatch(/^[0-9a-f-]{20,}$/i);
    expect(typeof contents.metadata.userAgent).toBe("string");
    expect(typeof contents.metadata.timezone).toBe("string");
  });

  test("the device id is stable across repeated downloads (same browser/profile)", async ({ page }) => {
    await page.goto("/download-answers");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    async function download() {
      const downloadPromise = page.waitForEvent("download");
      await page.locator(".learnr2-download-answers-btn").click();
      const dl = await downloadPromise;
      const stream = await dl.createReadStream();
      const chunks = [];
      for await (const chunk of stream) chunks.push(chunk);
      return JSON.parse(Buffer.concat(chunks).toString("utf8"));
    }

    const first = await download();
    const second = await download();
    expect(second.metadata.deviceId).toBe(first.metadata.deviceId);
  });

  test("is blocked with an error if a required info field is missing", async ({ page }) => {
    await page.goto("/download-answers");

    // Only fill in name, leaving the also-required email blank.
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("body").click();

    let downloadHappened = false;
    page.once("download", () => {
      downloadHappened = true;
    });

    await page.locator(".learnr2-download-answers-btn").click();
    await expect(page.locator(".learnr2-download-error")).toBeVisible();
    await expect(page.locator(".learnr2-download-error")).toContainText("Email:");
    expect(downloadHappened).toBe(false);

    // Filling in the missing field and retrying should now succeed.
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    await downloadPromise;
    await expect(page.locator(".learnr2-download-error")).toBeHidden();
  });
});
