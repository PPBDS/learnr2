# Covers R/create_tutorial.R: create_tutorial(), open_file().

test_that("create_tutorial() scaffolds a qmd wired for format: live-html plus the extension", {
  parent <- withr::local_tempdir()
  qmd <- create_tutorial("demo", dir = parent, open = FALSE)

  expect_true(fs::file_exists(qmd))
  expect_equal(as.character(fs::path_file(qmd)), "demo.qmd")
  expect_equal(
    as.character(fs::path_dir(qmd)),
    as.character(fs::path_abs(fs::path(parent, "demo")))
  )
  expect_true(fs::dir_exists(fs::path(parent, "demo", "_extensions", "r-wasm")))

  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "format: live-html")
})

test_that("create_tutorial() substitutes {{title}} and {{name}} everywhere in the template", {
  parent <- withr::local_tempdir()
  qmd <- create_tutorial("my-demo", dir = parent, title = "My Great Demo", open = FALSE)

  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, 'title: "My Great Demo"', fixed = TRUE)
  expect_match(contents, 'filename_prefix = "my-demo"', fixed = TRUE)
  expect_false(grepl("{{title}}", contents, fixed = TRUE))
  expect_false(grepl("{{name}}", contents, fixed = TRUE))
})

test_that("create_tutorial() defaults the title to name", {
  parent <- withr::local_tempdir()
  qmd <- create_tutorial("plain-demo", dir = parent, open = FALSE)

  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, 'title: "plain-demo"', fixed = TRUE)
})

test_that("create_tutorial() scaffolds a student_info() section and a download button by default", {
  parent <- withr::local_tempdir()
  qmd <- create_tutorial("demo", dir = parent, open = FALSE)

  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "learnr2::student_info\\(")
  expect_match(contents, "learnr2::download_answers_button\\(")
})

test_that("create_tutorial() returns the qmd path, invisibly", {
  parent <- withr::local_tempdir()
  res <- withVisible(create_tutorial("demo", dir = parent, open = FALSE))
  expect_false(res$visible)
  expect_equal(
    as.character(res$value),
    as.character(fs::path(fs::path_abs(fs::path(parent, "demo")), "demo", ext = "qmd"))
  )
})

test_that("create_tutorial() validates name", {
  parent <- withr::local_tempdir()
  expect_error(create_tutorial(dir = parent, open = FALSE), "single non-empty string")
  expect_error(create_tutorial("", dir = parent, open = FALSE), "single non-empty string")
  expect_error(create_tutorial(c("a", "b"), dir = parent, open = FALSE), "single non-empty string")
  expect_error(create_tutorial(1, dir = parent, open = FALSE), "single non-empty string")
})

test_that("create_tutorial() refuses a target directory that already exists and is non-empty", {
  parent <- withr::local_tempdir()
  target <- fs::path(parent, "demo")
  fs::dir_create(target)
  fs::file_create(fs::path(target, "something.txt"))

  expect_error(
    create_tutorial("demo", dir = parent, open = FALSE),
    "already exists and is not empty"
  )
})

test_that("create_tutorial() proceeds when the target directory exists but is empty", {
  parent <- withr::local_tempdir()
  fs::dir_create(fs::path(parent, "demo"))
  expect_no_error(create_tutorial("demo", dir = parent, open = FALSE))
})

test_that("create_tutorial(open = TRUE) opens the new file via open_file()", {
  parent <- withr::local_tempdir()
  opened <- NULL
  local_mocked_bindings(open_file = function(path) {
    opened <<- path
    invisible(path)
  })

  qmd <- suppressMessages(create_tutorial("demo", dir = parent, open = TRUE))
  expect_equal(opened, qmd)
})

test_that("open_file() falls back to utils::browseURL() outside RStudio", {
  f <- withr::local_tempfile(fileext = ".qmd")
  file.create(f)
  withr::local_envvar(RSTUDIO = "")

  seen <- NULL
  local_mocked_bindings(isAvailable = function(...) FALSE, .package = "rstudioapi")
  local_mocked_bindings(
    browseURL = function(url, ...) {
      seen <<- url
      invisible()
    },
    .package = "utils"
  )

  res <- withVisible(learnr2:::open_file(f))
  expect_false(res$visible)
  expect_equal(res$value, f)
  expect_equal(seen, f)
})

test_that("open_file() uses rstudioapi::navigateToFile() when RStudio is available", {
  f <- withr::local_tempfile(fileext = ".qmd")
  file.create(f)

  navigated <- NULL
  local_mocked_bindings(isAvailable = function(...) TRUE, .package = "rstudioapi")
  local_mocked_bindings(hasFun = function(...) TRUE, .package = "rstudioapi")
  local_mocked_bindings(
    navigateToFile = function(file, ...) {
      navigated <<- file
      invisible()
    },
    .package = "rstudioapi"
  )

  learnr2:::open_file(f)
  expect_equal(navigated, f)
})

test_that("open_file() uses utils::file.edit() when RSTUDIO env var is set but the API isn't", {
  f <- withr::local_tempfile(fileext = ".qmd")
  file.create(f)
  withr::local_envvar(RSTUDIO = "1")

  edited <- NULL
  local_mocked_bindings(isAvailable = function(...) FALSE, .package = "rstudioapi")
  local_mocked_bindings(
    file.edit = function(...) {
      edited <<- c(...)
      invisible()
    },
    .package = "utils"
  )

  learnr2:::open_file(f)
  expect_equal(edited, f)
})
