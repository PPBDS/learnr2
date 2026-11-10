# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

test_that("student_info() builds the default name/email/id fields", {
  info <- student_info()
  expect_s3_class(info, "learnr2_info")
  expect_equal(info$payload$id, "learnr2-info-student-info")
  expect_length(info$payload$fields, 3)
  expect_equal(info$payload$fields[[1]]$key, "name")
  # Default fields have no label: quiz.js labels them in the page language.
  expect_null(info$payload$fields[[1]]$label)
  expect_equal(learnr2:::tutorial_string("field_name", "en"), "Name:")
})

test_that("student_info() has a Submit button label, customizable like question()'s", {
  info <- student_info()
  expect_null(info$payload$submitLabel)
  expect_null(info$payload$editLabel)

  custom <- student_info(submit_button = "Save Info", edit_button = "Change")
  expect_equal(custom$payload$submitLabel, "Save Info")
  expect_equal(custom$payload$editLabel, "Change")
  expect_error(student_info(submit_button = ""), "single non-empty string")
})

test_that("name and email are required by default, id is not", {
  info <- student_info()
  by_key <- stats::setNames(
    vapply(info$payload$fields, function(f) f$required, logical(1)),
    vapply(info$payload$fields, function(f) f$key, character(1))
  )
  expect_true(by_key[["name"]])
  expect_true(by_key[["email"]])
  expect_false(by_key[["id"]])
})

test_that("required can be customized", {
  info <- student_info(
    fields = c(name = "Full name:", section = "Section:"),
    required = "name"
  )
  by_key <- stats::setNames(
    vapply(info$payload$fields, function(f) f$required, logical(1)),
    vapply(info$payload$fields, function(f) f$key, character(1))
  )
  expect_true(by_key[["name"]])
  expect_false(by_key[["section"]])
})

test_that("required rejects keys not present in fields", {
  expect_error(
    student_info(fields = c(name = "Name:"), required = "email"),
    "not present in `fields`"
  )
})

test_that("student_info() accepts custom fields and id", {
  info <- student_info(
    fields = c(name = "Full name:", section = "Section:"),
    id = "custom"
  )
  expect_equal(info$payload$id, "learnr2-info-custom")
  expect_length(info$payload$fields, 2)
  expect_equal(info$payload$fields[[2]]$key, "section")
  expect_equal(info$payload$fields[[2]]$label, "Section:")
})

test_that("student_info() validates its arguments", {
  expect_error(student_info(fields = c("Name:")), "named character vector")
  expect_error(student_info(fields = character(0)), "named character vector")
  expect_error(student_info(id = ""), "single non-empty string")
})

test_that("download_answers_button() has sensible defaults and can be customized", {
  btn <- download_answers_button()
  expect_s3_class(btn, "learnr2_download_button")
  expect_equal(btn$payload$filenamePrefix, "learnr2-answers")
  expect_null(btn$payload$label)

  btn2 <- download_answers_button(filename_prefix = "class-101", label = "Turn In")
  expect_equal(btn2$payload$filenamePrefix, "class-101")
  expect_equal(btn2$payload$label, "Turn In")
})

test_that("download_answers_button() records what the file is a submission for", {
  # At the console there is no tutorial being rendered: nulls, but the keys
  # are there so quiz.js always finds them.
  withr::local_envvar(LEARNR2_TUTORIAL_PACKAGE = NA, LEARNR2_TUTORIAL_VERSION = NA,
                      LEARNR2_TUTORIAL_NAME = NA)
  btn <- download_answers_button()
  expect_true(all(c("package", "version", "tutorial", "title", "learnr2Version") %in% names(btn$payload)))
  expect_null(btn$payload$package)
  expect_null(btn$payload$tutorial)
  expect_equal(btn$payload$learnr2Version, as.character(utils::packageVersion("learnr2")))
  json <- jsonlite::toJSON(btn$payload, auto_unbox = TRUE, null = "null")
  expect_match(as.character(json), '"package":null', fixed = TRUE)

  # render_tutorials() hands the source tutorial's identity over in the
  # environment, which wins over anything else.
  withr::local_envvar(LEARNR2_TUTORIAL_PACKAGE = "my.tutorials", LEARNR2_TUTORIAL_VERSION = "2.0.1",
                      LEARNR2_TUTORIAL_NAME = "orientation")
  btn <- download_answers_button()
  expect_equal(btn$payload$package, "my.tutorials")
  expect_equal(btn$payload$version, "2.0.1")
  expect_equal(btn$payload$tutorial, "orientation")
  expect_null(btn$payload$title)

  # A tutorial outside any package: name only.
  withr::local_envvar(LEARNR2_TUTORIAL_PACKAGE = "", LEARNR2_TUTORIAL_VERSION = "",
                      LEARNR2_TUTORIAL_NAME = "standalone")
  id <- learnr2:::render_identity()
  expect_null(id$package)
  expect_equal(id$tutorial, "standalone")
})

