#' Set tutorial-wide options
#'
#' Configures behaviour that applies to the whole tutorial page rather than
#' to one widget. Call it once, in its own `{r}` chunk with
#' `#| echo: false`, anywhere in the `.qmd`; it renders nothing visible.
#' Every option has a default, so a tutorial that never calls this
#' function behaves as described under "Defaults" below.
#'
#' @section Skipping ahead via the table of contents:
#' learnr2 reveals a tutorial one `##`/`###` section at a time, behind
#' "Continue" buttons (see the "Progress persistence" section of
#' [question()]). Quarto's table-of-contents sidebar lists every section
#' from the start, and each entry is a plain link to that section's
#' heading. By default (`allow_skip = FALSE`) an entry for a section the
#' reader has not reached yet is dimmed and inert: clicking it does
#' nothing, and it becomes a working link the moment that section is
#' unlocked. Entries for sections already reached navigate normally. So a
#' reader sees the shape of the tutorial and how far along they are, but
#' cannot use the sidebar to see the whole tutorial at once.
#'
#' With `allow_skip = TRUE`, clicking any entry instead unlocks every
#' section up to and including that one and jumps there -- the behaviour
#' of a classic 'learnr' tutorial with `allow_skip: yes`. Use it for
#' reference-style material a reader is meant to move around in freely,
#' such as learnr2's own `hello-learnr2` feature tour.
#'
#' Neither setting matters for a tutorial rendered with `toc: false`,
#' which has no sidebar and so only ever moves forward one Continue at a
#' time.
#'
#' @section Submitting before continuing:
#' By default (`require_submission = TRUE`) the "Continue" button at the
#' end of a section stays disabled, with a short note under it, until every
#' [question()] and [student_info()] form above it in that section has
#' been submitted. A reader can type anything, but they must submit
#' *something* before the tutorial moves on. Combined with `type =
#' "reflection"` questions, which lock once submitted, this is what lets a
#' tutorial show its own answer right after the reader's without inviting
#' them to copy it back into the box: by the time they see our answer,
#' theirs is already in and cannot be changed. Set `require_submission =
#' FALSE` for reference material a reader should be free to skim, such as
#' learnr2's own `hello-learnr2` feature tour. `{webr}` code cells are not
#' part of this check; they have no notion of being "submitted".
#'
#' @section Interface language:
#' Every string learnr2 puts on the page follows the document's language,
#' Quarto's `lang:` YAML key: `lang: fr` gives French "Continuer",
#' "Recommencer", "Soumettre la réponse" and so on, alongside Quarto's own
#' French table of contents. English is the default and the fallback for a
#' language learnr2 does not ship. `language` rewords single strings on
#' top of that, for a course that wants "Next" rather than "Continue",
#' say. Its names are the keys of the string table,
#' `system.file("extdata/quiz/lang/en.json", package = "learnr2")`; a
#' string may contain the placeholders the English one does, such as
#' `{title}` in `continue_to` or `{n}` in `continue_note_other`. An
#' unknown key is an error. The labels of [question()], [student_info()]
#' and [download_answers_button()] can also be set per call.
#'
#' @section Defaults:
#' * `allow_skip = FALSE`
#' * `require_submission = TRUE`
#' * `language = NULL`
#'
#' @param allow_skip Logical. May the reader use a table-of-contents link to
#'   unlock and jump to a section they have not reached yet? Default
#'   `FALSE`.
#' @param require_submission Logical. Must every question and student-info
#'   form in a section be submitted before its "Continue" button works?
#'   Default `TRUE`.
#' @param language `NULL`, or a named list or character vector of interface
#'   strings to override, e.g. `list(continue = "Next")`. See "Interface
#'   language" below.
#'
#' @return A `learnr2_options` object, printed as an invisible HTML
#'   element that the page's JavaScript reads at load.
#' @export
#' @examples
#' tutorial_options()
#' tutorial_options(allow_skip = TRUE)
#' tutorial_options(require_submission = FALSE)
#' tutorial_options(language = list(continue = "Next", start_over = "Reset"))
tutorial_options <- function(allow_skip = FALSE, require_submission = TRUE,
                             language = NULL) {
  check_flag(allow_skip, "allow_skip")
  check_flag(require_submission, "require_submission")
  payload <- list(allowSkip = allow_skip, requireSubmission = require_submission)
  if (!is.null(language)) {
    payload$language <- check_language_overrides(language)
  }
  structure(list(payload = payload), class = "learnr2_options")
}

# `language`: a named list or character vector of interface strings,
# keyed as in inst/extdata/quiz/lang/en.json. Returned as a named list of
# single strings. Unknown keys are an error, since a typo would otherwise
# silently change nothing.
check_language_overrides <- function(language) {
  if ((!is.list(language) && !is.character(language)) || length(language) == 0 ||
      is.null(names(language)) || any(!nzchar(names(language)))) {
    stop("`language` must be a named list or character vector, e.g. ",
         "list(continue = \"Next\").", call. = FALSE)
  }
  values <- lapply(language, function(v) {
    if (!is.character(v) || length(v) != 1 || is.na(v)) {
      stop("Every element of `language` must be a single string.", call. = FALSE)
    }
    v
  })
  unknown <- setdiff(names(values), names(tutorial_strings("en")))
  if (length(unknown) > 0) {
    stop("`language` has no interface string named ", paste0("`", unknown, "`", collapse = ", "),
         ". See the keys in `system.file(\"extdata/quiz/lang/en.json\", package = \"learnr2\")`.",
         call. = FALSE)
  }
  values
}

check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    stop("`", name, "` must be TRUE or FALSE.", call. = FALSE)
  }
  invisible(TRUE)
}

options_div <- function(x) {
  json <- jsonlite::toJSON(x$payload, auto_unbox = TRUE, null = "null")
  encoded <- jsonlite::base64_enc(charToRaw(as.character(json)))
  htmltools::tags$div(
    class = "learnr2-options",
    `data-learnr2-options` = encoded,
    hidden = NA
  )
}

options_html <- function(x) {
  htmltools::attachDependencies(options_div(x), learnr2_dependency())
}

#' @exportS3Method knitr::knit_print
knit_print.learnr2_options <- function(x, ...) {
  knitr::knit_print(options_html(x), ...)
}

#' @export
print.learnr2_options <- function(x, ...) {
  print(options_html(x), browse = interactive())
  invisible(x)
}
