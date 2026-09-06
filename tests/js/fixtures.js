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
// on too -- see exerciseAnswerFromScript() in quiz.js.
function webrExerciseScript(blockId, attr, code) {
  const type = "webr-" + blockId + "-contents";
  return '<script type="' + type + '">' + encode({ attr: attr, code: code }) + "</script>\n";
}

// Stands in for a real Quarto-rendered heading section: Quarto's HTML
// output wraps every `##`/`###` heading and everything under it in its own
// <section id="..." class="level2"|"level3">, nested for subsections (see
// initProgressiveSections() in quiz.js). `children` lets one section
// (e.g. "Running R Code") be built containing nested level3 sections
// (e.g. "Exercise 1"/"Exercise 2") the same way Quarto would.
function sectionBlock(id, level, heading, bodyHtml, children) {
  return (
    '<section id="' + id + '" class="level' + level + '">\n' +
    "<h" + level + ">" + heading + "</h" + level + ">\n" +
    (bodyHtml || "") +
    (children || []).join("\n") +
    "</section>\n"
  );
}

// Appends real <a href="#id"> links into Quarto's own TOC nav (left as an
// empty <nav id="TOC"> by renderPage() below) via a plain inline script --
// enough real markup to test TOC-driven navigation without needing
// renderPage() itself to know about per-fixture TOC content.
function tocScript(entries) {
  const html = entries
    .map(function (entry) {
      return '<a href="#' + entry[0] + '">' + entry[1] + "</a>";
    })
    .join("");
  return (
    "<script>\n" +
    'document.getElementById("TOC").innerHTML = ' + JSON.stringify(html) + ";\n" +
    "</script>\n"
  );
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
  "reflection-no-model-answer": [
    questionBlock(
      question({
        id: "reflection-no-model-answer",
        text: "How many minutes, approximately, did this take?",
        type: "reflection_editable",
        answers: [],
        validate: "integer"
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
    // Four {webr} cells covering every case exerciseAnswerFromScript() needs
    // to handle: a real exercise the reader has saved code for, one they
    // haven't touched, one with no persist: true (excluded -- there is no
    // record of it to find), and a plain non-exercise cell (no `exercise`
    // attr at all -- excluded, nothing to collect).
    webrExerciseScript("1", { exercise: "ex-attempted", persist: true }, "______"),
    webrExerciseScript("2", { exercise: "ex-untouched", persist: true }, "______"),
    webrExerciseScript("3", { exercise: "ex-not-persisted", persist: false }, "______"),
    webrExerciseScript("4", { edit: false }, "sample(1:10)"),
    downloadBlock(downloadButton({ filenamePrefix: "class-101" }))
  ],
  // Deliberately interleaves question() widgets and {webr} exercise cells so
  // the download's page-order guarantee is actually exercised: on the page
  // the order is q-one, ex-alpha, q-two, ex-beta, so contents.answers must
  // come back in exactly that order (not "all questions, then all exercises").
  "download-answers-interleaved": [
    infoBlock(info({ id: "learnr2-info-student-info" })),
    questionBlock(
      question({
        id: "q-one",
        text: "First question.",
        type: "single",
        answers: [answer("yes", true), answer("no")]
      })
    ),
    webrExerciseScript("1", { exercise: "ex-alpha", persist: true }, "______"),
    questionBlock(
      question({
        id: "q-two",
        text: "Second question.",
        type: "reflection",
        answers: [answer("A model answer.", true)]
      })
    ),
    webrExerciseScript("2", { exercise: "ex-beta", persist: true }, "______"),
    downloadBlock(downloadButton({ filenamePrefix: "class-101" }))
  ],
  // An image-paste reflection plus a download button: the download must
  // record the pasted screenshot's PNG data URL as that question's `answer`.
  "download-answers-image": [
    infoBlock(info({ id: "learnr2-info-student-info" })),
    questionBlock(
      question({
        id: "reflection-image",
        text: "Paste a screenshot of your plot.",
        type: "reflection",
        answers: [answer("A scatterplot with a downward trend.", true)],
        allowImage: true
      })
    ),
    downloadBlock(downloadButton({ filenamePrefix: "class-101" }))
  ],
  // Mirrors getting-started's real shape: two level2 sections with no
  // subsections (Introduction, Student Information), a level2 section
  // ("Running R Code") containing two nested level3 subsections (Exercise
  // 1/2) the way Quarto renders "### Exercise 1" under "## Running R Code",
  // and a trailing level2 (Summary) with nothing after it.
  "progressive-sections": [
    sectionBlock("introduction", 2, "Introduction", "<p>Intro text.</p>\n"),
    sectionBlock(
      "student-information",
      2,
      "Student Information",
      infoBlock(info({ id: "learnr2-info-student-info" }))
    ),
    sectionBlock(
      "running-r-code",
      2,
      "Running R Code",
      "<p>Running R code intro.</p>\n",
      [
        sectionBlock(
          "exercise-1",
          3,
          "Exercise 1",
          questionBlock(
            question({
              id: "exercise-1-q",
              text: "Exercise 1 question",
              type: "single",
              answers: [answer("Correct", true)]
            })
          )
        ),
        sectionBlock(
          "exercise-2",
          3,
          "Exercise 2",
          questionBlock(
            question({
              id: "exercise-2-q",
              text: "Exercise 2 question",
              type: "single",
              answers: [answer("Correct", true)]
            })
          )
        )
      ]
    ),
    sectionBlock("summary", 2, "Summary", "<p>All done.</p>\n"),
    tocScript([
      ["introduction", "Introduction"],
      ["student-information", "Student Information"],
      ["running-r-code", "Running R Code"],
      ["exercise-1", "Exercise 1"],
      ["exercise-2", "Exercise 2"],
      ["summary", "Summary"]
    ])
  ],
  // Mirrors hello-learnr2's real "## 3. Exercises" shape exactly: a level2
  // section containing its own intro *and* nested "### Hints"/"### Solutions"
  // level3 sections, each wrapping the exact `exercise-hint`/
  // `exercise-solution` marker div quarto-live itself renders (confirmed
  // against a real render -- see initProgressiveSections() in quiz.js).
  // Hints/Solutions must NOT get their own Continue stop.
  "progressive-sections-hints": [
    sectionBlock(
      "exercises",
      2,
      "3. Exercises",
      "<p>Exercise intro.</p>\n",
      [
        sectionBlock(
          "hints",
          3,
          "Hints",
          '<div class="hint webr-ojs-exercise exercise-hint d-none">Hint text.</div>\n'
        ),
        sectionBlock(
          "solutions",
          3,
          "Solutions",
          '<div class="webr-ojs-exercise exercise-solution d-none">Solution text.</div>\n'
        )
      ]
    ),
    sectionBlock("setup-cells", 2, "4. Setup cells", "<p>Setup intro.</p>\n")
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
