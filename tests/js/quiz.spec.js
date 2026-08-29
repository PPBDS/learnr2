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
    const submit = page.locator(".learnr2-submit");
    await expect(submit).toHaveText("Submit Answer");

    await page.locator("textarea").fill("First draft.");
    await submit.click();

    await expect(page.locator("textarea")).toBeEnabled();
    await expect(submit).toBeVisible();
    // Once submitted, further clicks are edits, not first submissions --
    // the button should say so.
    await expect(submit).toHaveText("Edit Answer");

    await page.locator("textarea").fill("Revised answer.");
    await submit.click();
    await expect(page.locator("textarea")).toHaveValue("Revised answer.");
    await expect(page.locator("textarea")).toBeEnabled();
    await expect(submit).toHaveText("Edit Answer");
  });

  test("editable type: button still says Edit Answer after a reload", async ({ page }) => {
    await page.goto("/reflection-editable");
    await page.locator("textarea").fill("First draft.");
    await page.locator(".learnr2-submit").click();

    await page.reload();
    await expect(page.locator(".learnr2-submit")).toHaveText("Edit Answer");
  });

  test("with no answer() marked correct: submitting saves the response but reveals no model answer box", async ({
    page
  }) => {
    await page.goto("/reflection-no-model-answer");
    // This fixture uses validate: "integer" (see the "how many minutes"
    // example it's modeled on), which renders a single-line input sized
    // like student_info()'s fields rather than a multi-row textarea.
    await page.locator(".learnr2-text-input").fill("90");
    await page.locator(".learnr2-submit").click();

    // Still behaves like a normal reflection_editable submission otherwise --
    // just nothing to reveal.
    await expect(page.locator(".learnr2-model-answer")).toBeHidden();
    await expect(page.locator(".learnr2-model-answer")).toBeEmpty();
    await expect(page.locator(".learnr2-submit")).toHaveText("Edit Answer");

    await page.reload();
    await expect(page.locator(".learnr2-text-input")).toHaveValue("90");
    await expect(page.locator(".learnr2-model-answer")).toBeHidden();
  });
});

