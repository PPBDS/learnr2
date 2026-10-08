# Covers R/tutorial_options.R: tutorial_options(), options_div(),
# options_html(), and the print/knit_print methods.

test_that("tutorial_options() defaults to allow_skip = FALSE and require_submission = TRUE", {
  opts <- tutorial_options()
  expect_s3_class(opts, "learnr2_options")
  expect_false(opts$payload$allowSkip)
  expect_true(opts$payload$requireSubmission)
})

test_that("tutorial_options(require_submission = FALSE) is recorded in the payload", {
  expect_false(tutorial_options(require_submission = FALSE)$payload$requireSubmission)
})

test_that("tutorial_options(allow_skip = TRUE) is recorded in the payload", {
  expect_true(tutorial_options(allow_skip = TRUE)$payload$allowSkip)
})

test_that("tutorial_options() validates allow_skip", {
  expect_error(tutorial_options(allow_skip = "yes"), "TRUE or FALSE")
  expect_error(tutorial_options(allow_skip = NA), "TRUE or FALSE")
  expect_error(tutorial_options(allow_skip = c(TRUE, FALSE)), "TRUE or FALSE")
  expect_error(tutorial_options(require_submission = "no"), "`require_submission` must be TRUE or FALSE")
})

test_that("options_div() emits a hidden element quiz.js can decode", {
  div <- learnr2:::options_div(tutorial_options(allow_skip = TRUE))
  html <- as.character(div)
  expect_match(html, 'class="learnr2-options"', fixed = TRUE)
  expect_match(html, "hidden", fixed = TRUE)
  encoded <- regmatches(html, regexpr('data-learnr2-options="[^"]+"', html))
  encoded <- sub('data-learnr2-options="([^"]+)"', "\\1", encoded)
  decoded <- jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(encoded)))
  expect_true(decoded$allowSkip)
})

test_that("options_html() attaches the learnr2-quiz dependency", {
  deps <- htmltools::findDependencies(learnr2:::options_html(tutorial_options()))
  expect_equal(deps[[1]]$name, "learnr2-quiz")
})

test_that("print.learnr2_options and knit_print.learnr2_options behave like student_info()'s", {
  opts <- tutorial_options()
  expect_invisible(out <- withr::with_options(list(viewer = NULL), print(opts)))
  expect_identical(out, opts)
  knitted <- knitr::knit_print(opts)
  expect_s3_class(knitted, "knit_asis")
  expect_match(as.character(knitted), "learnr2-options", fixed = TRUE)
})
