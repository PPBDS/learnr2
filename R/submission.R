#' Collect student identifying information
#'
#' Adds a small, ungraded form for the reader to fill in identifying
#' information before starting a tutorial: name and email required, an ID
#' optional, by default. Unlike [question()], nothing here is graded and
#' there is no model answer to reveal -- it is pure data collection,
#' auto-saved to the browser's `localStorage` as the reader types and
#' restored on their next visit. Pair with [download_answers_button()] so a
#' reader can turn their work in.
#'
#' @param fields A named character vector of field key/label pairs to
#'   collect. Defaults to name, email, and an optional ID, matching
#'   'tutorial.helpers''s `info_section.Rmd`.
#' @param required Character vector of keys (from `fields`) the reader must
#'   fill in. Defaults to `c("name", "email")`, so ID is optional by
#'   default. A required field left blank is flagged inline and blocks
#'   [download_answers_button()] until it's filled in.
#' @param id Stable identifier used to key the saved values in
#'   `localStorage`. Defaults to `"student-info"`; change it if a single
#'   tutorial embeds more than one `student_info()` form.
#'
#' @return A `learnr2_info` object, printed as an interactive HTML form.
#' @export
#' @examples
#' student_info()
#' student_info(fields = c(name = "Full name:", section = "Section:"), required = "name")
student_info <- function(fields = c(
                            name = "Name:",
                            email = "Email:",
                            id = "ID (if requested by your instructor):"
                          ),
                          required = c("name", "email"),
                          id = "student-info") {
  if (!is.character(fields) || length(fields) == 0 ||
      is.null(names(fields)) || any(!nzchar(names(fields)))) {
    stop("`fields` must be a named character vector, e.g. c(name = \"Name:\").", call. = FALSE)
  }
  if (!is.character(id) || length(id) != 1 || !nzchar(id)) {
    stop("`id` must be a single non-empty string.", call. = FALSE)
  }

  field_keys <- names(fields)
  if (!is.character(required)) {
    stop("`required` must be a character vector of keys from `fields`.", call. = FALSE)
  }
  unknown_required <- setdiff(required, field_keys)
  if (length(unknown_required) > 0) {
    stop(
      "`required` contains keys not present in `fields`: ",
      paste(unknown_required, collapse = ", "), ".",
      call. = FALSE
    )
  }

  payload <- list(
    id = paste0("learnr2-info-", slugify(id)),
    fields = lapply(seq_along(fields), function(i) {
      list(
        key = field_keys[i],
        label = unname(fields[i]),
        required = field_keys[i] %in% required
      )
    })
  )

  structure(list(payload = payload), class = "learnr2_info")
}

info_div <- function(info) {
  json <- jsonlite::toJSON(info$payload, auto_unbox = TRUE, null = "null")
  encoded <- jsonlite::base64_enc(charToRaw(as.character(json)))
  htmltools::tags$div(
    class = "learnr2-info",
    `data-learnr2-info` = encoded,
    htmltools::tags$noscript("This form requires JavaScript.")
  )
}

info_html <- function(x) {
  htmltools::attachDependencies(info_div(x), learnr2_dependency())
}

#' @export
knit_print.learnr2_info <- function(x, ...) {
  knitr::knit_print(info_html(x), ...)
}

#' @export
print.learnr2_info <- function(x, ...) {
  print(htmltools::browsable(info_html(x)))
  invisible(x)
}

#' Add a "download my answers" button
#'
#' Adds a button that, when clicked, gathers every [question()] and
#' [student_info()] answer currently on the page -- each already saved to
#' the browser's `localStorage` as the reader worked through the tutorial
#' -- into a single readable JSON file and downloads it. This happens
#' entirely in the reader's browser; there is no server to submit to, so
#' this is meant for a reader to save and turn in themselves (e.g. attach
#' to an email or upload to an LMS).
#'
#' @param filename_prefix Prefix for the downloaded file's name. Defaults
#'   to `"learnr2-answers"`.
#' @param label Button label. Defaults to `"Download My Answers"`.
#'
#' @return A `learnr2_download_button` object, printed as an interactive
#'   HTML button.
#' @export
#' @examples
#' download_answers_button()
download_answers_button <- function(filename_prefix = "learnr2-answers",
                                     label = "Download My Answers") {
  if (!is.character(filename_prefix) || length(filename_prefix) != 1 || !nzchar(filename_prefix)) {
    stop("`filename_prefix` must be a single non-empty string.", call. = FALSE)
  }
  if (!is.character(label) || length(label) != 1 || !nzchar(label)) {
    stop("`label` must be a single non-empty string.", call. = FALSE)
  }

  payload <- list(filenamePrefix = filename_prefix, label = label)
  structure(list(payload = payload), class = "learnr2_download_button")
}

download_button_div <- function(button) {
  json <- jsonlite::toJSON(button$payload, auto_unbox = TRUE, null = "null")
  encoded <- jsonlite::base64_enc(charToRaw(as.character(json)))
  htmltools::tags$div(
    class = "learnr2-download-answers",
    `data-learnr2-download` = encoded,
    htmltools::tags$noscript("This button requires JavaScript.")
  )
}

download_button_html <- function(x) {
  htmltools::attachDependencies(download_button_div(x), learnr2_dependency())
}

#' @export
knit_print.learnr2_download_button <- function(x, ...) {
  knitr::knit_print(download_button_html(x), ...)
}

#' @export
print.learnr2_download_button <- function(x, ...) {
  print(htmltools::browsable(download_button_html(x)))
  invisible(x)
}
