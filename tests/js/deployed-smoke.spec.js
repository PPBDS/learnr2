"use strict";
const { test, expect } = require("@playwright/test");

// Runs against a real, already-deployed tutorial page (see
// .github/workflows/tutorials.yaml's smoke-test job) rather than the local
// fixture server the rest of tests/js/ uses -- the point is to catch
// deploy-pipeline failures (render broke, GitHub Pages served something
// stale or missing, the quarto-live extension didn't come along for the
// ride) that a fixture page, built from the same quiz.js but never
// actually rendered by Quarto or served by GitHub, cannot catch.
//
// Deliberately only exercises question()/student_info()/
// download_answers_button() -- plain JS, no WebR involved -- so this can't
// flake on WebR's WebAssembly runtime being slow to boot; see AGENTS.md's
// "Publishing tutorials via GitHub Pages" section for why {webr} exercises
// are out of scope here.
const SMOKE_URL = process.env.SMOKE_URL;

test.describe("deployed hello-learnr2 smoke test", () => {
  test.skip(!SMOKE_URL, "SMOKE_URL not set -- only meant to run against a live deployment");

  test("known answers survive a real download from the live page", async ({ page }) => {
    await page.goto(SMOKE_URL);

    const knownName = "Smoke Test Reader";
    const knownEmail = "smoke-test@example.com";

    await page.locator("#learnr2-info-student-info-name").fill(knownName);
    await page.locator("#learnr2-info-student-info-email").fill(knownEmail);

    const choiceQuestion = page.locator(".learnr2-question", {
      hasText: "Which function computes the arithmetic mean in base R?"
    });
    await choiceQuestion.locator("label.learnr2-answer", { hasText: "mean()" }).locator("input").check();
    await choiceQuestion.locator(".learnr2-submit").click();
    await expect(choiceQuestion.locator(".learnr2-feedback")).toBeVisible();

    const textQuestion = page.locator(".learnr2-question", {
      hasText: "What R package powers grading for learnr2 exercises?"
    });
    await textQuestion.locator(".learnr2-text-input").fill("gradethis");
    await textQuestion.locator(".learnr2-submit").click();
    await expect(textQuestion.locator(".learnr2-feedback")).toBeVisible();

    const downloadPromise = page.waitForEvent("download");
    await page.locator(".learnr2-download-answers-btn").click();
    const download = await downloadPromise;

    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) {
      chunks.push(chunk);
    }
    const contents = JSON.parse(Buffer.concat(chunks).toString("utf8"));

    expect(contents.info.name).toBe(knownName);
    expect(contents.info.email).toBe(knownEmail);

    // Entries are { id, answer } now; ids are slugified from the question
    // text (no explicit id set in the deployed tutorial).
    const choiceAnswer = contents.answers.find(
      (a) => a.id.indexOf("arithmetic-mean") !== -1
    );
    expect(choiceAnswer.answer).toEqual(["mean()"]);

    const textAnswer = contents.answers.find(
      (a) => a.id.indexOf("powers-grading") !== -1
    );
    expect(textAnswer.answer).toBe("gradethis");
  });
});
