# Covers R/tutorials.R: available_tutorials() and its internal helpers
# (tutorials_in_package, tutorial_doc, tutorial_format, tutorial_title), plus
# run_tutorial(). The heavy render + serve steps of run_tutorial() are mocked
# -- exercising Quarto/WebR for real belongs in tests/js/deployed-smoke.spec.js.

# ---- available_tutorials() ------------------------------------------------

test_that("available_tutorials(package = 'learnr2') lists the bundled tutorials", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_s3_class(tutorials, "data.frame")
  expect_true(all(c("package", "name", "title", "format") %in% names(tutorials)))
  expect_true("hello-learnr2" %in% tutorials$name)
  expect_true(all(tutorials$package == "learnr2"))
})

test_that("available_tutorials() with no package scans every installed package", {
  tutorials <- available_tutorials()
  expect_true("hello-learnr2" %in% tutorials$name[tutorials$package == "learnr2"])
})

test_that("available_tutorials() errors on an unknown or malformed package", {
  expect_error(available_tutorials(package = ""), "single non-empty string")
  expect_error(available_tutorials(package = c("a", "b")), "single non-empty string")
  expect_error(available_tutorials(package = 1), "single non-empty string")
  expect_error(available_tutorials(package = "not-a-real-package-xyz"), "No package found")
})

test_that("available_tutorials() validates type", {
  expect_error(available_tutorials(type = "learnr"), '"all", "rmarkdown", or "quarto"')
  expect_error(available_tutorials(type = c("all", "quarto")), '"all", "rmarkdown", or "quarto"')
})

test_that("available_tutorials() reports format and filters by type", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_identical(
    tutorials$format[tutorials$name == "hello-learnr2"],
    "quarto"
  )

  quarto_only <- available_tutorials(package = "learnr2", type = "quarto")
  expect_true("hello-learnr2" %in% quarto_only$name)
  expect_true(all(quarto_only$format == "quarto"))

  rmarkdown_only <- available_tutorials(package = "learnr2", type = "rmarkdown")
  expect_false("hello-learnr2" %in% rmarkdown_only$name)
  expect_true(all(rmarkdown_only$format == "rmarkdown"))
})

test_that("available_tutorials() returns a typed zero-row frame for a package with no tutorials", {
  # 'utils' is installed but ships no inst/tutorials/.
  res <- available_tutorials(package = "utils")
  expect_s3_class(res, "data.frame")
  expect_identical(nrow(res), 0L)
  expect_named(res, c("package", "name", "title", "format"))
})

# ---- internal helpers ---------------------------------------------------

test_that("tutorials_in_package() returns NULL for a package with no tutorials/ dir", {
  expect_null(learnr2:::tutorials_in_package("utils"))
})

test_that("tutorial_doc() prefers .qmd, falls back to .Rmd, else NA", {
  d <- withr::local_tempdir()
  expect_true(is.na(learnr2:::tutorial_doc(d)))

  fs::file_create(fs::path(d, "lesson.Rmd"))
  expect_match(learnr2:::tutorial_doc(d), "lesson\\.Rmd$")

  fs::file_create(fs::path(d, "lesson.qmd"))
  expect_match(learnr2:::tutorial_doc(d), "lesson\\.qmd$")
})

test_that("tutorial_format() maps a doc's extension to a label, and passes NA through", {
  expect_identical(learnr2:::tutorial_format("x.qmd"), "quarto")
  expect_identical(learnr2:::tutorial_format("x.Rmd"), "rmarkdown")
  expect_true(is.na(learnr2:::tutorial_format(NA_character_)))
})

test_that("tutorial_title() reads the YAML title, or NA when absent/unparseable", {
  expect_true(is.na(learnr2:::tutorial_title(NA_character_)))

  no_title <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "format: html", "---", "", "# Body"), no_title)
  expect_true(is.na(learnr2:::tutorial_title(no_title)))

  titled <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "title: Hello There", "---", "", "# Body"), titled)
  expect_identical(learnr2:::tutorial_title(titled), "Hello There")

  # Malformed YAML front matter -> tryCatch swallows the error -> NA.
  bad <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "title: a: b", "---"), bad)
  expect_true(is.na(learnr2:::tutorial_title(bad)))
})

