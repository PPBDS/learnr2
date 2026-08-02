#' Define an answer choice for a quiz question
#'
#' @param text The answer text shown to the reader. For `type = "text"`
#'   questions (see [question()]), this is instead one acceptable response
#'   that the reader's typed input is compared against. For `"reflection"`
#'   and `"reflection_editable"` questions, the `text` of every `correct`
#'   answer is shown to the reader as the model answer -- it is not compared
#'   against anything.
#' @param correct Is this a correct answer? Defaults to `FALSE`. For
#'   `"reflection"`/`"reflection_editable"` questions, this instead marks
#'   `text` as one of the model answers to reveal.
#' @param message Optional feedback shown when the reader picks (or types)
#'   this specific answer. Unused for `"reflection"`/`"reflection_editable"`
#'   questions.
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
#'   exactly one answer is marked `correct`, and `"multiple"` otherwise.
#'   Other types:
#'   * `"text"` -- a free-text question, graded by comparing (trimmed,
#'     whitespace-collapsed, case-insensitive) the reader's response against
#'     the [answer()] text(s).
#'   * `"reflection"` -- an ungraded free-response question. After
#'     submitting, the reader sees the model answer (the `correct`
#'     [answer()] text(s)) and their own response is locked.
#'   * `"reflection_editable"` -- like `"reflection"`, but the reader's
#'     response stays editable after the model answer is revealed, so they
#'     can keep revising it.
#' @param correct Message shown when the reader answers correctly. Unused
#'   for `"reflection"`/`"reflection_editable"` questions.
#' @param incorrect Message shown when the reader answers incorrectly. Unused
#'   for `"reflection"`/`"reflection_editable"` questions.
#' @param allow_retry Allow the reader to try again after an incorrect
#'   answer? Defaults to `FALSE`. Unused for
#'   `"reflection"`/`"reflection_editable"` questions.
#' @param random_answer_order Shuffle answer order each time the page loads?
#'   Defaults to `FALSE`. Only applies to `"single"`/`"multiple"` questions.
#' @param submit_button,try_again_button Button labels.
#' @param edit_button Button label shown instead of `submit_button` once a
#'   `"reflection_editable"` question has been submitted at least once --
#'   from then on, clicking it revises the reader's already-visible answer
#'   rather than submitting for the first time. Ignored for every other
#'   `type`, since only `"reflection_editable"` stays open for revision
#'   after the model answer is revealed.
#' @param id Stable identifier used to key the reader's saved answer (see
#'   "Progress persistence" below). Defaults to a slug derived from `text`.
#'   Set this explicitly if you plan to edit the question wording later and
#'   want readers' saved answers to survive the edit.
#' @param allow_image For `"reflection"`/`"reflection_editable"` questions,
#'   let the reader paste a PNG image (e.g. a screenshot) from their
#'   clipboard, alongside their typed response -- not a file upload, just
#'   Ctrl+V/Cmd+V into the question. Defaults to `FALSE`. Ignored for other
#'   question types.
#' @param validate Client-side format check applied before the reader can
#'   submit a `"text"`, `"reflection"`, or `"reflection_editable"` answer.
#'   `"none"` (the default) accepts anything. `"integer"` requires the typed
#'   response to be a whole number (optionally signed, e.g. `-3`) -- useful
#'   for a question like "how many minutes did this take?" where any honest
#'   number is fine, but free-form prose is not; see the `"reflection"`
#'   example below. Ignored (forced to `"none"`) for `"single"`/`"multiple"`
#'   questions.
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
#' `localStorage` is written straight to disk, not held only in memory, so
#' this survives closing and reopening the browser, and restarting the
#' computer -- confirmed with automated tests
#' (`tests/js/persistence.spec.js`) that fully quit and relaunch a real
#' browser against the same profile, for both a `file://` tutorial (how
#' [run_tutorial()] opens one) and one served over HTTP. Two things it does
#' *not* survive, by browser design rather than anything learnr2 controls:
#' private/incognito windows (their storage is wiped when the window
#' closes) and the exact page URL changing -- a tutorial re-rendered to a
#' different path, or opened from a different server/port, starts fresh.
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
#'
#' question(
#'   "How many minutes, approximately, did this take?",
#'   answer(
#'     "There's no fixed correct answer here -- just enter your honest estimate.",
#'     correct = TRUE
#'   ),
#'   type = "reflection_editable",
#'   validate = "integer"
#' )
question <- function(text,
                      ...,
                      type = c(
                        "auto", "single", "multiple", "text",
                        "reflection", "reflection_editable"
                      ),
                      correct = "Correct!",
                      incorrect = "Incorrect.",
                      allow_retry = FALSE,
                      random_answer_order = FALSE,
                      submit_button = "Submit Answer",
                      try_again_button = "Try Again",
                      edit_button = "Edit Answer",
                      id = NULL,
                      allow_image = FALSE,
                      validate = c("none", "integer")) {
  type <- match.arg(type)
  validate <- match.arg(validate)

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
  is_choice_type <- type %in% c("single", "multiple")
  is_reflection_type <- type %in% c("reflection", "reflection_editable")
  is_free_text_type <- type %in% c("text", "reflection", "reflection_editable")

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
    randomAnswerOrder = isTRUE(random_answer_order) && is_choice_type,
    submitLabel = submit_button,
    tryAgainLabel = try_again_button,
    editLabel = edit_button,
    allowImage = isTRUE(allow_image) && is_reflection_type,
    validate = if (is_free_text_type) validate else "none"
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

learnr2_dependency <- function() {
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
  htmltools::attachDependencies(question_div(x), learnr2_dependency())
}

#' @exportS3Method
quiz_html.learnr2_quiz <- function(x) {
  container <- htmltools::tags$div(
    class = "learnr2-quiz",
    htmltools::tags$div(class = "learnr2-quiz-caption", x$caption),
    lapply(x$questions, question_div)
  )
  htmltools::attachDependencies(container, learnr2_dependency())
}

#' @exportS3Method knitr::knit_print
knit_print.learnr2_question <- function(x, ...) {
  knitr::knit_print(quiz_html(x), ...)
}

#' @exportS3Method knitr::knit_print
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