test_that("download_answers_button() validates its arguments", {
  expect_error(download_answers_button(filename_prefix = ""), "single non-empty string")
  expect_error(download_answers_button(label = ""), "single non-empty string")
})

test_that("rendered info/button HTML embeds a decodable payload with the quiz dependency", {
  info <- student_info()
  info_html_obj <- learnr2:::widget_html(info)
  expect_true(inherits(info_html_obj, "shiny.tag"))
  encoded <- info_html_obj$attribs[["data-learnr2-info"]]
  decoded <- jsonlite::fromJSON(
    rawToChar(jsonlite::base64_dec(encoded)),
    simplifyVector = FALSE
  )
  expect_equal(decoded$id, "learnr2-info-student-info")
  expect_length(decoded$fields, 3)

  deps <- htmltools::findDependencies(info_html_obj)
  expect_true(any(vapply(deps, function(d) d$name == "learnr2-quiz", logical(1))))

  btn <- download_answers_button()
  btn_html_obj <- learnr2:::widget_html(btn)
  encoded2 <- btn_html_obj$attribs[["data-learnr2-download"]]
  decoded2 <- jsonlite::fromJSON(
    rawToChar(jsonlite::base64_dec(encoded2)),
    simplifyVector = FALSE
  )
  expect_equal(decoded2$filenamePrefix, "learnr2-answers")
})

test_that("print.learnr2_info and knit_print.learnr2_info behave like question()'s print/knit_print", {
  withr::local_options(viewer = function(...) stop("browser preview opened non-interactively"))
  info <- student_info()

  expect_output(print(info), "data-learnr2-info")
  capture.output(result <- withVisible(print(info)))
  expect_false(result$visible)
  expect_identical(result$value, info)

  kp <- knitr::knit_print(info)
  expect_s3_class(kp, "knit_asis")
  html <- as.character(kp)
  expect_match(html, "learnr2-info")
  expect_match(html, "data-learnr2-info")
})

test_that("print.learnr2_download_button and knit_print.learnr2_download_button behave like question()'s print/knit_print", {
  withr::local_options(viewer = function(...) stop("browser preview opened non-interactively"))
  btn <- download_answers_button()

  expect_output(print(btn), "data-learnr2-download")
  capture.output(result <- withVisible(print(btn)))
  expect_false(result$visible)
  expect_identical(result$value, btn)

  kp <- knitr::knit_print(btn)
  expect_s3_class(kp, "knit_asis")
  html <- as.character(kp)
  expect_match(html, "learnr2-download-answers")
  expect_match(html, "data-learnr2-download")
})

# Builds a submission JSON file in the shape quiz.js's collectAnswers()
# produces: no hashing, a `time` field carrying the obfuscated download time.
write_submission <- function(path,
                             info = list(name = "Ada Lovelace", email = "ada@example.com"),
                             when = as.POSIXct("2026-01-15 12:00:00", tz = "UTC")) {
  full <- list(
    page = "http://localhost/tutorial.html",
    info = info,
    answers = list(
      list(id = "quiz-questions-1", answer = list("4")),
      list(id = "exercise-total-and-average-1", answer = "sum(1:100)")
    ),
    metadata = list(
      timezone = "America/New_York",
      userAgent = "test-agent",
      language = "en-US",
      screen = "1920x1080",
      deviceId = "test-device-id"
    ),
    time = learnr2:::encode_submission_time(when)
  )
  writeLines(
    as.character(jsonlite::toJSON(full, auto_unbox = TRUE, null = "null")),
    path, useBytes = TRUE
  )
  invisible(list(full = full, when = when))
}

test_that("encode_base36() matches JavaScript's Number.prototype.toString(36)", {
  expect_equal(learnr2:::encode_base36(0), "0")
  expect_equal(learnr2:::encode_base36(35), "z")
  expect_equal(learnr2:::encode_base36(36), "10")
  # (1736942400 * 8093 + 1000003).toString(36) in Node:
  expect_equal(learnr2:::encode_base36(1736942400 * 8093 + 1000003), "4zdqc0i9v")
})

