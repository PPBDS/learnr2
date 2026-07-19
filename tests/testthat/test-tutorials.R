test_that("the bundled extension can be located", {
  dir <- live_extension_dir()
  expect_true(fs::dir_exists(fs::path(dir, "r-wasm", "live")))
})

test_that("add_live_extension copies the extension", {
  tmp <- fs::path(tempfile())
  fs::dir_create(tmp)
  on.exit(fs::dir_delete(tmp), add = TRUE)

  add_live_extension(tmp)
  expect_true(fs::dir_exists(fs::path(tmp, "_extensions", "r-wasm", "live")))
})

test_that("the hello-learnr2 tutorial is available", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_s3_class(tutorials, "data.frame")
  expect_true(all(c("package", "name", "title") %in% names(tutorials)))
  expect_true("hello-learnr2" %in% tutorials$name)
  expect_true(all(tutorials$package == "learnr2"))
})

test_that("available_tutorials() with no package scans every installed package", {
  tutorials <- available_tutorials()
  expect_true("hello-learnr2" %in% tutorials$name[tutorials$package == "learnr2"])
})

test_that("available_tutorials() validates and errors on an unknown package", {
  expect_error(available_tutorials(package = ""), "single non-empty string")
  expect_error(available_tutorials(package = "not-a-real-package-xyz"), "No package found")
})

test_that("the hello-learnr2 tutorial demonstrates quiz questions", {
  qmd <- system.file(
    "tutorials", "hello-learnr2", "hello-learnr2.qmd",
    package = "learnr2"
  )
  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "learnr2::question\\(")
  expect_match(contents, "learnr2::quiz\\(")
})

test_that("run_tutorial() defaults to a persistent output_dir, not tempdir()", {
  # R deletes its own session tempdir() on exit; a browser opened via
  # `open = TRUE` in a non-interactive session (e.g. Rscript) can lose the
  # race and find the file already gone. The default output_dir must not
  # live under tempdir().
  default_output_dir <- eval(formals(run_tutorial)$output_dir)
  expect_false(startsWith(default_output_dir, tempdir()))
})

test_that("create_tutorial scaffolds a qmd and extension", {
  tmp <- fs::path(tempfile())
  fs::dir_create(tmp)
  on.exit(fs::dir_delete(tmp), add = TRUE)

  qmd <- create_tutorial("demo", dir = tmp, open = FALSE)
  expect_true(fs::file_exists(qmd))
  expect_true(fs::dir_exists(fs::path(tmp, "demo", "_extensions", "r-wasm")))

  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "format: live-html")
})

test_that("create_tutorial() scaffolds a student_info() section by default", {
  tmp <- fs::path(tempfile())
  fs::dir_create(tmp)
  on.exit(fs::dir_delete(tmp), add = TRUE)

  qmd <- create_tutorial("demo", dir = tmp, open = FALSE)
  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "learnr2::student_info\\(")
})
