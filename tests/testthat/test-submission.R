test_that("student_info() builds the default name/email/id fields", {
  info <- student_info()
  expect_s3_class(info, "learnr2_info")
  expect_equal(info$payload$id, "learnr2-info-student-info")
  expect_length(info$payload$fields, 3)
  expect_equal(info$payload$fields[[1]]$key, "name")
  expect_equal(info$payload$fields[[1]]$label, "Name:")
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
