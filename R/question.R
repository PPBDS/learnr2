#' Define an answer choice for a quiz question
#'
#' @param text The answer text shown to the reader. For `type = "text"`
#'   questions (see [question()]), this is instead one acceptable response
#'   that the reader's typed input is compared against.
#' @param correct Is this a correct answer? Defaults to `FALSE`.
#' @param message Optional feedback shown when the reader picks (or types)
#'   this specific answer.
#'
#' @return A `learnr2_answer` object for use inside [question()].
#' @export
#' @examples
#' answer("4", correct = TRUE)
#' answer("3", message = "Close, but check your arithmetic.")
answer <- function(text, correct = FALSE, message = NULL) {
  if (missing(text) || !is.character(text) || length(text) != 1 || is.na(text)) {
    stop("`text` must be a single string.", call. = FALSE)
  }
  structure(
    list(text = text, correct = isTRUE(correct), message = message),
    class = "learnr2_answer"
  )
}

#' @export
print.learnr2_answer <- function(x, ...) {
  flag <- if (x$correct) " [correct]" else ""
  cat("<answer: \"", x$text, "\"", flag, ">\n", sep = "")
  invisible(x)
}

#' Create a quiz question
#'
#' A learnr-style quiz question, rendered as a small self-contained,
#' client-side interactive widget --- no Shiny or R server required. Supports
#' single-choice ("radio"), multiple-choice ("checkbox"), and free-text
#' questions, graded entirely in the reader's browser.
#'
#' @param text Question prompt.
#' @param ... One or more [answer()] objects.
#' @param type Question type. `"auto"` (the default) picks `"single"` when
#'   exactly one answer is marked `correct`, and `"multiple"` otherwise. Use
#'   `"text"` for a free-text question, where the reader types a response
#'   that is compared (trimmed, whitespace-collapsed, case-insensitive)
#'   against the [answer()] text(s).
#' @param correct Message shown when the reader answers correctly.
#' @param incorrect Message shown when the reader answers incorrectly.
#' @param allow_retry Allow the reader to try again after an incorrect
#'   answer? Defaults to `FALSE`.
#' @param random_answer_order Shuffle answer order each time the page loads?
#'   Defaults to `FALSE`. Ignored for `type = "text"`.
#' @param submit_button,try_again_button Button labels.
#' @param id Stable identifier used to key the reader's saved answer (see
#'   "Progress persistence" below). Defaults to a slug derived from `text`.
#'   Set this explicitly if you plan to edit the question wording later and
#'   want readers' saved answers to survive the edit.
#'
#' @return A `learnr2_question` object. Printed as an interactive HTML
#'   widget, both in a rendered Quarto document and (via a browser preview)
#'   at the R console.
#'
#' @section Progress persistence:
#' Once a reader submits an answer, it is saved in the browser's
#' `localStorage` (keyed by page URL and `id`) and restored on the next
#' visit. Because the default `id` is derived from `text`, editing a
#' question's wording changes its `id` and resets any saved answers for it;
#' pass `id` explicitly to avoid that.
#'
#' @export
#' @examples
#' question(
#'   "What is 6 times 7?",
#'   answer("42", correct = TRUE),
#'   answer("36"),
#'   answer("48"),
#'   allow_retry = TRUE
#' )
question <- function(text,
                      ...,
                      type = c("auto", "single", "multiple", "text"),
                      correct = "Correct!",
                      incorrect = "Incorrect.",
                      allow_retry = FALSE,
                      random_answer_order = FALSE,
                      submit_button = "Submit Answer",
                      try_again_button = "Try Again",
                      id = NULL) {
  type <- match.arg(type)

  if (!is.null(id) && (!is.character(id) || length(id) != 1 || !nzchar(id))) {
    stop("`id` must be a single non-empty string.", call. = FALSE)
  }

  if (missing(text) || !is.character(text) || length(text) != 1) {
    stop("`text` must be a single string.", call. = FALSE)
  }

  answers <- list(...)
  if (length(answers) == 0) {
    stop("`question()` requires at least one `answer()`.", call. = FALSE)
  }
  is_answer <- vapply(answers, inherits, logical(1), "learnr2_answer")
  if (!all(is_answer)) {
    stop("All elements of `...` must be created with `answer()`.", call. = FALSE)
  }

  n_correct <- sum(vapply(answers, function(a) a$correct, logical(1)))
  if (n_correct == 0) {
    stop("`question()` needs at least one correct `answer()`.", call. = FALSE)
  }

  if (type == "auto") {
    type <- if (n_correct > 1) "multiple" else "single"
  }

  payload <- list(
    id = question_id(id, text),
    text = text,
    type = type,
    answers = lapply(answers, function(a) {
      list(text = a$text, correct = a$correct, message = a$message)
    }),
    correctMessage = correct,
    incorrectMessage = incorrect,
    allowRetry = isTRUE(allow_retry),
    randomAnswerOrder = isTRUE(random_answer_order) && type != "text",
    submitLabel = submit_button,
    tryAgainLabel = try_again_button
  )

  structure(list(payload = payload), class = "learnr2_question")
}

