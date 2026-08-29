test_that("answer() validates and constructs a learnr2_answer", {
  a <- answer("42", correct = TRUE, message = "Nice.")
  expect_s3_class(a, "learnr2_answer")
  expect_equal(a$text, "42")
  expect_true(a$correct)
  expect_equal(a$message, "Nice.")

  expect_false(answer("7")$correct)
  expect_error(answer(1), "single string")
})

test_that("answer() defaults correct to FALSE and message to NULL", {
  a <- answer("x")
  expect_false(a$correct)
  expect_null(a$message)
})

test_that("answer() rejects a missing, multi-element, or NA text", {
  expect_error(answer(), "single string")
  expect_error(answer(c("a", "b")), "single string")
  expect_error(answer(NA_character_), "single string")
})

test_that("question() requires answer() objects and at least one correct", {
  expect_error(question("Prompt?"), "at least one")
  expect_error(question("Prompt?", "not an answer"), "created with `answer\\(\\)`")
  expect_error(
    question("Prompt?", answer("a"), answer("b")),
    "at least one correct"
  )
})

test_that("question() infers single vs multiple from correct answers", {
  single <- question("2 + 2?", answer("4", correct = TRUE), answer("5"))
  expect_equal(single$payload$type, "single")

  multiple <- question(
    "Pick the even numbers",
    answer("2", correct = TRUE),
    answer("3"),
    answer("4", correct = TRUE)
  )
  expect_equal(multiple$payload$type, "multiple")
})

test_that("question() records payload fields used by the JS runtime", {
  q <- question(
    "6 * 7?",
    answer("42", correct = TRUE),
    answer("36"),
    allow_retry = TRUE,
    random_answer_order = TRUE
  )
  expect_s3_class(q, "learnr2_question")
  expect_equal(q$payload$text, "6 * 7?")
  expect_true(q$payload$allowRetry)
  expect_true(q$payload$randomAnswerOrder)
  expect_length(q$payload$answers, 2)
  expect_true(nzchar(q$payload$id))
})

test_that("type = 'text' questions disable random answer order", {
  q <- question(
    "Capital of France?",
    answer("Paris", correct = TRUE),
    type = "text",
    random_answer_order = TRUE
  )
  expect_equal(q$payload$type, "text")
  expect_false(q$payload$randomAnswerOrder)
})

test_that("reflection questions lock random_answer_order off and carry the model answer", {
  q <- question(
    "What surprised you most about this section?",
    answer("There is no single right answer, but look for ...", correct = TRUE),
    type = "reflection",
    random_answer_order = TRUE
  )
  expect_equal(q$payload$type, "reflection")
  expect_false(q$payload$randomAnswerOrder)
  expect_true(q$payload$answers[[1]]$correct)
})

test_that("reflection_editable is a distinct type from reflection", {
  q <- question(
    "Summarize the argument in your own words.",
    answer("A model summary would mention ...", correct = TRUE),
    type = "reflection_editable"
  )
  expect_equal(q$payload$type, "reflection_editable")
})

test_that("allow_image is carried through for reflection types", {
  q <- question(
    "Paste a screenshot of your plot.",
    answer("A scatterplot with a downward trend.", correct = TRUE),
    type = "reflection",
    allow_image = TRUE
  )
  expect_true(q$payload$allowImage)

  q2 <- question(
    "Paste a screenshot of your plot.",
    answer("A scatterplot with a downward trend.", correct = TRUE),
    type = "reflection_editable",
    allow_image = TRUE,
    id = "plot-screenshot-editable"
  )
  expect_true(q2$payload$allowImage)
})

test_that("allow_image is ignored for non-reflection question types", {
  q <- question(
    "2 + 2?",
    answer("4", correct = TRUE),
    allow_image = TRUE
  )
  expect_false(q$payload$allowImage)

  q2 <- question(
    "Capital of France?",
    answer("Paris", correct = TRUE),
    type = "text",
    allow_image = TRUE
  )
  expect_false(q2$payload$allowImage)
})

test_that("validate defaults to 'none' and is carried through for free-text types", {
  q <- question("2 + 2?", answer("4", correct = TRUE), type = "text")
  expect_equal(q$payload$validate, "none")

  minutes <- question(
    "How many minutes did this take?",
    answer("Any honest number is fine.", correct = TRUE),
    type = "reflection_editable",
    validate = "integer"
  )
  expect_equal(minutes$payload$validate, "integer")

  reflection <- question(
    "What surprised you?",
    answer("Anything.", correct = TRUE),
    type = "reflection",
    validate = "integer"
  )
  expect_equal(reflection$payload$validate, "integer")
})

test_that("validate is ignored (forced to 'none') for single/multiple questions", {
  q <- question("2 + 2?", answer("4", correct = TRUE), validate = "integer")
  expect_equal(q$payload$validate, "none")

  q2 <- question(
    "Pick the even numbers",
    answer("2", correct = TRUE),
    answer("3"),
    validate = "integer"
  )
  expect_equal(q2$payload$validate, "none")
})

