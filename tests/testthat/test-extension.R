# Covers R/extension.R: live_extension_dir(), add_live_extension().

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

test_that("live_extension_dir() returns the bundled _extensions path", {
  dir <- live_extension_dir()
  expect_type(dir, "character")
  expect_length(dir, 1)
  expect_true(fs::dir_exists(dir))
  # The 'quarto-live' extension itself lives one level down.
  expect_true(fs::dir_exists(fs::path(dir, "r-wasm", "live")))
})

# NOTE: live_extension_dir()'s `if (!nzchar(path))` guard fires only when the
# installed package is missing inst/extdata/_extensions entirely. That can't
# be provoked from a test without uninstalling/corrupting the package
# (base::system.file() cannot be mocked -- its binding is locked), so the
# guard is left as untested defensive code by design.

test_that("add_live_extension() copies the extension into <dir>/_extensions/", {
  tmp <- withr::local_tempdir()
  add_live_extension(tmp)
  expect_true(fs::dir_exists(fs::path(tmp, "_extensions", "r-wasm", "live")))
})

test_that("add_live_extension() returns the _extensions path, invisibly", {
  tmp <- withr::local_tempdir()
  res <- withVisible(add_live_extension(tmp))
  expect_false(res$visible)
  expect_equal(fs::path_abs(res$value), fs::path_abs(fs::path(tmp, "_extensions")))
})

test_that("add_live_extension() creates the target directory if it doesn't exist", {
  tmp <- fs::path(withr::local_tempdir(), "not", "there", "yet")
  expect_false(fs::dir_exists(tmp))
  add_live_extension(tmp)
  expect_true(fs::dir_exists(fs::path(tmp, "_extensions", "r-wasm")))
})

test_that("add_live_extension(overwrite = TRUE) replaces an existing copy", {
  tmp <- withr::local_tempdir()
  add_live_extension(tmp)

  stale <- fs::path(tmp, "_extensions", "r-wasm", "STALE-MARKER")
  fs::file_create(stale)

  add_live_extension(tmp, overwrite = TRUE)
  expect_false(fs::file_exists(stale))            # old copy was deleted first
  expect_true(fs::dir_exists(fs::path(tmp, "_extensions", "r-wasm", "live")))
})

test_that("add_live_extension(overwrite = FALSE) leaves an existing copy untouched", {
  tmp <- withr::local_tempdir()
  add_live_extension(tmp)

  keep <- fs::path(tmp, "_extensions", "r-wasm", "KEEP-MARKER")
  fs::file_create(keep)

  res <- withVisible(add_live_extension(tmp, overwrite = FALSE))
  expect_true(fs::file_exists(keep))              # early return -- nothing recopied
  expect_false(res$visible)
  expect_equal(fs::path_abs(res$value), fs::path_abs(fs::path(tmp, "_extensions")))
})

test_that("add_live_extension() has no default dir: it never writes anywhere unnamed", {
  expect_identical(formals(add_live_extension)$dir, quote(expr = ))  # no default
  expect_error(add_live_extension(), "`dir` must be a single directory path")
  expect_error(add_live_extension(NULL), "`dir` must be")
  expect_error(add_live_extension(c("a", "b")), "`dir` must be")
})

test_that("check_dir_arg() accepts a single non-empty string and returns it invisibly", {
  res <- withVisible(learnr2:::check_dir_arg("somewhere", FALSE))
  expect_identical(res$value, "somewhere")
  expect_false(res$visible)
  expect_error(learnr2:::check_dir_arg("somewhere", TRUE), "`dir` must be")
})