test_that("encode/decode_submission_time() round-trips at second resolution", {
  when <- as.POSIXct("2026-03-04 09:41:07", tz = "UTC")
  code <- learnr2:::encode_submission_time(when)
  expect_type(code, "character")
  expect_no_match(code, "[^0-9a-z]")
  expect_equal(learnr2:::decode_submission_time(code), when)
})

test_that("decode_submission_time() rejects codes that don't fit the scheme", {
  expect_null(learnr2:::decode_submission_time("not base 36 !!"))
  expect_null(learnr2:::decode_submission_time("zzzz"))          # valid base36, wrong residue
  expect_true(is.na(learnr2:::decode_base36("hello world")))
})

# The same fixture, canonical text and hash are pinned in tests/js/quiz.spec.js;
# the two implementations must agree on them.
fingerprint_fixture <- function() list(
  time = "abc",
  metadata = list(deviceId = "dev-1"),
  info = list(name = "Ada", email = "ada@example.com", id = NULL),
  answers = list(list(id = "q1", answer = list("a", "b")), list(id = "q2", answer = "Because."),
                 list(id = "q3", answer = NULL)),
  progress = list(sections = 2, of = 5, answered = 2, of_questions = 3),
  loadedFrom = NULL
)
fingerprint_canonical <- paste(c(
  "learnr2-fingerprint-v1", "time=abc", "device=dev-1", "loadedFrom=", "progress=2/5/2/3",
  "info.email=ada@example.com", "info.id=", "info.name=Ada",
  "answer.q1=a\u001fb", "answer.q2=Because.", "answer.q3=<null>"
), collapse = "\n")

test_that("canonical_submission() produces the pinned text, and sha256_text() hashes it", {
  skip_if_not(exists("sha256sum", asNamespace("tools")))
  expect_identical(learnr2:::canonical_submission(fingerprint_fixture()), fingerprint_canonical)
  expect_match(learnr2:::sha256_text(fingerprint_canonical), "^[0-9a-f]{64}$")
  # A loaded-from fingerprint is part of the text, so stripping it changes the hash.
  with_from <- utils::modifyList(fingerprint_fixture(), list(loadedFrom = list(fingerprint = "ff00")))
  expect_match(learnr2:::canonical_submission(with_from), "loadedFrom=ff00", fixed = TRUE)
})

write_fingerprinted <- function(dir, tamper = identity, fingerprint = TRUE) {
  file <- fingerprint_fixture()
  if (isTRUE(fingerprint)) file$fingerprint <- learnr2:::sha256_text(learnr2:::canonical_submission(file))
  file <- tamper(file)
  path <- fs::path(dir, "sub.json")
  jsonlite::write_json(file, path, auto_unbox = TRUE, null = "null")
  as.character(path)
}

test_that("check_submission() tells a pristine file from an edited one, and reports provenance", {
  skip_if_not(exists("sha256sum", asNamespace("tools")))
  dir <- withr::local_tempdir()
  expect_message(res <- check_submission(write_fingerprinted(dir)), "Fingerprint: valid")
  expect_message(check_submission(write_fingerprinted(dir)), "Progress: section 2 of 5, 2 of 3 questions answered")
  expect_equal(res$fingerprint, "valid")
  expect_equal(res$name, "Ada")
  expect_equal(res$progress$answered, 2)
  expect_null(res$loaded_from)
  # A file with no progress block (an ungated page, or an older download).
  no_progress <- write_fingerprinted(dir, function(f) { f$progress <- NULL; f$fingerprint <- learnr2:::sha256_text(learnr2:::canonical_submission(f)); f })
  expect_message(res <- check_submission(no_progress), "Progress: not recorded")
  expect_equal(res$fingerprint, "valid")

  edited <- write_fingerprinted(dir, function(f) { f$info$name <- "Bob"; f })
  expect_message(res <- check_submission(edited), "Fingerprint: INVALID")
  expect_equal(res$fingerprint, "invalid")
  edited_answer <- write_fingerprinted(dir, function(f) { f$answers[[2]]$answer <- "Copied."; f })
  expect_equal(suppressMessages(check_submission(edited_answer))$fingerprint, "invalid")

  expect_message(res <- check_submission(write_fingerprinted(dir, fingerprint = FALSE)), "Fingerprint: missing")
  expect_equal(res$fingerprint, "missing")

  with_from <- write_fingerprinted(dir, function(f) {
    f$loadedFrom <- list(time = "abc", deviceId = "dev-0", fingerprint = "ff00", name = "Carol", email = "c@x.org")
    f$fingerprint <- learnr2:::sha256_text(learnr2:::canonical_submission(f))
    f
  })
  expect_message(res <- check_submission(with_from), "Loaded from: .*by Carol <c@x.org> on device dev-0 -- a DIFFERENT device")
  expect_equal(res$fingerprint, "valid")
  expect_equal(res$loaded_from$name, "Carol")
})

