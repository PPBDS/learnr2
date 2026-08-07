"use strict";

// Test fixtures for the quiz.js runtime (inst/extdata/quiz/quiz.js). Each
// fixture is a payload object in exactly the shape the R side produces (see
// R/question.R's and R/submission.R's `payload <- list(...)` construction)
// -- kept in sync by hand, since there's no R dependency in this JS test
// project. If those payload fields change, update here too.

function answer(text, correct, message) {
  return { text: text, correct: !!correct, message: message === undefined ? null : message };
}

function question(overrides) {
  return Object.assign(
    {
      id: "test-question",
      text: "Question text",
      type: "single",
      answers: [],
      correctMessage: "Correct!",
      incorrectMessage: "Incorrect.",
      allowRetry: false,
      randomAnswerOrder: false,
      submitLabel: "Submit Answer",
      tryAgainLabel: "Try Again",
      editLabel: "Edit Answer",
      allowImage: false,
      validate: "none"
    },
    overrides
  );
}

function info(overrides) {
  return Object.assign(
    {
      id: "learnr2-info-student-info",
      fields: [
        { key: "name", label: "Name:", required: true },
        { key: "email", label: "Email:", required: true },
        { key: "id", label: "ID (if requested by your instructor):", required: false }
      ],
      submitLabel: "Submit",
      editLabel: "Edit"
    },
    overrides
  );
}

function downloadButton(overrides) {
  return Object.assign(
    { filenamePrefix: "learnr2-answers", label: "Download My Answers" },
    overrides
  );
}

function encode(payload) {
  return Buffer.from(JSON.stringify(payload), "utf8").toString("base64");
}

function questionBlock(payload) {
  return (
    '<div class="learnr2-question" data-learnr2-question="' + encode(payload) + '">\n' +
    "  <noscript>This quiz question requires JavaScript.</noscript>\n" +
    "</div>\n"
  );
}

function infoBlock(payload) {
  return (
    '<div class="learnr2-info" data-learnr2-info="' + encode(payload) + '">\n' +
    "  <noscript>This form requires JavaScript.</noscript>\n" +
    "</div>\n"
  );
}

function downloadBlock(payload) {
  return (
    '<div class="learnr2-download-answers" data-learnr2-download="' + encode(payload) + '">\n' +
    "  <noscript>This button requires JavaScript.</noscript>\n" +
    "</div>\n"
  );
}

// Stands in for a real quarto-live {webr} exercise cell's own static
// markup -- a <script type="webr-<blockId>-contents"> holding base64-
// encoded {attr, code} JSON. Confirmed against the real bundled
// live-runtime.js/webr-exercise.ojs: `blockId` is what quarto-live's own
// editor uses as the default persistence id (not the `exercise:` label),
// so it's what a real "editor-<page>#<blockId>" localStorage key is keyed
// on too -- see collectExerciseAnswers() in quiz.js.
function webrExerciseScript(blockId, attr, code) {
  const type = "webr-" + blockId + "-contents";
  return '<script type="' + type + '">' + encode({ attr: attr, code: code }) + "</script>\n";
}

// Each fixture is a list of HTML blocks to place on one page.
const FIXTURES = {
  "single-choice": [
    questionBlock(
      question({
        id: "single-choice",
        text: "What is 6 times 7?",
        type: "single",
        answers: [answer("42", true), answer("36"), answer("48")],
        allowRetry: true
      })
    )
  ],
  "multiple-choice": [
    questionBlock(
      question({
        id: "multiple-choice",
        text: "Pick the even numbers",
        type: "multiple",
        answers: [answer("2", true), answer("3"), answer("4", true)]
      })
    )
  ],
  text: [
    questionBlock(
      question({
        id: "text-question",
        text: "Capital of France?",
        type: "text",
        answers: [answer("Paris", true)],
        allowRetry: true
      })
    )
  ],
  "reflection-locked": [
    questionBlock(
      question({
        id: "reflection-locked",
        text: "Explain why the sky is blue.",
        type: "reflection",
        answers: [answer("Rayleigh scattering.", true)]
      })
    )
  ],
  "reflection-editable": [
    questionBlock(
      question({
        id: "reflection-editable",
        text: "Explain photosynthesis.",
        type: "reflection_editable",
        answers: [answer("Plants convert light into chemical energy.", true)]
      })
    )
  ],
  "reflection-editable-integer": [
    questionBlock(
      question({
        id: "reflection-editable-integer",
        text: "How many minutes did this take?",
        type: "reflection_editable",
        answers: [answer("Any honest number of minutes is fine.", true)],
        validate: "integer"
      })
    )
  ],
  "text-integer": [
    questionBlock(
      question({
        id: "text-integer",
        text: "Enter the year 1999 as a number.",
        type: "text",
        answers: [answer("1999", true)],
        validate: "integer"
      })
    )
  ],
  "reflection-image": [
    questionBlock(
      question({
        id: "reflection-image",
        text: "Paste a screenshot of your plot.",
        type: "reflection",
        answers: [answer("A scatterplot with a downward trend.", true)],
        allowImage: true
      })
    )
  ],
  "student-info": [infoBlock(info({ id: "learnr2-info-student-info" }))],
  "download-answers": [
    infoBlock(info({ id: "learnr2-info-student-info" })),
    questionBlock(
      question({
        id: "single-choice",
        text: "What is 6 times 7?",
        type: "single",
        answers: [answer("42", true), answer("36"), answer("48")]
      })
    ),
    questionBlock(
      question({
        id: "reflection-locked",
        text: "Explain why the sky is blue.",
        type: "reflection",
        answers: [answer("Rayleigh scattering.", true)]
      })
    ),
    // Four {webr} cells covering every case collectExerciseAnswers() needs
    // to handle: a real exercise the reader has saved code for, one they
    // haven't touched, one with no persist: true (excluded -- there is no
    // record of it to find), and a plain non-exercise cell (no `exercise`
    // attr at all -- excluded, nothing to collect).
    webrExerciseScript("1", { exercise: "ex-attempted", persist: true }, "______"),
    webrExerciseScript("2", { exercise: "ex-untouched", persist: true }, "______"),
    webrExerciseScript("3", { exercise: "ex-not-persisted", persist: false }, "______"),
    webrExerciseScript("4", { edit: false }, "sample(1:10)"),
    downloadBlock(downloadButton({ filenamePrefix: "class-101" }))
  ]
};

function renderPage(name) {
  const blocks = FIXTURES[name];
  if (!blocks) {
    return null;
  }
  return (
    "<!doctype html>\n" +
    "<html>\n" +
    "<head>\n" +
    '<meta charset="utf-8">\n' +
    "<title>quiz fixture: " + name + "</title>\n" +
    '<link rel="stylesheet" href="/quiz/quiz.css">\n' +
    "</head>\n" +
    "<body>\n" +
    // Minimal stand-in for Quarto's own TOC sidebar (the real markup has a
    // lot more in it -- a <nav id="TOC">, heading, link list -- but all
    // injectStartOverButton() needs is the #quarto-margin-sidebar container
    // itself to append into, matching every real rendered tutorial page.
    '<div id="quarto-margin-sidebar" class="sidebar margin-sidebar"><nav id="TOC"></nav></div>\n' +
    blocks.join("\n") +
    '<script src="/quiz/quiz.js"></script>\n' +
    "</body>\n" +
    "</html>\n"
  );
}

module.exports = { FIXTURES, renderPage };
