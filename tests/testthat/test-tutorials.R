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
  expect_true("hello-learnr2" %in% available_tutorials())
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
