#' Collect student identifying information
#'
#' Adds a small, ungraded form for the reader to fill in identifying
#' information before starting a tutorial: name and email required, an ID
#' optional, by default. Unlike [question()], nothing here is graded and
#' there is no model answer to reveal -- it is auto-saved to the browser's
#' `localStorage` as the reader types and restored on their next visit, the
#' same as every other field here. A confirmation button, matching the one
#' on every [question()] in both style and behavior, gives the reader an
#' explicit way to confirm their entry and see the required fields checked
#' right away, instead of only finding out when they later try to download:
#' it reads "Submit" until they successfully do, at which point it switches
#' to "Edit" (like a `"reflection_editable"` [question()]) since any further
#' click is revising an already-confirmed entry, not submitting for the
#' first time. Pair with [download_answers_button()] so a reader can turn
#' their work in.
#'
#' @param fields A named character vector of field key/label pairs to
#'   collect. Defaults to name, email, and an optional ID, matching
#'   'tutorial.helpers''s `info_section.Rmd`. A field named `"email"` is
#'   additionally checked for an `"@"` character, regardless of whether it
#'   is `required`.
#' @param required Character vector of keys (from `fields`) the reader must
#'   fill in. Defaults to whichever of `"name"` and `"email"` are actually
#'   present in `fields`, so ID is optional by default and supplying custom
#'   `fields` does not require also supplying `required`. A required field
#'   left blank, or an `"email"` field missing an `"@"`, is flagged inline
#'   (on blur, and again when the button is clicked) and blocks
#'   [download_answers_button()] until it's fixed. Passing a key that is
#'   not in `fields` is an error.
#' @param id Stable identifier used to key the saved values in
#'   `localStorage`. Defaults to `"student-info"`; change it if a single
#'   tutorial embeds more than one `student_info()` form.
#' @param submit_button Button label shown before the reader has
#'   successfully confirmed their entry.
#' @param edit_button Button label shown instead of `submit_button` from
#'   then on -- mirrors [question()]'s `edit_button` for a
#'   `"reflection_editable"` question exactly, including persisting across
#'   a reload.
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
                          required = intersect(c("name", "email"), names(fields)),
                          id = "student-info",
                          submit_button = "Submit",
                          edit_button = "Edit") {
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
    }),
    submitLabel = submit_button,
    editLabel = edit_button
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

#' @exportS3Method knitr::knit_print
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
#' The download's `answers` array is one flat list: every [question()] plus
#' every `{webr}` code exercise, each as a `{ id, answer }` pair keyed by
#' the widget's (or exercise's) stable id. A question never submitted has
#' `answer: null`; a choice question's `answer` is an array of the picked
#' options; an image-paste reflection's `answer` is the pasted screenshot
#' as a PNG data-URL string.
#'
#' A `{webr}` exercise appears only under the condition quarto-live itself
#' requires to keep a record of the reader's code at all: `#| persist:
#' true` (already the convention every bundled tutorial follows). An
#' exercise without `persist: true` has no saved copy of the reader's code
#' anywhere -- `learnr2` included -- so it can't appear in the download;
#' this is a structural limit of quarto-live's own editor, not something
#' `download_answers_button()` chooses to skip.
#'
#' The download also carries a `metadata` block (timezone, browser info, and
#' a random per-device id persisted across the reader's visits) and a `time`
#' field: the moment the reader clicked "Download", lightly obfuscated so the
#' raw timestamp isn't readable or hand-editable in the file. Recover it with
#' [submission_time()]. Nothing else is hashed or signed -- a determined
#' reader can still edit their answers; this only keeps the submission time
#' honest at a glance.
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

#' @exportS3Method knitr::knit_print
knit_print.learnr2_download_button <- function(x, ...) {
  knitr::knit_print(download_button_html(x), ...)
}

#' @export
print.learnr2_download_button <- function(x, ...) {
  print(htmltools::browsable(download_button_html(x)))
  invisible(x)
}