test.describe("validate = \"integer\"", () => {
  test("text question: non-integer input is rejected without grading, valid input proceeds to grading", async ({ page }) => {
    await page.goto("/text-integer");
    const input = page.locator(".learnr2-text-input");
    const feedback = page.locator(".learnr2-feedback");

    await input.fill("nineteen ninety-nine");
    await page.locator(".learnr2-submit").click();
    await expect(feedback).toHaveClass(/learnr2-feedback-incorrect/);
    await expect(feedback).toHaveText(/whole number/);
    // Rejected at the validation step, before grading -- input stays enabled.
    await expect(input).toBeEnabled();

    await input.fill("2000");
    await page.locator(".learnr2-submit").click();
    await expect(feedback).toHaveText("Incorrect.");
    await expect(input).toBeDisabled();
  });

  test("text question: a signed integer passes validation and grades correct", async ({ page }) => {
    await page.goto("/text-integer");
    await page.locator(".learnr2-text-input").fill("1999");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-feedback")).toHaveClass(/learnr2-feedback-correct/);
  });

  test("reflection_editable question: non-integer input blocks submission, no model answer revealed", async ({ page }) => {
    await page.goto("/reflection-editable-integer");
    // validate: "integer" renders a single-line input, not a textarea (see
    // the fixture above).
    const textarea = page.locator(".learnr2-text-input");
    const feedback = page.locator(".learnr2-feedback");

    await textarea.fill("about an hour");
    await page.locator(".learnr2-submit").click();
    await expect(feedback).toHaveClass(/learnr2-feedback-incorrect/);
    await expect(feedback).toHaveText(/whole number/);
    await expect(page.locator(".learnr2-model-answer")).toBeHidden();
    await expect(textarea).toBeEnabled();

    await textarea.fill("45");
    await page.locator(".learnr2-submit").click();
    await expect(page.locator(".learnr2-model-answer")).toBeVisible();
    await expect(textarea).toBeEnabled(); // reflection_editable stays editable
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

  test("a non-PNG raster image (GIF) is accepted and re-encoded as PNG", async ({ page }) => {
    // A screenshot isn't guaranteed to already be a PNG -- the real OS
    // clipboard format varies by platform (verified: only the *write*
    // side of the newer Async Clipboard API is documented as PNG-only;
    // this code reads via the older paste-event path instead, which has
    // no such guarantee). So common raster types are accepted directly
    // and converted, rather than rejected for not already being PNG.
    await page.goto("/reflection-image");
    await dispatchSyntheticPaste(page, ".learnr2-image-paste", TINY_GIF_BASE64, "image/gif", "photo.gif");

    await expect(page.locator(".learnr2-image-paste-error")).toBeHidden();
    await expect(page.locator(".learnr2-image-paste-preview")).toBeVisible();
    // What's actually stored is always PNG, regardless of the source format.
    const src = await page.locator(".learnr2-image-paste-preview").getAttribute("src");
    expect(src).toMatch(/^data:image\/png;base64,/);
  });

  test("a non-image file (e.g. a PDF) is rejected with an error", async ({ page }) => {
    await page.goto("/reflection-image");
    await dispatchSyntheticPaste(page, ".learnr2-image-paste", TINY_PNG_BASE64, "application/pdf", "notes.pdf");

    await expect(page.locator(".learnr2-image-paste-error")).toBeVisible();
    await expect(page.locator(".learnr2-image-paste-error")).toContainText("Please paste an image");
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

  test("button reads Submit, flags a missing required field, then switches to Edit on a valid submission", async ({ page }) => {
    await page.goto("/student-info");

    const submit = page.locator(".learnr2-info .learnr2-submit");
    const feedback = page.locator(".learnr2-info .learnr2-feedback");
    await expect(submit).toHaveText("Submit");

    // Required fields still blank -- clicking should flag it, not silently
    // succeed, and it must not switch to "Edit" for an invalid attempt.
    await submit.click();
    await expect(feedback).toBeVisible();
    await expect(feedback).toHaveClass(/learnr2-feedback-incorrect/);
    await expect(submit).toHaveText("Submit");
    await expect(
      page.locator("#learnr2-info-student-info-name")
        .locator("xpath=../div[contains(@class,'learnr2-info-error')]")
    ).toBeVisible();

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await submit.click();
    await expect(feedback).toHaveClass(/learnr2-feedback-correct/);
    // Mirrors question()'s reflection_editable behavior exactly: once
    // submitted successfully, further clicks are edits, not first submissions.
    await expect(submit).toHaveText("Edit");

    // Unlike a graded question(), the form stays editable after clicking --
    // this is data entry, not something to lock.
    await expect(page.locator("#learnr2-info-student-info-name")).toBeEditable();
  });

  test("button still says Edit after a reload, once already submitted", async ({ page }) => {
    await page.goto("/student-info");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator(".learnr2-info .learnr2-submit").click();

    await page.reload();
    await expect(page.locator(".learnr2-info .learnr2-submit")).toHaveText("Edit");
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

  test("email field is flagged when it has no '@', and clears once fixed", async ({ page }) => {
    await page.goto("/student-info");

    const emailInput = page.locator("#learnr2-info-student-info-email");
    const emailError = emailInput.locator("xpath=../div[contains(@class,'learnr2-info-error')]");

    await emailInput.fill("adaexample.com");
    await page.locator("body").click(); // blur
    await expect(emailError).toBeVisible();
    await expect(emailError).toContainText("@");

    await emailInput.fill("ada@example.com");
    await page.locator("body").click();
    await expect(emailError).toBeHidden();
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
    // The reflection question above was left unanswered on purpose, so the
    // "make sure you submitted" check should warn before letting this
    // through -- confirm it anyway to get the download.
    await expect(page.locator(".learnr2-confirm-dialog")).toContainText("Explain why the sky is blue");
    await page.locator(".learnr2-confirm-dialog-confirm").click();
    const download = await downloadPromise;

    expect(download.suggestedFilename()).toMatch(/^class-101-.*\.json$/);

    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) {
      chunks.push(chunk);
    }
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));

    expect(contents.info).toEqual({ name: "Ada Lovelace", email: "ada@example.com", id: null });
    // Two question() widgets plus the two persist:true {webr} exercises in
    // the fixture -- all one flat list now, each entry just { id, answer }.
    expect(contents.answers).toHaveLength(4);

    const choiceAnswer = contents.answers.find((a) => a.id === "single-choice");
    expect(choiceAnswer.answer).toEqual(["42"]);

    const reflectionAnswer = contents.answers.find((a) => a.id === "reflection-locked");
    expect(reflectionAnswer.answer).toBeNull();

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

  test("includes {webr} exercise code, keyed by exercise label not the internal block id", async ({ page }) => {
    await page.goto("/download-answers");

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    // Simulate quarto-live's own editor having saved the reader's code for
    // "ex-attempted" (fixture block id "1") -- real key format confirmed
    // against quarto-live's own live-runtime.js: editor-<page>#webr-<id>-contents,
    // storing the plain code string, not JSON.
    await page.evaluate(() => {
      localStorage.setItem("editor-" + location.href + "#webr-1-contents", "sum(1:100)");
    });

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    // Neither question was answered -- confirm past the unanswered-questions
    // warning to get the download.
    await page.locator(".learnr2-confirm-dialog-confirm").click();
    const download = await downloadPromise;
    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) {
      chunks.push(chunk);
    }
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));

    // "ex-not-persisted" and the plain non-exercise cell (fixture block ids
    // 3 and 4) must not appear at all -- neither has anywhere a code could
    // have been recorded. Exercises share the one `answers` list with
    // question() widgets now, appended after them.
    const exerciseAnswers = contents.answers.filter((a) => a.id.indexOf("ex-") === 0);
    expect(exerciseAnswers).toEqual([
      { id: "ex-attempted", answer: "sum(1:100)" },
      { id: "ex-untouched", answer: null }
    ]);
  });

  test("records a pasted image as the question's answer (the PNG data URL string)", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await page.goto("/download-answers-image");

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    const imageQuestion = page.locator(".learnr2-question", {
      has: page.locator(".learnr2-image-paste")
    });
    await writeImageToClipboard(page, TINY_PNG_BASE64, "image/png");
    await imageQuestion.locator(".learnr2-image-paste").click();
    await page.keyboard.press("Control+V");
    await expect(imageQuestion.locator(".learnr2-image-paste-preview")).toBeVisible();
    await imageQuestion.locator(".learnr2-submit").click();
    await expect(imageQuestion.locator(".learnr2-image-paste")).toHaveClass(
      /learnr2-image-paste-disabled/
    );

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    const download = await downloadPromise;
    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) chunks.push(chunk);
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));

    const imageAnswer = contents.answers.find((a) => a.id === "reflection-image");
    expect(imageAnswer.answer).toMatch(/^data:image\/png;base64,/);
  });

  test("still finds a saved answer and exercise after the reader navigates to a different TOC section (URL hash change) before downloading", async ({ page }) => {
    // Regression test: quiz.js used to build every storage key from a fresh
    // `window.location.href` read at click time. Quarto's own TOC sidebar
    // links change the URL's hash without reloading the page -- completely
    // normal navigation -- so a reader who saved an answer while the hash
    // pointed at one section, then clicked to another section before
    // downloading, made collectAnswers()/collectExerciseAnswers() look for
    // keys under the new hash while the data was actually saved under the
    // old one. Nothing was lost, but the download silently came back empty
    // for that answer/exercise. Fixed by capturing a hash-stripped page URL
    // once at load time instead (matching how quarto-live's own editor
    // caches its storage key once, in its constructor).
    await page.goto("/download-answers");

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();
    const singleChoiceQuestion = page.locator(".learnr2-question", {
      has: page.locator("#single-choice-answer-0")
    });
    await singleChoiceQuestion.locator("#single-choice-answer-0").check();
    await singleChoiceQuestion.locator(".learnr2-submit").click();
    await page.evaluate(() => {
      localStorage.setItem("editor-" + location.href + "#webr-1-contents", "sum(1:100)");
    });

    // Same as clicking a `<a href="#some-other-section">` TOC link: changes
    // location.hash without a page reload.
    await page.evaluate(() => { location.hash = "some-other-section"; });

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    // The reflection question is still unanswered -- confirm past the warning.
    await page.locator(".learnr2-confirm-dialog-confirm").click();
    const download = await downloadPromise;
    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) chunks.push(chunk);
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));

    const choiceAnswer = contents.answers.find((a) => a.id === "single-choice");
    expect(choiceAnswer.answer).toEqual(["42"]);
    expect(contents.answers).toContainEqual({ id: "ex-attempted", answer: "sum(1:100)" });
  });

  test("the device id is stable across repeated downloads (same browser/profile)", async ({ page }) => {
    await page.goto("/download-answers");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    async function download() {
      const downloadPromise = page.waitForEvent("download");
      await page.locator(".learnr2-download-answers-btn").click();
      // Neither question is answered in this test -- confirm past the
      // unanswered-questions warning each time.
      await page.locator(".learnr2-confirm-dialog-confirm").click();
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
    // Neither question is answered in this test -- confirm past the
    // unanswered-questions warning to get the download.
    await page.locator(".learnr2-confirm-dialog-confirm").click();
    await downloadPromise;
    await expect(page.locator(".learnr2-download-error")).toBeHidden();
  });

  test("is blocked with an error if the email field has no '@', even though it's non-empty", async ({ page }) => {
    await page.goto("/download-answers");

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("adaexample.com");
    await page.locator("body").click();

    let downloadHappened = false;
    page.once("download", () => {
      downloadHappened = true;
    });

    await page.locator(".learnr2-download-answers-btn").click();
    await expect(page.locator(".learnr2-download-error")).toBeVisible();
    await expect(page.locator(".learnr2-download-error")).toContainText("Email:");
    expect(downloadHappened).toBe(false);

    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    // Neither question is answered in this test -- confirm past the
    // unanswered-questions warning to get the download.
    await page.locator(".learnr2-confirm-dialog-confirm").click();
    await downloadPromise;
    await expect(page.locator(".learnr2-download-error")).toBeHidden();
  });

  test("warns before downloading if a question hasn't been submitted, and lets the reader cancel", async ({ page }) => {
    await page.goto("/download-answers");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();

    let downloadHappened = false;
    page.once("download", () => {
      downloadHappened = true;
    });

    await page.locator(".learnr2-download-answers-btn").click();
    await expect(page.locator(".learnr2-confirm-dialog")).toBeVisible();
    await expect(page.locator(".learnr2-confirm-dialog")).toContainText("2 questions");
    await expect(page.locator(".learnr2-confirm-dialog")).toContainText("What is 6 times 7?");
    await expect(page.locator(".learnr2-confirm-dialog")).toContainText("Explain why the sky is blue");

    await page.locator(".learnr2-confirm-dialog-cancel").click();
    expect(downloadHappened).toBe(false);

    // Answer both questions, then downloading should go straight through
    // with no warning at all.
    const singleChoiceQuestion = page.locator(".learnr2-question", {
      has: page.locator("#single-choice-answer-0")
    });
    await singleChoiceQuestion.locator("#single-choice-answer-0").check();
    await singleChoiceQuestion.locator(".learnr2-submit").click();

    const reflectionQuestion = page.locator(".learnr2-question", { hasText: "Explain why the sky is blue" });
    await reflectionQuestion.locator("textarea").fill("Rayleigh scattering.");
    await reflectionQuestion.locator(".learnr2-submit").click();

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    await downloadPromise;
  });
});