# Deterministic ids (stable across re-renders, so saved answers in
# localStorage survive re-rendering the same tutorial) with disambiguation
# for repeats within one render.
slugify <- function(text) {
  slug <- tolower(text)
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-+|-+$", "", slug)
  if (!nzchar(slug)) {
    slug <- "question"
  }
  substr(slug, 1, 60)
}

question_registry <- new.env(parent = emptyenv())

question_id <- function(id, text) {
  base <- paste0("learnr2-question-", slugify(if (!is.null(id)) id else text))
  candidate <- base
  n <- 1L
  while (exists(candidate, envir = question_registry, inherits = FALSE)) {
    n <- n + 1L
    candidate <- paste0(base, "-", n)
  }
  assign(candidate, TRUE, envir = question_registry)
  candidate
}

#' Group questions into a quiz
#'
#' @param ... One or more [question()] objects.
#' @param caption Heading shown above the questions.
#'
#' @return A `learnr2_quiz` object, printed as a set of interactive widgets.
#' @export
#' @examples
#' quiz(
#'   caption = "Arithmetic",
#'   question(
#'     "What is 2 + 2?",
#'     answer("4", correct = TRUE),
#'     answer("22")
#'   )
#' )
quiz <- function(..., caption = "Quiz") {
  questions <- list(...)
  is_question <- vapply(questions, inherits, logical(1), "learnr2_question")
  if (length(questions) == 0 || !all(is_question)) {
    stop("`quiz()` requires one or more `question()` objects.", call. = FALSE)
  }
  structure(list(caption = caption, questions = questions), class = "learnr2_quiz")
}

# ---- Rendering -------------------------------------------------------------

quiz_dependency <- function() {
  htmltools::htmlDependency(
    name = "learnr2-quiz",
    version = as.character(utils::packageVersion("learnr2")),
    src = system.file("extdata", "quiz", package = "learnr2"),
    script = "quiz.js",
    stylesheet = "quiz.css",
    all_files = FALSE
  )
}

question_div <- function(question) {
  json <- jsonlite::toJSON(question$payload, auto_unbox = TRUE, null = "null")
  encoded <- jsonlite::base64_enc(charToRaw(as.character(json)))
  htmltools::tags$div(
    class = "learnr2-question",
    `data-learnr2-question` = encoded,
    htmltools::tags$noscript("This quiz question requires JavaScript.")
  )
}

quiz_html <- function(x) {
  UseMethod("quiz_html")
}

#' @exportS3Method
quiz_html.learnr2_question <- function(x) {
  htmltools::attachDependencies(question_div(x), quiz_dependency())
}

#' @exportS3Method
quiz_html.learnr2_quiz <- function(x) {
  container <- htmltools::tags$div(
    class = "learnr2-quiz",
    htmltools::tags$div(class = "learnr2-quiz-caption", x$caption),
    lapply(x$questions, question_div)
  )
  htmltools::attachDependencies(container, quiz_dependency())
}

#' @export
knit_print.learnr2_question <- function(x, ...) {
  knitr::knit_print(quiz_html(x), ...)
}

#' @export
knit_print.learnr2_quiz <- function(x, ...) {
  knitr::knit_print(quiz_html(x), ...)
}

#' @export
print.learnr2_question <- function(x, ...) {
  print(htmltools::browsable(quiz_html(x)))
  invisible(x)
}

#' @export
print.learnr2_quiz <- function(x, ...) {
  print(htmltools::browsable(quiz_html(x)))
  invisible(x)
}