#' Recover a submission's download time
#'
#' [download_answers_button()] writes the moment the reader clicked
#' "Download" into the JSON as a `time` field, lightly obfuscated: base-36 of
#' the epoch second run through a fixed multiply-and-offset. It is *not*
#' encrypted --- the scheme is public, in `inst/extdata/quiz/quiz.js` ---
#' just enough that the raw timestamp isn't sitting in the file where a
#' student could read it, or swap in a different plausible time without
#' re-running the encoder. This function reverses it.
#'
#' Nothing else in the file is hashed or signed, so this does **not** detect
#' edited answers. If you need that, compare against work submitted through a
#' channel you control.
#'
#' @param x Path to a JSON file downloaded via [download_answers_button()],
#'   or the raw `time` string from one.
#'
#' @return The download time as a `POSIXct` (UTC), invisibly. Also prints a
#'   short summary --- with the reader's name, email, and device id when `x`
#'   is a file.
#' @export
#' @examples
#' \dontrun{
#' submission_time("class-101-answers.json")
#' }
#' # Decode a bare time code:
#' submission_time(learnr2:::encode_submission_time(as.POSIXct("2026-01-15 12:00:00", tz = "UTC")))
submission_time <- function(x) {
  if (!is.character(x) || length(x) != 1 || !nzchar(x)) {
    stop(
      "`x` must be a single non-empty string (a file path or a `time` code).",
      call. = FALSE
    )
  }

  info <- NULL
  metadata <- NULL
  is_file <- file.exists(x)
  if (is_file) {
    raw_text <- paste(readLines(x, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    parsed <- tryCatch(
      jsonlite::fromJSON(raw_text, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(parsed)) {
      stop("Could not parse '", x, "' as JSON.", call. = FALSE)
    }
    code <- parsed$time
    info <- parsed$info
    metadata <- parsed$metadata
    if (is.null(code) || !is.character(code) || length(code) != 1) {
      stop(
        "'", x, "' has no `time` field -- not downloaded via ",
        "learnr2::download_answers_button(), or it predates this feature.",
        call. = FALSE
      )
    }
  } else {
    code <- x
  }

  when <- decode_submission_time(code)
  if (is.null(when)) {
    stop("'", code, "' is not a valid learnr2 time code.", call. = FALSE)
  }

  stamp <- format(when, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  if (is_file) {
    message(
      "Submitted: ", stamp, " UTC\n",
      "  Name: ", if (is.null(info$name)) "(none)" else info$name, "\n",
      "  Email: ", if (is.null(info$email)) "(none)" else info$email, "\n",
      "  Device id: ", if (is.null(metadata$deviceId)) "(unknown)" else metadata$deviceId
    )
  } else {
    message("Submitted: ", stamp, " UTC")
  }

  invisible(when)
}

# The obfuscation scheme shared with encodeDownloadTime() in
# inst/extdata/quiz/quiz.js -- keep the two constants in sync.
.time_mul <- 8093
.time_add <- 1000003

# Base-36 string -> numeric (double). The encoded values (~1.4e13) exceed
# .Machine$integer.max so strtoi() can't be used, but a double holds them
# exactly (well under 2^53). Returns NA for any non-[0-9a-z] character.
decode_base36 <- function(x) {
  chars <- utf8ToInt(tolower(x))
  vals <- ifelse(
    chars >= 48L & chars <= 57L, chars - 48L,
    ifelse(chars >= 97L & chars <= 122L, chars - 87L, NA_real_)
  )
  if (length(vals) == 0 || anyNA(vals)) {
    return(NA_real_)
  }
  Reduce(function(acc, d) acc * 36 + d, vals)
}

# time code -> POSIXct (UTC), or NULL if `code` isn't a valid one.
decode_submission_time <- function(code) {
  n <- decode_base36(code)
  if (is.na(n) || (n - .time_add) %% .time_mul != 0) {
    return(NULL)
  }
  as.POSIXct((n - .time_add) / .time_mul, origin = "1970-01-01", tz = "UTC")
}

# Numeric -> lowercase base-36 string, matching JavaScript's
# Number.prototype.toString(36). Input stays under 2^53, so the %% / division
# below are exact.
encode_base36 <- function(n) {
  n <- floor(n)
  if (n <= 0) {
    return("0")
  }
  out <- character(0)
  while (n > 0) {
    r <- n %% 36
    out <- c(if (r < 10) as.character(r) else intToUtf8(87 + r), out)
    n <- (n - r) / 36
  }
  paste0(out, collapse = "")
}

# POSIXct/numeric -> time code. Mirrors encodeDownloadTime() in quiz.js;
# used by tests and the roxygen example.
encode_submission_time <- function(when) {
  encode_base36(floor(as.numeric(when)) * .time_mul + .time_add)
}
