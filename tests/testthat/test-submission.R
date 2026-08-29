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

# Builds a submission JSON file exactly like the one quiz.js's
# collectAnswers() produces, with a correctly-computed integrity hash, so
# tests can start from something genuinely valid and then tamper with it.
write_valid_submission <- function(path, info = list(name = "Ada Lovelace", email = "ada@example.com")) {
  content <- list(
    page = "http://localhost/tutorial.html",
    downloadedAt = "2026-01-15T12:00:00.000Z",
    info = info,
    answers = list(
      list(id = "quiz-questions-1", answer = list("4")),
      list(id = "exercise-total-and-average-1", answer = "sum(1:100)")
    ),
    metadata = list(
      capturedAt = "2026-01-15T12:00:00.000Z",
      timezone = "America/New_York",
      userAgent = "test-agent",
      language = "en-US",
      screen = "1920x1080",
      deviceId = "test-device-id"
    )
  )
  hashed_content <- as.character(jsonlite::toJSON(content, auto_unbox = TRUE, null = "null"))
  hash <- digest::digest(hashed_content, algo = "sha256", serialize = FALSE)

  full <- c(content, list(integrity = list(algorithm = "sha256", hash = hash, hashedContent = hashed_content)))
  writeLines(as.character(jsonlite::toJSON(full, auto_unbox = TRUE, null = "null")), path, useBytes = TRUE)
  invisible(list(content = content, hashed_content = hashed_content, hash = hash))
}

test_that("verify_submission() reports ok for an untampered file", {
  skip_if_not_installed("digest")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  write_valid_submission(tmp)

  result <- suppressMessages(verify_submission(tmp))
  expect_true(result$ok)
})

test_that("verify_submission() detects a tampered hash", {
  skip_if_not_installed("digest")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  built <- write_valid_submission(tmp)

  # Simulate someone editing the visible answer without recomputing the hash:
  # corrupt the stored hash directly.
  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  raw$integrity$hash <- "0000000000000000000000000000000000000000000000000000000000000"
  writeLines(as.character(jsonlite::toJSON(raw, auto_unbox = TRUE, null = "null")), tmp, useBytes = TRUE)

  result <- suppressMessages(verify_submission(tmp))
  expect_false(result$ok)
})

test_that("verify_submission() detects visible content edited without updating hashedContent", {
  skip_if_not_installed("digest")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  write_valid_submission(tmp)

  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  raw$info$name <- "Someone Else"
  # integrity block deliberately left untouched -- still matches the
  # *original* hashedContent, but no longer matches the visible info.
  writeLines(as.character(jsonlite::toJSON(raw, auto_unbox = TRUE, null = "null")), tmp, useBytes = TRUE)

  result <- suppressMessages(verify_submission(tmp))
  expect_false(result$ok)
})

test_that("verify_submission() detects answers edited without updating hashedContent", {
  skip_if_not_installed("digest")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  write_valid_submission(tmp)

  # Same tamper pattern as the info-editing test above, but for an
  # answer/exercise entry specifically -- visible_fields (in
  # verify_submission()) has to be kept in sync with the submission format
  # by hand for this to actually be checked.
  raw <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  raw$answers[[2]]$answer <- "sum(1:1000000)"
  writeLines(as.character(jsonlite::toJSON(raw, auto_unbox = TRUE, null = "null")), tmp, useBytes = TRUE)

  result <- suppressMessages(verify_submission(tmp))
  expect_false(result$ok)
})

test_that("verify_submission() reports not-ok for a file with no integrity block", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  writeLines('{"page": "http://example.com", "info": {}}', tmp)

  result <- suppressMessages(verify_submission(tmp))
  expect_false(result$ok)
})

test_that("verify_submission() errors on a missing file or bad path", {
  expect_error(verify_submission(123), "single non-empty string")
  expect_error(verify_submission("this-file-does-not-exist.json"), "not found")
})