# ---- hello-learnr2 bundled content ------------------------------------

test_that("the hello-learnr2 tutorial is bundled and demonstrates quiz questions", {
  qmd <- system.file(
    "tutorials", "hello-learnr2", "hello-learnr2.qmd",
    package = "learnr2"
  )
  expect_true(nzchar(qmd))
  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "learnr2::question\\(")
  expect_match(contents, "learnr2::quiz\\(")
})

# ---- run_tutorial() ---------------------------------------------------

test_that("run_tutorial() defaults to a persistent output_dir, not the session tempdir()", {
  # R deletes its own session tempdir() on exit; a browser opened via
  # open = TRUE in a non-interactive session (e.g. Rscript) can lose the race
  # and find the file already gone. The default output_dir must not live
  # under tempdir().
  default_output_dir <- eval(formals(run_tutorial)$output_dir)
  expect_false(startsWith(default_output_dir, tempdir()))
})

test_that("run_tutorial(name = NULL) lists the available tutorials and returns NULL invisibly", {
  expect_message(run_tutorial(package = "learnr2"), "Available tutorials")
  expect_message(run_tutorial(package = "learnr2"), "hello-learnr2")

  res <- withVisible(suppressMessages(run_tutorial(package = "learnr2")))
  expect_null(res$value)
  expect_false(res$visible)
})

test_that("run_tutorial() errors on an unknown tutorial name", {
  expect_error(
    run_tutorial("no-such-tutorial", package = "learnr2"),
    "Unknown tutorial"
  )
})

test_that("run_tutorial(open = FALSE) copies the tutorial, adds the extension, renders, and returns the html path invisibly", {
  out_parent <- withr::local_tempdir()

  rendered_input <- NULL
  local_mocked_bindings(
    quarto_render = function(input, ...) {
      writeLines("<html><body>stub</body></html>", fs::path_ext_set(input, "html"))
      rendered_input <<- input
      invisible()
    },
    .package = "quarto"
  )

  res <- withVisible(suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2",
                 output_dir = out_parent, open = FALSE)
  ))

  expect_false(res$visible)
  expect_true(fs::file_exists(res$value))
  expect_match(res$value, "hello-learnr2\\.html$")

  work_dir <- fs::path(out_parent, "hello-learnr2")
  expect_true(fs::file_exists(fs::path(work_dir, "hello-learnr2.qmd")))
  expect_true(fs::dir_exists(fs::path(work_dir, "_extensions", "r-wasm")))
  expect_match(rendered_input, "hello-learnr2\\.qmd$")
})

test_that("run_tutorial(open = TRUE) serves the rendered work dir over a static server", {
  out_parent <- withr::local_tempdir()

  local_mocked_bindings(
    quarto_render = function(input, ...) {
      writeLines("<html></html>", fs::path_ext_set(input, "html"))
      invisible()
    },
    .package = "quarto"
  )
  served_dir <- NULL
  served_browse <- NULL
  local_mocked_bindings(
    runStaticServer = function(dir, browse = TRUE, ...) {
      served_dir <<- dir
      served_browse <<- browse
      invisible()
    },
    .package = "httpuv"
  )

  suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2",
                 output_dir = out_parent, open = TRUE)
  )

  work_dir <- fs::path(out_parent, "hello-learnr2")
  expect_equal(
    as.character(fs::path_abs(served_dir)),
    as.character(fs::path_abs(work_dir))
  )
  expect_true(served_browse)
  # index.html is copied in so browse = TRUE lands on the tutorial itself,
  # not httpuv's bare directory listing.
  expect_true(fs::file_exists(fs::path(work_dir, "index.html")))
})
