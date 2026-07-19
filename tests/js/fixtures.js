"use strict";

// Test fixtures for the quiz.js runtime (inst/extdata/quiz/quiz.js). Each
// fixture is a payload object in exactly the shape R/question.R's
// `question()` produces (see its `payload <- list(...)` construction) --
// kept in sync by hand, since there's no R dependency in this JS test
// project. If question.R's payload fields change, update here too.

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
      allowImage: false
    },
    overrides
  );
}

const FIXTURES = {
  "single-choice": question({
    id: "single-choice",
    text: "What is 6 times 7?",
    type: "single",
    answers: [answer("42", true), answer("36"), answer("48")],
    allowRetry: true
  }),
  "multiple-choice": question({
    id: "multiple-choice",
    text: "Pick the even numbers",
    type: "multiple",
    answers: [answer("2", true), answer("3"), answer("4", true)]
  }),
  text: question({
    id: "text-question",
    text: "Capital of France?",
    type: "text",
    answers: [answer("Paris", true)],
    allowRetry: true
  }),
  "reflection-locked": question({
    id: "reflection-locked",
    text: "Explain why the sky is blue.",
    type: "reflection",
    answers: [answer("Rayleigh scattering.", true)]
  }),
  "reflection-editable": question({
    id: "reflection-editable",
    text: "Explain photosynthesis.",
    type: "reflection_editable",
    answers: [answer("Plants convert light into chemical energy.", true)]
  }),
  "reflection-image": question({
    id: "reflection-image",
    text: "Paste a screenshot of your plot.",
    type: "reflection",
    answers: [answer("A scatterplot with a downward trend.", true)],
    allowImage: true
  })
};

function encode(payload) {
  return Buffer.from(JSON.stringify(payload), "utf8").toString("base64");
}

function renderPage(name) {
  const payload = FIXTURES[name];
  if (!payload) {
    return null;
  }
  const encoded = encode(payload);
  return (
    "<!doctype html>\n" +
    "<html>\n" +
    "<head>\n" +
    '<meta charset="utf-8">\n' +
    "<title>quiz fixture: " + name + "</title>\n" +
    '<link rel="stylesheet" href="/quiz/quiz.css">\n' +
    "</head>\n" +
    "<body>\n" +
    '<div class="learnr2-question" data-learnr2-question="' + encoded + '">\n' +
    "  <noscript>This quiz question requires JavaScript.</noscript>\n" +
    "</div>\n" +
    '<script src="/quiz/quiz.js"></script>\n' +
    "</body>\n" +
    "</html>\n"
  );
}

module.exports = { FIXTURES, renderPage };
