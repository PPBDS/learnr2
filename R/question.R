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
#' @param ... One or more [answer()] objects. Optional for
#'   `"reflection"`/`"reflection_editable"` questions (see `type`); required,
#'   with at least one marked `correct`, for every other type.
#' @param type Question type. `"auto"` (the default) picks `"single"` when
#'   exactly one answer is marked `correct`, and `"multiple"` otherwise.
#'   Other types:
#'   * `"text"` -- a free-text question, graded by comparing (trimmed,
#'     whitespace-collapsed, case-insensitive) the reader's response against
#'     the [answer()] text(s).
#'   * `"reflection"` -- an ungraded free-response question. After
#'     submitting, the reader sees the model answer (the `correct`
#'     [answer()] text(s)) and their own response is locked. If no `answer()`
#'     is marked `correct` -- including passing none at all, e.g. for a
#'     genuinely open-ended prompt like "how many minutes did this take?"
#'     with no right answer to demonstrate -- nothing is revealed; the
#'     reader's response is still saved and locked exactly the same.
#'   * `"reflection_editable"` -- like `"reflection"`, but the reader's
#'     response stays editable after submitting (whether or not a model
#'     answer was revealed), so they can keep revising it.
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
#' @param id Stable identifier for this question: it keys the reader's saved
#'   answer (see "Progress persistence" below) and is the `id` the question
#'   appears under in a [download_answers_button()] submission. Defaults to
#'   the label of the `{r}` chunk the `question()` call sits in --- which,
#'   following `tutorial.helpers`' `section-header-N` chunk-naming
#'   convention, is already a unique, readable identifier (`## Quiz
#'   questions` -> `quiz-questions-1`, `quiz-questions-2`, ...). Falls back
#'   to a slug of `text` when there is no usable chunk label, e.g. when
#'   printing a `question()` at the console. Pass `id` explicitly to pin it
#'   regardless of where the call sits.
#' @param allow_image For `"reflection"`/`"reflection_editable"` questions,
#'   let the reader paste an image (e.g. a screenshot) from their clipboard,
#'   alongside their typed response -- not a file upload, just Ctrl+V/Cmd+V
#'   into the question. Defaults to `FALSE`. Ignored for other question
#'   types. Accepts PNG, JPEG, GIF, WebP, or BMP (whatever the reader's
#'   platform actually put on the clipboard -- this varies, and isn't
#'   guaranteed to be PNG just because they took a screenshot) and
#'   re-encodes it as PNG before storing it, so what ends up saved is
#'   always PNG regardless of the source format. Capped at 2MB.
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
#' visit. Because the default `id` is the enclosing `{r}` chunk's label,
#' renaming that chunk (or moving the question into a different one) resets
#' any saved answers for it --- but editing only the question's wording
#' does not. Pass `id` explicitly to pin it.
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
#' Every page also gets a "Start Over" button, appended automatically to
#' the bottom of Quarto's TOC sidebar (nothing to opt into -- it's added by
#' the same JavaScript that renders [question()]/[student_info()], as long
#' as the tutorial has a sidebar to put it in, i.e. `toc: true`). Clicking
#' it, after a confirmation prompt, clears every `question()`/
#' [student_info()] answer *and* every `{webr}` exercise's persisted code
#' (`persist: true`) for this page on this device, then reloads -- a clean
#' slate, without needing to know that both live under different
#' `localStorage` key prefixes. It deliberately leaves alone the random
#' per-device id [download_answers_button()] embeds in a submission's
#' metadata, since that identifies this browser across every tutorial and
#' visit, not this one tutorial's progress.
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
#' # No answer() at all -- a genuinely open-ended prompt with nothing to
#' # reveal after the reader submits.
#' question(
#'   "How many minutes, approximately, did this take?",
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
  is_answer <- vapply(answers, inherits, logical(1), "learnr2_answer")
  if (!all(is_answer)) {
    stop("All elements of `...` must be created with `answer()`.", call. = FALSE)
  }

  # Every other type needs a correct answer() to grade against; a
  # reflection question isn't graded at all, so it's the one type allowed
  # no answer()s, or none marked correct -- that's simply a reflection with
  # no model answer to reveal after the reader submits (see quiz.js's
  # buildReflectionQuestion(), which skips rendering the "Model answer:"
  # box entirely in that case rather than showing it empty).
  is_reflection_type <- type %in% c("reflection", "reflection_editable")

  if (length(answers) == 0 && !is_reflection_type) {
    stop("`question()` requires at least one `answer()`.", call. = FALSE)
  }

  n_correct <- sum(vapply(answers, function(a) a$correct, logical(1)))
  if (n_correct == 0 && !is_reflection_type) {
    stop("`question()` needs at least one correct `answer()`.", call. = FALSE)
  }

  if (type == "auto") {
    type <- if (n_correct > 1) "multiple" else "single"
  }
  is_choice_type <- type %in% c("single", "multiple")
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

# lowercase; every run of non-alphanumerics (including any already-present
# dashes) collapsed to a single dash; no leading/trailing dash; capped at
# 60 chars. This is the same shape tutorial.helpers' `section-header-N`
# chunk-label convention already produces, so applying it to a chunk label
# is a no-op -- it's here to defend against a hand-written `id` or a slug
# taken from free text.
slugify <- function(text) {
  slug <- tolower(text)
  # `-` is itself non-alphanumeric, so a run like " - " or "--" collapses
  # to one `-` here too.
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-+|-+$", "", slug)
  if (!nzchar(slug)) {
    slug <- "question"
  }
  substr(slug, 1, 60)
}

# The label of the `{r}` chunk currently being knit, or NULL when there
# isn't a meaningful one -- not rendering at all (a bare console `print()`),
# or an unlabelled chunk (knitr auto-names those "unnamed-chunk-N", which
# is neither stable nor readable, so it's no better than a text slug).
current_chunk_label <- function() {
  if (!isTRUE(getOption("knitr.in.progress"))) {
    return(NULL)
  }
  label <- knitr::opts_current$get("label")
  if (is.null(label) || !nzchar(label) ||
      grepl("^unnamed-chunk-[0-9]+$", label)) {
    return(NULL)
  }
  label
}

question_registry <- new.env(parent = emptyenv())

# Resolve a question's id -- deterministic, so a reader's saved answer in
# localStorage survives re-rendering the same tutorial. Most specific
# source first:
#   1. an explicit `id =` argument,
#   2. the enclosing chunk's label -- in a real tutorial every question()
#      sits in its own chunk labelled `section-header-N` (see AGENTS.md),
#      so the label is already a unique, human-meaningful identifier and
#      the natural thing to key saved answers / downloads on,
#   3. a slug of the question text, for when there is no usable label
#      (printing a question() at the console, an unlabelled chunk).
# A numeric suffix disambiguates repeats within one render -- e.g. a quiz()
# of several question()s all sharing their chunk's one label.
question_id <- function(id, text) {
  base <- if (!is.null(id)) {
    slugify(id)
  } else {
    label <- current_chunk_label()
    slugify(if (!is.null(label)) label else text)
  }
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
