#' Collect student identifying information
#'
#' Adds a small, ungraded form for the reader to fill in identifying
#' information before starting a tutorial: name and email required, an ID
#' optional, by default. Unlike [question()], nothing here is graded and
#' there is no model answer to reveal.
#'
#' The form has two states. While *editing*, the fields are open and the
#' button reads "Submit". A valid Submit saves the entry, locks the fields,
#' and switches the button to "Edit". Clicking Edit only reopens the fields
#' and switches the button back to "Submit", with a note that the change
#' isn't saved until the next Submit. So the button always tells the reader
#' whether what they see is what was received. Typing is kept as a draft in
#' the browser's `localStorage`, so a reload mid-edit loses nothing, but a
#' draft is never the answer: [download_answers_button()] reports only the
#' last submitted entry, and is blocked until the form is submitted. A
#' `"reflection_editable"` [question()] works the same way. Pair with
#' [download_answers_button()] so a reader can turn their work in.
#'
#' @param fields A named character vector of field key/label pairs to
#'   collect, e.g. `c(name = "Full name:", section = "Section:")`. `NULL`,
#'   the default, gives the three fields of 'tutorial.helpers''s
#'   `info_section.Rmd` -- `name`, `email` and an optional `id` -- labelled
#'   in the page language (see the "Language" section of [question()]).
#'   A field named `"email"` is additionally checked for an `"@"`
#'   character, regardless of whether it is `required`.
#' @param required Character vector of keys (from `fields`) the reader must
#'   fill in. Defaults to whichever of `"name"` and `"email"` are actually
#'   present in `fields`, so ID is optional by default and supplying custom
#'   `fields` does not require also supplying `required`. A required field
#'   left blank, or an `"email"` field missing an `"@"`, is flagged inline
#'   (on blur, and again when the button is clicked) and the form can't
#'   be submitted until it's fixed. Passing a key that is not in `fields`
#'   is an error.
#' @param id Stable identifier used to key the saved values in
#'   `localStorage`. Defaults to `"student-info"`; change it if a single
#'   tutorial embeds more than one `student_info()` form.
#' @param submit_button Button label while the form is open for editing.
#'   `NULL`, the default, means the page language's "Submit".
#' @param edit_button Button label while the form is locked on a
#'   submission. Clicking it reopens the form. `NULL`, the default, means
#'   the page language's "Edit".
#'
#' @return A `learnr2_info` object, printed as an interactive HTML form.
#' @export
#' @examples
#' student_info()
#' student_info(fields = c(name = "Full name:", section = "Section:"), required = "name")
student_info <- function(fields = NULL,
                          required = intersect(c("name", "email"), names(fields) %||% default_info_fields),
                          id = "student-info",
                          submit_button = NULL,
                          edit_button = NULL) {
  # The default fields carry no label: quiz.js labels them in the document's
  # language (field_name, field_email, field_id in lang/<lang>.json).
  default_labels <- is.null(fields)
  if (default_labels) {
    fields <- stats::setNames(rep(NA_character_, length(default_info_fields)), default_info_fields)
  }
  if (!is.character(fields) || length(fields) == 0 ||
      is.null(names(fields)) || any(!nzchar(names(fields)))) {
    stop("`fields` must be a named character vector, e.g. c(name = \"Name:\").", call. = FALSE)
  }
  check_label(submit_button, "submit_button")
  check_label(edit_button, "edit_button")
  check_string(id, "id")

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
        label = if (default_labels) NULL else unname(fields[i]),
        required = field_keys[i] %in% required
      )
    }),
    submitLabel = submit_button,
    editLabel = edit_button
  )

  structure(list(payload = payload), class = "learnr2_info")
}

default_info_fields <- c("name", "email", "id")

info_div <- function(info) {
  widget_div("learnr2-info", "data-learnr2-info", info$payload, noscript = "noscript_info")
}

#' @exportS3Method
widget_html.learnr2_info <- function(x) with_dependency(info_div(x))

#' @exportS3Method knitr::knit_print
knit_print.learnr2_info <- function(x, ...) knit_widget(x, ...)