test_that("validate rejects unknown values", {
  expect_error(
    question("2 + 2?", answer("4", correct = TRUE), validate = "numeric"),
    "should be one of"
  )
})

test_that("non-reflection types still require at least one correct answer", {
  expect_error(
    question("2 + 2?", answer("4"), answer("5")),
    "at least one correct"
  )
  expect_error(
    question("Capital of France?", answer("Paris"), type = "text"),
    "at least one correct"
  )
})

test_that("reflection types allow no answer() marked correct -- no model answer to reveal", {
  q <- question("Reflect on this.", answer("not marked correct"), type = "reflection")
  expect_equal(q$payload$type, "reflection")
  expect_length(q$payload$answers, 1)
  expect_false(q$payload$answers[[1]]$correct)
})

test_that("reflection types allow no answer() at all -- a genuinely open-ended prompt", {
  q <- question(
    "How many minutes, approximately, did this take?",
    type = "reflection_editable",
    validate = "integer"
  )
  expect_equal(q$payload$type, "reflection_editable")
  expect_length(q$payload$answers, 0)
  expect_equal(q$payload$validate, "integer")

  locked <- question("What surprised you?", type = "reflection")
  expect_equal(locked$payload$type, "reflection")
  expect_length(locked$payload$answers, 0)
})

test_that("non-reflection types still require at least one answer() at all", {
  expect_error(question("Prompt?"), "at least one")
  expect_error(question("Prompt?", type = "text"), "at least one")
})

test_that("question ids fall back to a deterministic slug of the text outside a chunk", {
  q <- question("The Deterministic ID Test Case!!", answer("x", correct = TRUE))
  expect_equal(q$payload$id, "the-deterministic-id-test-case")
})

test_that("question id defaults to the enclosing chunk label when knitting", {
  saved <- knitr::opts_current$get()
  saved_opt <- options(knitr.in.progress = TRUE)
  knitr::opts_current$set(label = "quiz-questions-1")
  on.exit({
    knitr::opts_current$restore(saved)
    options(saved_opt)
  }, add = TRUE)

  q <- question("Wording that is ignored in favour of the chunk label",
                answer("x", correct = TRUE))
  expect_equal(q$payload$id, "quiz-questions-1")
})

test_that("an unlabelled (auto-named) chunk falls back to the text slug", {
  saved <- knitr::opts_current$get()
  saved_opt <- options(knitr.in.progress = TRUE)
  knitr::opts_current$set(label = "unnamed-chunk-7")
  on.exit({
    knitr::opts_current$restore(saved)
    options(saved_opt)
  }, add = TRUE)

  q <- question("Auto Named Chunk Fallback", answer("x", correct = TRUE))
  expect_equal(q$payload$id, "auto-named-chunk-fallback")
})

test_that("explicit id overrides both the chunk label and the text slug", {
  q <- question("Ignored text", answer("x", correct = TRUE), id = "custom-id-xyz")
  expect_equal(q$payload$id, "custom-id-xyz")
})

test_that("explicit id is slugified (weird characters and duplicate dashes collapsed)", {
  q <- question("t", answer("x", correct = TRUE), id = "My Section -- Part 2!")
  expect_equal(q$payload$id, "my-section-part-2")
})

test_that("repeated wording within a render gets disambiguated ids", {
  q1 <- question("Duplicate Wording Case", answer("x", correct = TRUE))
  q2 <- question("Duplicate Wording Case", answer("y", correct = TRUE))
  expect_false(q1$payload$id == q2$payload$id)
  expect_true(startsWith(q2$payload$id, q1$payload$id))
})

test_that("question() validates id", {
  expect_error(
    question("Prompt?", answer("a", correct = TRUE), id = ""),
    "single non-empty string"
  )
  expect_error(
    question("Prompt?", answer("a", correct = TRUE), id = 5),
    "single non-empty string"
  )
})

test_that("quiz() requires question() objects", {
  expect_error(quiz(), "one or more")
  expect_error(quiz("not a question"), "one or more")

  q <- question("2 + 2?", answer("4", correct = TRUE))
  qz <- quiz(q, caption = "Arithmetic")
  expect_s3_class(qz, "learnr2_quiz")
  expect_equal(qz$caption, "Arithmetic")
  expect_length(qz$questions, 1)
})

test_that("rendered question HTML embeds a decodable payload", {
  q <- question("6 * 7?", answer("42", correct = TRUE), answer("36"))
  html <- learnr2:::quiz_html(q)
  expect_true(inherits(html, "shiny.tag"))

  encoded <- html$attribs[["data-learnr2-question"]]
  decoded <- jsonlite::fromJSON(
    rawToChar(jsonlite::base64_dec(encoded)),
    simplifyVector = FALSE
  )
  expect_equal(decoded$text, "6 * 7?")
  expect_equal(decoded$type, "single")
  expect_length(decoded$answers, 2)

  deps <- htmltools::findDependencies(html)
  expect_true(any(vapply(deps, function(d) d$name == "learnr2-quiz", logical(1))))
})

