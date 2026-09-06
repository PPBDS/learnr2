test_that("student_info() builds the default name/email/id fields", {
  info <- student_info()
  expect_s3_class(info, "learnr2_info")
  expect_equal(info$payload$id, "learnr2-info-student-info")
  expect_length(info$payload$fields, 3)
  expect_equal(info$payload$fields[[1]]$key, "name")
  expect_equal(info$payload$fields[[1]]$label, "Name:")
})

test_that("student_info() has a Submit button label, customizable like question()'s", {
  info <- student_info()
  expect_equal(info$payload$submitLabel, "Submit")

  custom <- student_info(submit_button = "Save Info")
  expect_equal(custom$payload$submitLabel, "Save Info")
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
  expect_equal(btn$payload$label, "Download My Answers")

  btn2 <- download_answers_button(filename_prefix = "class-101", label = "Turn In")
  expect_equal(btn2$payload$filenamePrefix, "class-101")
  expect_equal(btn2$payload$label, "Turn In")
})

test_that("download_answers_button() validates its arguments", {
  expect_error(download_answers_button(filename_prefix = ""), "single non-empty string")
  expect_error(download_answers_button(label = ""), "single non-empty string")
})

test_that("rendered info/button HTML embeds a decodable payload with the quiz dependency", {
  info <- student_info()
  info_html_obj <- learnr2:::info_html(info)
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
  btn_html_obj <- learnr2:::download_button_html(btn)
  encoded2 <- btn_html_obj$attribs[["data-learnr2-download"]]
  decoded2 <- jsonlite::fromJSON(
    rawToChar(jsonlite::base64_dec(encoded2)),
    simplifyVector = FALSE
  )
  expect_equal(decoded2$filenamePrefix, "learnr2-answers")
})

test_that("print.learnr2_info and knit_print.learnr2_info behave like question()'s print/knit_print", {
  info <- student_info()

  expect_no_error(print(info))
  result <- withVisible(print(info))
  expect_false(result$visible)
  expect_identical(result$value, info)

  kp <- knitr::knit_print(info)
  expect_s3_class(kp, "knit_asis")
  html <- as.character(kp)
  expect_match(html, "learnr2-info")
  expect_match(html, "data-learnr2-info")
})

test_that("print.learnr2_download_button and knit_print.learnr2_download_button behave like question()'s print/knit_print", {
  btn <- download_answers_button()

  expect_no_error(print(btn))
  result <- withVisible(print(btn))
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
