# Covers R/create_tutorial.R: create_tutorial(), open_file().

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

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

test_that("create_tutorial() has no default dir: it never writes anywhere unnamed", {
  expect_identical(formals(create_tutorial)$dir, quote(expr = ))  # no default
  expect_error(create_tutorial("demo", open = FALSE), "`dir` must be a single directory path")
  expect_error(create_tutorial("demo", dir = c("a", "b"), open = FALSE), "`dir` must be")
  expect_error(create_tutorial("demo", dir = "", open = FALSE), "`dir` must be")
  expect_error(create_tutorial("demo", dir = NA_character_, open = FALSE), "`dir` must be")
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

test_that("open_file() uses utils::file.edit() in RStudio and in Positron", {
  f <- withr::local_tempfile(fileext = ".qmd")
  file.create(f)
  edited <- NULL
  local_mocked_bindings(
    file.edit = function(...) {
      edited <<- c(...)
      invisible()
    },
    .package = "utils"
  )
  local_mocked_bindings(open_in_vscode = function(path) stop("must not open VS Code"))

  withr::with_envvar(c(RSTUDIO = "1", POSITRON = "", TERM_PROGRAM = "vscode"), {
    res <- withVisible(learnr2:::open_file(f))
  })
  expect_equal(edited, f)
  expect_false(res$visible)
  expect_equal(res$value, f)

  edited <- NULL
  withr::with_envvar(c(RSTUDIO = "", POSITRON = "1"), learnr2:::open_file(f))
  expect_equal(edited, f)
})

test_that("open_file() opens the file with VS Code's `code` command in a VS Code terminal", {
  f <- withr::local_tempfile(fileext = ".qmd")
  file.create(f)
  opened <- NULL
  local_mocked_bindings(open_in_vscode = function(path) opened <<- path)
  local_mocked_bindings(has_code_command = function() TRUE)
  withr::with_envvar(c(RSTUDIO = "", POSITRON = "", TERM_PROGRAM = "vscode"), learnr2:::open_file(f))
  expect_equal(opened, f)
})

test_that("has_code_command() reports whether `code` is on the PATH", {
  expect_type(learnr2:::has_code_command(), "logical")
  withr::with_envvar(c(PATH = ""), expect_false(learnr2:::has_code_command()))
})

test_that("open_file() only prints the path anywhere else, rather than guess at an app", {
  f <- withr::local_tempfile(fileext = ".qmd")
  file.create(f)
  local_mocked_bindings(
    file.edit = function(...) stop("must not start an editor"),
    browseURL = function(...) stop("must not hand the file to the OS"),
    .package = "utils"
  )
  local_mocked_bindings(open_in_vscode = function(path) stop("must not open VS Code"))
  withr::with_envvar(c(RSTUDIO = "", POSITRON = "", TERM_PROGRAM = ""), {
    expect_message(res <- learnr2:::open_file(f), "Open it in your editor: ")
  })
  expect_equal(res, f)
})
