# Covers R/utils.R: `%||%`, is_string(), check_string(), check_label().

test_that("%||% returns the left side unless it is NULL", {
  expect_identical(learnr2:::`%||%`(NULL, "b"), "b")
  expect_identical(learnr2:::`%||%`("a", "b"), "a")
  expect_identical(learnr2:::`%||%`(NA, "b"), NA)
})

test_that("is_string() is TRUE only for one non-empty, non-NA string", {
  expect_true(learnr2:::is_string("x"))
  expect_false(learnr2:::is_string(""))
  expect_false(learnr2:::is_string(NA_character_))
  expect_false(learnr2:::is_string(c("a", "b")))
  expect_false(learnr2:::is_string(1))
  expect_false(learnr2:::is_string(NULL))
})

test_that("check_string() and check_label() name the argument in their errors", {
  expect_invisible(learnr2:::check_string("x", "name"))
  expect_error(learnr2:::check_string("", "name"), "`name` must be a single non-empty string")
  expect_error(learnr2:::check_string(NULL, "name"), "`name` must be a single non-empty string")
  expect_true(learnr2:::check_label(NULL, "label"))
  expect_true(learnr2:::check_label("x", "label"))
  expect_error(learnr2:::check_label("", "label"), "`label` must be NULL or a single non-empty string")
  expect_error(learnr2:::check_label(c("a", "b"), "label"), "NULL or a single")
})