#' @export
print.learnr2_info <- function(x, ...) print_widget(x)

#' Add a "download my answers" button
#'
#' Adds a button that, when clicked, gathers every [question()] and
#' [student_info()] answer currently on the page -- each already saved to
#' the browser's `localStorage` when the reader submitted it -- into a
#' single readable JSON file and downloads it. Only submitted answers
#' count: an answer reopened with "Edit" and not resubmitted is reported as
#' its last submitted version, and the download is blocked until every
#' [student_info()] form is submitted. This happens
#' entirely in the reader's browser; there is no server to submit to, so
#' this is meant for a reader to save and turn in themselves (e.g. attach
#' to an email or upload to an LMS).
#'
#' The download's `answers` array is one flat list: every [question()] plus
#' every `{webr}` code exercise, each as a `{ id, answer }` pair keyed by
#' the widget's (or exercise's) stable id. A question never submitted has
#' `answer: null`; a choice question's `answer` is an array of the picked
#' options; an image-paste reflection's `answer` is the pasted screenshot
#' as a data-URL string (WebP, or JPEG where the browser can't write
#' WebP; see [question()]'s `allow_image`).
#'
#' A `{webr}` exercise appears only under the condition quarto-live itself
#' requires to keep a record of the reader's code at all: `#| persist:
#' true` (already the convention every bundled tutorial follows). An
#' exercise without `persist: true` has no saved copy of the reader's code
#' anywhere -- `learnr2` included -- so it can't appear in the download;
#' this is a structural limit of quarto-live's own editor, not something
#' `download_answers_button()` chooses to skip.
#'
#' The file opens with what it is a submission *for*: `package` and
#' `version` (the package the tutorial ships in, and that package's version
#' as rendered), `tutorial` (the tutorial's name, its directory under
#' `inst/tutorials/`), `title` (its YAML title) and `learnr2Version`. These
#' are filled in at render time -- by [render_tutorials()], and so by
#' [run_tutorial()] and [prerender_tutorials()], which know where the
#' tutorial came from, or from the `.qmd`'s own location when it is
#' rendered with `quarto render` inside a package tree. A tutorial outside
#' any package has `package` and `version` `null`.
#'
#' The download also carries a `metadata` block (timezone, browser info, and
#' a random per-device id persisted across the reader's visits) and a `time`
#' field: the moment the reader clicked "Download", lightly obfuscated so the
#' raw timestamp isn't readable or hand-editable in the file. Recover it with
#' [submission_time()].
#'
#' The file ends with two fields for the grader. `fingerprint` is a SHA-256
#' of the submission's identifying content (time, device id, `loadedFrom`,
#' the info fields and every answer), so a name or an answer edited by hand
#' in the file no longer matches it; [check_submission()] recomputes and
#' compares. `loadedFrom` is `null` unless the page was restored from an
#' earlier download ([load_tutorial()] or the page's Load Answers button),
#' in which case it records that file's `time`, device id, fingerprint,
#' name and email, so a resubmission can be traced to the file it grew
#' from. Neither is a signature: everything runs in the reader's browser
#' with no secret, so a reader who reads the code can regenerate both. They
#' make the common case, a copied file with the name changed, visible; they
#' do not make the file tamper-proof.
#'
#' @param filename_prefix Prefix for the downloaded file's name. Defaults
#'   to `"learnr2-answers"`.
#' @param label Button label. `NULL`, the default, means the page
#'   language's "Download My Answers" (see the "Language" section of
#'   [question()]).
#'
#' @return A `learnr2_download_button` object, printed as an interactive
#'   HTML button.
#' @export
#' @examples
#' download_answers_button()
download_answers_button <- function(filename_prefix = "learnr2-answers",
                                     label = NULL) {
  check_string(filename_prefix, "filename_prefix")
  check_label(label, "label")

  identity <- render_identity()
  payload <- list(
    filenamePrefix = filename_prefix,
    label = label,
    package = identity$package,
    version = identity$version,
    tutorial = identity$tutorial,
    title = identity$title,
    learnr2Version = as.character(utils::packageVersion("learnr2"))
  )
  structure(list(payload = payload), class = "learnr2_download_button")
}