test_that("rendered quiz HTML contains one div per question", {
  qz <- quiz(
    question("2 + 2?", answer("4", correct = TRUE)),
    question("3 + 3?", answer("6", correct = TRUE)),
    caption = "Arithmetic"
  )
  html <- as.character(learnr2:::quiz_html(qz))
  expect_match(html, "learnr2-quiz-caption")
  expect_equal(lengths(regmatches(html, gregexpr("learnr2-question\"", html))), 2)
})

test_that("print.learnr2_answer prints a one-line summary, with [correct] only when applicable", {
  correct_answer <- answer("42", correct = TRUE)
  expect_output(print(correct_answer), "<answer: \"42\" \\[correct\\]>")

  wrong_answer <- answer("36")
  out <- capture.output(print(wrong_answer))
  expect_match(out, "<answer: \"36\">", fixed = TRUE, all = FALSE)
  expect_false(grepl("correct", out, fixed = TRUE))

  # Like every print method here, returns its input invisibly rather than
  # e.g. NULL, so `x <- print(x)` in a pipe doesn't silently lose the value.
  expect_identical(print(correct_answer), correct_answer)
})

test_that("print.learnr2_question opens a browser preview without erroring, and returns its input invisibly", {
  q <- question("6 * 7?", answer("42", correct = TRUE), answer("36"))
  expect_no_error(print(q))

  result <- withVisible(print(q))
  expect_false(result$visible)
  expect_identical(result$value, q)
})

test_that("knit_print.learnr2_question renders via quiz_html(), tagged for knitr as knit_asis", {
  q <- question("6 * 7?", answer("42", correct = TRUE), answer("36"))
  kp <- knitr::knit_print(q)
  expect_s3_class(kp, "knit_asis")
  html <- as.character(kp)
  expect_match(html, "learnr2-question")
  expect_match(html, "data-learnr2-question")
})

test_that("print.learnr2_quiz and knit_print.learnr2_quiz behave the same way as the single-question versions", {
  qz <- quiz(question("2 + 2?", answer("4", correct = TRUE)), caption = "Arithmetic")

  expect_no_error(print(qz))
  result <- withVisible(print(qz))
  expect_false(result$visible)
  expect_identical(result$value, qz)

  kp <- knitr::knit_print(qz)
  expect_s3_class(kp, "knit_asis")
  expect_match(as.character(kp), "learnr2-quiz-caption")
})

# ---- internal helpers (question.R) ----------------------------------

test_that("slugify() lowercases, collapses runs of non-alphanumerics to one dash, trims, and caps at 60", {
  expect_equal(learnr2:::slugify("Hello, World!"), "hello-world")
  expect_equal(learnr2:::slugify("  leading & trailing  "), "leading-trailing")
  expect_equal(learnr2:::slugify("multiple---dashes___here"), "multiple-dashes-here")
  expect_equal(learnr2:::slugify("6. Quiz Questions"), "6-quiz-questions")
  expect_equal(learnr2:::slugify("!!!"), "question")   # nothing survives -> fallback
  expect_equal(learnr2:::slugify(""), "question")
  expect_lte(nchar(learnr2:::slugify(strrep("a", 200))), 60)
})

test_that("current_chunk_label() is NULL when not knitting", {
  # The test suite itself is not run through knitr.
  expect_null(learnr2:::current_chunk_label())
})

test_that("current_chunk_label() returns the running chunk's label, but rejects knitr's auto-names", {
  saved <- knitr::opts_current$get()
  saved_opt <- options(knitr.in.progress = TRUE)
  on.exit({
    knitr::opts_current$restore(saved)
    options(saved_opt)
  }, add = TRUE)

  knitr::opts_current$set(label = "creating-vectors-2")
  expect_equal(learnr2:::current_chunk_label(), "creating-vectors-2")

  knitr::opts_current$set(label = "unnamed-chunk-12")
  expect_null(learnr2:::current_chunk_label())
})

test_that("learnr2_dependency() bundles quiz.js and quiz.css as an htmlDependency", {
  dep <- learnr2:::learnr2_dependency()
  expect_s3_class(dep, "html_dependency")
  expect_equal(dep$name, "learnr2-quiz")
  expect_equal(dep$script, "quiz.js")
  expect_equal(dep$stylesheet, "quiz.css")
  expect_true(fs::file_exists(fs::path(dep$src$file, dep$script)))
  expect_true(fs::file_exists(fs::path(dep$src$file, dep$stylesheet)))
})

test_that("question_id() disambiguates within one render but is stable across question texts", {
  # Fresh registry state is not guaranteed between test files, so use ids
  # unlikely to have been claimed already.
  a <- learnr2:::question_id("zzz-unique-base", "irrelevant")
  b <- learnr2:::question_id("zzz-unique-base", "irrelevant")
  expect_equal(a, "zzz-unique-base")
  expect_equal(b, "zzz-unique-base-2")
})
