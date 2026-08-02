test_that("answer() validates and constructs a learnr2_answer", {
  a <- answer("42", correct = TRUE, message = "Nice.")
  expect_s3_class(a, "learnr2_answer")
  expect_equal(a$text, "42")
  expect_true(a$correct)
  expect_equal(a$message, "Nice.")

  expect_false(answer("7")$correct)
  expect_error(answer(1), "single string")
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

test_that("reflection types still require at least one correct answer", {
  expect_error(
    question("Reflect on this.", answer("not marked correct"), type = "reflection"),
    "at least one correct"
  )
})

test_that("question ids are deterministic slugs of the text", {
  q <- question("The Deterministic ID Test Case!!", answer("x", correct = TRUE))
  expect_equal(q$payload$id, "learnr2-question-the-deterministic-id-test-case")
})

test_that("explicit id overrides the text-derived slug", {
  q <- question("Ignored text", answer("x", correct = TRUE), id = "custom-id-xyz")
  expect_equal(q$payload$id, "learnr2-question-custom-id-xyz")
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
  html <- quiz_html(q)
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
  html <- as.character(quiz_html(qz))
  expect_match(html, "learnr2-quiz-caption")
  expect_equal(lengths(regmatches(html, gregexpr("learnr2-question\"", html))), 2)
})
