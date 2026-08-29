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
#' The download includes a `metadata` block (timestamp, timezone, browser
#' info, and a random per-device id persisted across the reader's visits)
#' and a SHA-256 `integrity` hash over the content. Check a downloaded file
#' with [verify_submission()]. This is tamper-*evidence*, not proof of
#' identity: since everything runs in the reader's own browser with no
#' server-held secret, a technical reader could reproduce the hash
#' themselves. What it reliably catches is editing the file afterward (e.g.
#' changing a wrong answer to a right one before turning it in).
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

#' Verify a downloaded submission's integrity hash
#'
#' Checks a JSON file downloaded via [download_answers_button()] against its
#' embedded SHA-256 hash, to detect whether it was edited after being
#' downloaded (e.g. a wrong answer quietly changed to a right one before
#' being turned in). This is tamper-*evidence*, not proof of identity: the
#' hash is computed entirely in the reader's own browser with no
#' server-held secret, so a technical reader could in principle reproduce
#' it themselves -- this is a deterrent and a check against casual editing,
#' not real cryptographic security.
#'
#' @param path Path to a JSON file downloaded via [download_answers_button()].
#'
#' @return Invisibly, a list with `ok` (logical) and the parsed submission
#'   `content`. Also prints a human-readable summary.
#' @export
#' @examples
#' \dontrun{
#' verify_submission("class-101-2026-01-15T12-00-00-000Z.json")
#' }
verify_submission <- function(path) {
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("`path` must be a single non-empty string.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop(
      "The 'digest' package is required to verify submissions. ",
      "Install it with install.packages(\"digest\").",
      call. = FALSE
    )
  }

  raw_text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  parsed <- tryCatch(
    jsonlite::fromJSON(raw_text, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) {
    message("FAILED: could not parse '", path, "' as JSON.")
    return(invisible(list(ok = FALSE, content = NULL)))
  }

  integrity <- parsed$integrity
  if (is.null(integrity$hash) || is.null(integrity$hashedContent)) {
    message(
      "FAILED: '", path, "' has no integrity hash -- not downloaded via ",
      "learnr2::download_answers_button(), or it predates this feature."
    )
    return(invisible(list(ok = FALSE, content = parsed)))
  }

  computed_hash <- digest::digest(integrity$hashedContent, algo = "sha256", serialize = FALSE)
  hash_ok <- identical(computed_hash, integrity$hash)

  # The hash only certifies `hashedContent` itself; separately confirm the
  # human-readable top-level fields match it, in case only *those* were
  # hand-edited after download, leaving the integrity block untouched.
  hashed_parsed <- tryCatch(
    jsonlite::fromJSON(integrity$hashedContent, simplifyVector = FALSE),
    error = function(e) NULL
  )
  visible_fields <- c("page", "downloadedAt", "info", "answers", "metadata")
  visible_ok <- !is.null(hashed_parsed) &&
    isTRUE(all.equal(hashed_parsed, parsed[visible_fields]))

  ok <- hash_ok && visible_ok

  if (ok) {
    message("OK: '", path, "' matches its integrity hash -- unedited since download.")
  } else if (!hash_ok) {
    message(
      "TAMPERED: '", path, "'s hash does not match its content.\n",
      "  Expected: ", integrity$hash, "\n",
      "  Computed: ", computed_hash
    )
  } else {
    message("TAMPERED: '", path, "'s visible content does not match its hashed content.")
  }

  info <- parsed$info
  metadata <- parsed$metadata
  message(
    "  Name: ", if (is.null(info$name)) "(none)" else info$name, "\n",
    "  Email: ", if (is.null(info$email)) "(none)" else info$email, "\n",
    "  Captured at: ", if (is.null(metadata$capturedAt)) "(unknown)" else metadata$capturedAt, "\n",
    "  Device id: ", if (is.null(metadata$deviceId)) "(unknown)" else metadata$deviceId
  )

  invisible(list(ok = ok, content = parsed))
}