test_that("check_submission() counts screenshots and recordings, and extract_submission_media() writes them out", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "ada.json")
  jsonlite::write_json(list(answers = list(
    list(id = "plot-1", answer = paste0("data:image/webp;base64,", jsonlite::base64_enc(charToRaw("webp bytes")))),
    list(id = "say-2", answer = paste0("data:audio/webm;codecs=opus;base64,", jsonlite::base64_enc(charToRaw("opus bytes")))),
    list(id = "text-3", answer = "data: is how a line of prose might start"),
    list(id = "odd-4", answer = paste0("data:audio/x-made-up;base64,", jsonlite::base64_enc(charToRaw("?")))),
    list(id = "none-5", answer = NULL)
  ), info = list(name = "Ada")), path, auto_unbox = TRUE, null = "null")

  expect_message(res <- check_submission(path), "Media: 1 screenshot\\(s\\), 2 recording\\(s\\)")
  expect_identical(res$screenshots, 1L)
  expect_identical(res$recordings, 2L)

  expect_message(files <- extract_submission_media(path), "Wrote 3 file\\(s\\) to '.*ada'")
  expect_identical(names(files), c("plot-1", "say-2", "odd-4"))
  expect_identical(basename(files), c("plot-1.webp", "say-2.webm", "odd-4.x-made-up"))
  expect_identical(dirname(files[[1]]), file.path(dir, "ada"))
  expect_identical(readBin(files[["say-2"]], "raw", 100), charToRaw("opus bytes"))
  expect_identical(readBin(files[["plot-1"]], "raw", 100), charToRaw("webp bytes"))

  out <- file.path(dir, "elsewhere", "deeper")
  expect_silent(files2 <- extract_submission_media(path, dir = out, quiet = TRUE))
  expect_true(all(file.exists(files2)))
  expect_identical(dirname(files2[[1]]), out)

  empty <- file.path(dir, "empty.json")
  writeLines('{"answers": [{"id": "t", "answer": "words"}]}', empty)
  expect_message(none <- extract_submission_media(empty), "No screenshots or recordings")
  expect_identical(none, character(0))
  expect_error(extract_submission_media(path, dir = 1), "`dir` must be a single non-empty string")
})

test_that("submission_time() decodes a bare time code", {
  code <- learnr2:::encode_submission_time(as.POSIXct("2026-01-15 12:00:00", tz = "UTC"))
  res <- withVisible(suppressMessages(submission_time(code)))
  expect_false(res$visible)
  expect_s3_class(res$value, "POSIXct")
  expect_equal(format(res$value, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2026-01-15 12:00:00")
  expect_message(submission_time(code), "Submitted: 2026-01-15 12:00:00 UTC")
})

test_that("submission_time() reads a downloaded file and prints a summary", {
  tmp <- withr::local_tempfile(fileext = ".json")
  write_submission(
    tmp,
    info = list(name = "Grace Hopper", email = "grace@example.com"),
    when = as.POSIXct("2026-01-15 12:00:00", tz = "UTC")
  )

  res <- suppressMessages(submission_time(tmp))
  expect_equal(format(res, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2026-01-15 12:00:00")
  expect_message(submission_time(tmp), "Submitted: 2026-01-15 12:00:00 UTC")
  expect_message(submission_time(tmp), "Grace Hopper")
  expect_message(submission_time(tmp), "grace@example.com")
  expect_message(submission_time(tmp), "test-device-id")
})

test_that("submission_time() validates its argument", {
  expect_error(submission_time(123), "single non-empty string")
  expect_error(submission_time(character(0)), "single non-empty string")
  expect_error(submission_time(""), "single non-empty string")
})

test_that("submission_time() errors on a file with no `time` field", {
  tmp <- withr::local_tempfile(fileext = ".json")
  writeLines('{"page": "http://example.com", "info": {}}', tmp)
  expect_error(submission_time(tmp), "no `time` field")
})

test_that("submission_time() errors on a file that isn't valid JSON", {
  tmp <- withr::local_tempfile(fileext = ".json")
  writeLines("this is not json {{{", tmp)
  expect_error(submission_time(tmp), "[Cc]ould not parse")
})

test_that("submission_time() errors on a non-file string that isn't a valid code", {
  expect_error(submission_time("definitely not a code"), "not a valid learnr2 time code")
})