test.describe("Start Over", () => {
  test("appears at the bottom of the sidebar", async ({ page }) => {
    await page.goto("/download-answers");
    const sidebar = page.locator("#quarto-margin-sidebar");
    const button = sidebar.locator(".learnr2-start-over");
    await expect(button).toHaveText("Start Over");
    // Genuinely last, not just present -- appended after the TOC nav.
    await expect(sidebar.locator(":scope > *").last()).toHaveClass(/learnr2-start-over-container/);
  });

  test("clears saved answers, student info, and {webr} exercise persistence, but not the device id, then reloads", async ({ page }) => {
    await page.goto("/download-answers");

    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("#learnr2-info-student-info-email").fill("ada@example.com");
    await page.locator("body").click();
    await page.locator("#single-choice-answer-0").check();
    const singleChoice = page.locator(".learnr2-question", { has: page.locator("#single-choice-answer-0") });
    await singleChoice.locator(".learnr2-submit").click();

    // Stand in for a real quarto-live {webr} exercise's own persisted code
    // (this fixture harness has no live webr runtime to produce one) and
    // for a device id that must survive -- it identifies this browser
    // across every tutorial and visit, not this one tutorial's progress.
    await page.evaluate(() => {
      localStorage.setItem("editor-" + location.href + "#some_exercise", JSON.stringify({ code: "1 + 1" }));
      localStorage.setItem("learnr2-device-id", "test-device-should-survive");
    });

    await page.locator(".learnr2-start-over").click();
    // Registering the load-state wait and the click together matters here:
    // the click resolves as soon as the event dispatches, but the actual
    // reload() only happens after the in-page <dialog>'s Start Over button
    // is clicked. Awaiting the click alone, then waitForLoadState()
    // afterward, can win that race and observe the pre-reload page
    // (confirmed: this genuinely happens, not hypothetical -- the fix
    // below is required, not defensive).
    await Promise.all([
      page.waitForLoadState(),
      page.locator(".learnr2-confirm-dialog-confirm").click()
    ]);

    await expect(page.locator("#learnr2-info-student-info-name")).toHaveValue("");
    await expect(page.locator("#single-choice-answer-0")).not.toBeChecked();

    const remaining = await page.evaluate(() => {
      const keys = [];
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k.indexOf("learnr2-" + location.href) === 0 || k.indexOf("editor-" + location.href) === 0) {
          keys.push(k);
        }
      }
      return keys;
    });
    expect(remaining).toEqual([]);
    await expect
      .poll(() => page.evaluate(() => localStorage.getItem("learnr2-device-id")))
      .toBe("test-device-should-survive");
  });

  test("does nothing if the confirmation is dismissed", async ({ page }) => {
    await page.goto("/download-answers");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("body").click();

    await page.locator(".learnr2-start-over").click();
    await page.locator(".learnr2-confirm-dialog-cancel").click();

    // No reload happened -- the value typed above is still right there.
    await expect(page.locator("#learnr2-info-student-info-name")).toHaveValue("Ada Lovelace");
  });

  test("still clears a saved answer after the reader navigates to a different TOC section (URL hash change) before clicking Start Over", async ({ page }) => {
    // Same underlying bug as the equivalent download-answers regression
    // test above, but for clearAllProgress()'s own key prefixes.
    await page.goto("/download-answers");
    await page.locator("#learnr2-info-student-info-name").fill("Ada Lovelace");
    await page.locator("body").click();

    await page.evaluate(() => { location.hash = "some-other-section"; });

    await page.locator(".learnr2-start-over").click();
    await Promise.all([
      page.waitForLoadState(),
      page.locator(".learnr2-confirm-dialog-confirm").click()
    ]);

    await expect(page.locator("#learnr2-info-student-info-name")).toHaveValue("");
  });

  test("a plain window.confirm() is never used -- the dialog is in-page DOM content, since VS Code's Simple Browser webview (see item 0 of TODO.txt on how run_tutorial() ends up opening there) silently no-ops window.confirm()", async ({ page }) => {
    await page.goto("/download-answers");

    let nativeDialogFired = false;
    page.on("dialog", (dialog) => {
      nativeDialogFired = true;
      dialog.dismiss();
    });

    await page.locator(".learnr2-start-over").click();
    await expect(page.locator(".learnr2-confirm-dialog")).toBeVisible();
    expect(nativeDialogFired).toBe(false);

    await page.locator(".learnr2-confirm-dialog-cancel").click();
    await expect(page.locator(".learnr2-confirm-dialog")).toHaveCount(0);
  });
});