# What the download file's header says about the tutorial being rendered.
# render_tutorials() passes the source tutorial's identity through the
# environment (TUTORIAL_ENV in R/render_tutorials.R), since Quarto knits in
# its own R process from a copy of the tutorial. Without that -- a plain
# `quarto render` of a .qmd -- the file being knit is read from its own
# location. At the console there is no tutorial, and every field is NULL.
render_identity <- function() {
  knitting <- isTRUE(getOption("knitr.in.progress"))
  env <- Sys.getenv(unname(TUTORIAL_ENV), unset = "", names = TRUE)
  identity <- if (nzchar(env[[TUTORIAL_ENV[["tutorial"]]]])) {
    list(
      package = if (nzchar(env[[TUTORIAL_ENV[["package"]]]])) env[[TUTORIAL_ENV[["package"]]]],
      version = if (nzchar(env[[TUTORIAL_ENV[["version"]]]])) env[[TUTORIAL_ENV[["version"]]]],
      tutorial = env[[TUTORIAL_ENV[["tutorial"]]]]
    )
  } else if (knitting) {
    input <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NULL)
    if (is.null(input) || !nzchar(input)) list() else tutorial_identity(input)
  } else {
    list()
  }
  title <- if (knitting) rmarkdown::metadata$title else NULL
  list(
    package = identity$package,
    version = identity$version,
    tutorial = identity$tutorial,
    title = if (is.character(title) && length(title) == 1) title else NULL
  )
}

download_button_div <- function(button) {
  widget_div("learnr2-download-answers", "data-learnr2-download", button$payload,
             noscript = "noscript_download")
}

#' @exportS3Method
widget_html.learnr2_download_button <- function(x) with_dependency(download_button_div(x))

#' @exportS3Method knitr::knit_print
knit_print.learnr2_download_button <- function(x, ...) knit_widget(x, ...)

#' @export
print.learnr2_download_button <- function(x, ...) print_widget(x)

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
#' This reads only `time`. For the file's `fingerprint` and `loadedFrom`
#' provenance, see [check_submission()].
#'
#' @param x Path to a JSON file downloaded via [download_answers_button()],
#'   or the raw `time` string from one.
#'
#' @return The download time as a `POSIXct` (UTC), invisibly. Also prints a
#'   short summary --- with the reader's name, email, and device id when `x`
#'   is a file.
#' @export
#' @examples
#' # Decode a bare time code:
#' submission_time("52mz7x0xv")
#'
#' # Or read it, along with the reader's details, from a downloaded file:
#' answers <- tempfile(fileext = ".json")
#' writeLines(
#'   '{"time": "52mz7x0xv", "info": {"name": "Ada", "email": "ada@example.com"}}',
#'   answers
#' )
#' submission_time(answers)
#' unlink(answers)
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
# used by the tests.
encode_submission_time <- function(when) {
  encode_base36(floor(as.numeric(when)) * .time_mul + .time_add)
}

