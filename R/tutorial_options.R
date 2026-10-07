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
#' @section Defaults:
#' * `allow_skip = FALSE`
#'
#' @param allow_skip Logical. May the reader use a table-of-contents link to
#'   unlock and jump to a section they have not reached yet? Default
#'   `FALSE`.
#'
#' @return A `learnr2_options` object, printed as an invisible HTML
#'   element that the page's JavaScript reads at load.
#' @export
#' @examples
#' tutorial_options()
#' tutorial_options(allow_skip = TRUE)
tutorial_options <- function(allow_skip = FALSE) {
  if (!is.logical(allow_skip) || length(allow_skip) != 1 || is.na(allow_skip)) {
    stop("`allow_skip` must be TRUE or FALSE.", call. = FALSE)
  }
  payload <- list(allowSkip = allow_skip)
  structure(list(payload = payload), class = "learnr2_options")
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