test.describe("progressive sections (Continue buttons)", () => {
  test("only the first section is visible on first load, with a Continue button naming the next one", async ({ page }) => {
    await page.goto("/progressive-sections");

    await expect(page.locator("#introduction")).toBeVisible();
    await expect(page.locator("#student-information")).toBeHidden();
    await expect(page.locator("#running-r-code")).toBeHidden();
    await expect(page.locator("#exercise-1")).toBeHidden();
    await expect(page.locator("#exercise-2")).toBeHidden();
    await expect(page.locator("#summary")).toBeHidden();

    const button = page.locator("#introduction .learnr2-continue");
    await expect(button).toBeVisible();
    await expect(button).toContainText("Student Information");
  });

  test("clicking Continue reveals only the next section, not everything", async ({ page }) => {
    await page.goto("/progressive-sections");

    await page.locator("#introduction .learnr2-continue").click();

    await expect(page.locator("#student-information")).toBeVisible();
    await expect(page.locator("#running-r-code")).toBeHidden();

    const button = page.locator("#student-information .learnr2-continue");
    await expect(button).toBeVisible();
    await expect(button).toContainText("Running R Code");
  });

  test("a Continue button inside a section with nested subsections lands before the first subsection, not after the last one", async ({ page }) => {
    // "Running R Code" (level2) contains "Exercise 1"/"Exercise 2" (level3)
    // nested inside it, mirroring getting-started's real structure. Reveal
    // through to "Running R Code" itself and confirm its own intro content
    // shows immediately while both exercises stay locked -- i.e. the button
    // sits right after the level2's own content, not dumped at the very end
    // of the whole subtree after Exercise 2.
    await page.goto("/progressive-sections");
    await page.locator("#introduction .learnr2-continue").click();
    await page.locator("#student-information .learnr2-continue").click();

    await expect(page.locator("#running-r-code")).toBeVisible();
    await expect(page.locator("#running-r-code")).toContainText("Running R code intro.");
    await expect(page.locator("#exercise-1")).toBeHidden();
    await expect(page.locator("#exercise-2")).toBeHidden();

    const button = page.locator("#running-r-code .learnr2-continue");
    await expect(button).toBeVisible();
    await expect(button).toContainText("Exercise 1");

    // The button must be a direct child of #running-r-code, positioned
    // before the (still-hidden) #exercise-1 section -- not appended after
    // #exercise-2, which would put it at the wrong end of the section.
    const order = await page.locator("#running-r-code > *").evaluateAll((nodes) =>
      nodes.map((n) => n.id || n.className)
    );
    expect(order.indexOf("learnr2-continue-container")).toBeLessThan(order.indexOf("exercise-1"));

    // Continuing twice more steps through both exercises one at a time.
    await button.click();
    await expect(page.locator("#exercise-1")).toBeVisible();
    await expect(page.locator("#exercise-2")).toBeHidden();
    await expect(page.locator("#exercise-1 .learnr2-continue")).toContainText("Exercise 2");

    await page.locator("#exercise-1 .learnr2-continue").click();
    await expect(page.locator("#exercise-2")).toBeVisible();
    await expect(page.locator("#exercise-2 .learnr2-continue")).toContainText("Summary");
  });

  test("no Continue button remains once every section has been revealed", async ({ page }) => {
    await page.goto("/progressive-sections");
    await page.locator("#introduction .learnr2-continue").click();
    await page.locator("#student-information .learnr2-continue").click();
    await page.locator("#running-r-code .learnr2-continue").click();
    await page.locator("#exercise-1 .learnr2-continue").click();
    await page.locator("#exercise-2 .learnr2-continue").click();

    await expect(page.locator("#summary")).toBeVisible();
    await expect(page.locator(".learnr2-continue")).toHaveCount(0);
  });

  test("progress survives a reload", async ({ page }) => {
    await page.goto("/progressive-sections");
    await page.locator("#introduction .learnr2-continue").click();
    await page.locator("#student-information .learnr2-continue").click();

    await page.reload();

    await expect(page.locator("#running-r-code")).toBeVisible();
    await expect(page.locator("#exercise-1")).toBeHidden();
    await expect(page.locator("#running-r-code .learnr2-continue")).toContainText("Exercise 1");
  });

  test("Start Over resets progress back to only the first section", async ({ page }) => {
    await page.goto("/progressive-sections");
    await page.locator("#introduction .learnr2-continue").click();
    await page.locator("#student-information .learnr2-continue").click();
    await expect(page.locator("#running-r-code")).toBeVisible();

    await page.locator(".learnr2-start-over").click();
    await Promise.all([
      page.waitForLoadState(),
      page.locator(".learnr2-confirm-dialog-confirm").click()
    ]);

    await expect(page.locator("#introduction")).toBeVisible();
    await expect(page.locator("#student-information")).toBeHidden();
    await expect(page.locator("#running-r-code")).toBeHidden();
  });

  test("clicking a TOC sidebar link skips ahead and reveals every section up through the target", async ({ page }) => {
    await page.goto("/progressive-sections");

    // Nothing continued through yet -- jump straight to Exercise 2 via the
    // TOC, same as a reader using the sidebar instead of Continue.
    await page.locator('#TOC a[href="#exercise-2"]').click();

    await expect(page.locator("#student-information")).toBeVisible();
    await expect(page.locator("#running-r-code")).toBeVisible();
    await expect(page.locator("#exercise-1")).toBeVisible();
    await expect(page.locator("#exercise-2")).toBeVisible();
    await expect(page.locator("#summary")).toBeHidden();
  });

  test("Hints/Solutions subsections don't get their own Continue stop -- they show as soon as their exercise section is unlocked", async ({ page }) => {
    // Regression test: an earlier version gated every level2/level3 section
    // uniformly, so reaching "4. Setup cells" from "3. Exercises" took two
    // extra, easy-to-miss clicks through bare "Hints"/"Solutions" stops with
    // no number of their own -- reported as the numbering "jumping" (e.g.
    // straight from 2 to 5 in hello-learnr2, skipping what looked like 3 and
    // 4). Confirmed against a real hello-learnr2 render before fixing.
    await page.goto("/progressive-sections-hints");

    await expect(page.locator("#exercises")).toBeVisible();
    await expect(page.locator("#hints")).toBeVisible();
    await expect(page.locator("#solutions")).toBeVisible();
    await expect(page.locator("#setup-cells")).toBeHidden();

    // Exactly one Continue click reaches "4. Setup cells" -- not one to
    // reveal Hints, another for Solutions, then a third for Setup cells.
    const button = page.locator(".learnr2-continue");
    await expect(button).toHaveCount(1);
    await expect(button).toContainText("4. Setup cells");
    await button.click();
    await expect(page.locator("#setup-cells")).toBeVisible();
  });
});