#' Check a submission's fingerprint and provenance
#'
#' Every file from [download_answers_button()] ends with a `fingerprint`,
#' a SHA-256 of its identifying content, and a `loadedFrom` block when the
#' page it came from had been restored from an earlier download. This
#' recomputes the fingerprint from the file's own `time`, device id,
#' `loadedFrom`, info fields and answers and says whether it still matches,
#' then reports where the file came from. A file whose name or answers were
#' edited by hand after downloading fails the check. It is not proof of
#' anything: the scheme runs in the browser with no secret, so a reader who
#' studies `quiz.js` can regenerate a fingerprint. It catches the ordinary
#' case, a copied file with the name changed, and makes a resubmission
#' traceable to the file it grew from.
#'
#' SHA-256 comes from `tools::sha256sum()`, available from R 4.5.0; on an
#' older R the fingerprint is reported as `"unchecked"`.
#'
#' @param path Path to a JSON file downloaded via [download_answers_button()].
#'
#' @return Invisibly, a list: `time` (POSIXct, UTC, or `NULL`), `name`,
#'   `email`, `device` (the per-device id), `fingerprint` (one of
#'   `"valid"`, `"invalid"`, `"missing"`, `"unchecked"`) and `loaded_from`
#'   (the file's provenance block as a list, or `NULL`). Also prints a
#'   summary.
#' @seealso [submission_time()], [load_tutorial()].
#' @export
#' @examples
#' answers <- tempfile(fileext = ".json")
#' writeLines('{"time": "52mz7x0xv", "info": {"name": "Ada"}, "answers": []}', answers)
#' check_submission(answers)
check_submission <- function(path) {
  file <- read_answers_file(path)
  info <- file$info %||% list()
  device <- file$metadata$deviceId
  state <- if (!is_string(file$fingerprint)) {
    "missing"
  } else if (!exists("sha256sum", asNamespace("tools"))) {
    "unchecked"
  } else if (identical(sha256_text(canonical_submission(file)), tolower(file$fingerprint))) {
    "valid"
  } else {
    "invalid"
  }
  when <- if (is_string(file$time)) decode_submission_time(file$time) else NULL
  from <- if (is.list(file$loadedFrom)) file$loadedFrom else NULL

  lines <- c(
    paste0("Submitted: ", if (is.null(when)) "unknown" else format(when, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")),
    paste0("Name: ", info$name %||% "(none)", "  Email: ", info$email %||% "(none)"),
    paste0("Device: ", device %||% "(none)"),
    paste0("Fingerprint: ", switch(state,
      valid = "valid (the file matches what was downloaded)",
      invalid = "INVALID (the file was edited after it was downloaded)",
      missing = "missing (downloaded before fingerprints, or stripped)",
      unchecked = "unchecked (tools::sha256sum() needs R 4.5.0 or later)"
    ))
  )
  if (!is.null(from)) {
    from_when <- if (is_string(from$time)) decode_submission_time(from$time) else NULL
    lines <- c(lines, paste0(
      "Loaded from: a file downloaded ",
      if (is.null(from_when)) "at an unknown time" else format(from_when, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
      " by ", from$name %||% "(no name)", " <", from$email %||% "no email", ">",
      " on device ", from$deviceId %||% "(unknown)",
      if (!identical(from$deviceId, device)) " -- a DIFFERENT device from this download" else ""
    ))
  } else {
    lines <- c(lines, "Loaded from: nothing (a fresh run of the tutorial)")
  }
  message(paste(lines, collapse = "\n"))
  invisible(list(time = when, name = info$name, email = info$email, device = device,
                 fingerprint = state, loaded_from = from))
}

# The text the fingerprint hashes. Mirrors canonicalSubmission() in quiz.js
# line for line: header, time, device, the loaded-from file's fingerprint,
# the info fields in byte order of their keys (JavaScript sorts by code
# unit; `method = "radix"` does the same, not the session locale), then
# every answer in file order -- an array joined with U+001F, a missing
# answer as "<null>".
canonical_submission <- function(file) {
  info <- file$info %||% list()
  from <- file$loadedFrom
  lines <- c(
    "learnr2-fingerprint-v1",
    paste0("time=", file$time %||% ""),
    paste0("device=", file$metadata$deviceId %||% ""),
    paste0("loadedFrom=", if (is.list(from) && is_string(from$fingerprint)) from$fingerprint else "")
  )
  for (key in sort(names(info), method = "radix")) {
    lines <- c(lines, paste0("info.", key, "=", if (is.null(info[[key]])) "" else as.character(info[[key]])))
  }
  for (a in file$answers) {
    v <- a$answer
    text <- if (is.null(v)) {
      "<null>"
    } else if (is.list(v)) {
      paste(vapply(v, as.character, character(1)), collapse = "\u001f")
    } else {
      as.character(v)
    }
    lines <- c(lines, paste0("answer.", a$id, "=", text))
  }
  paste(lines, collapse = "\n")
}

sha256_text <- function(text) {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeBin(charToRaw(enc2utf8(text)), tmp)
  unname(tools::sha256sum(tmp))
}
