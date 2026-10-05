# Covers R/tutorials.R: available_tutorials() and its internal helpers
# (tutorials_in_package, tutorial_doc, tutorial_format, tutorial_title), plus
# run_tutorial(). The heavy render + serve steps of run_tutorial() are mocked
# -- exercising Quarto/WebR for real belongs in tests/js/deployed-smoke.spec.js.

# ---- available_tutorials() ------------------------------------------------

test_that("available_tutorials(package = 'learnr2') lists the bundled tutorials", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_s3_class(tutorials, "data.frame")
  expect_true(all(
    c("package", "name", "title", "format", "path", "package_dependencies") %in% names(tutorials)
  ))
  expect_true("hello-learnr2" %in% tutorials$name)
  expect_true(all(tutorials$package == "learnr2"))
  # `path` is the installed document itself, ready for render_tutorials().
  expect_true(all(fs::file_exists(tutorials$path)))
  expect_match(tutorials$path[tutorials$name == "hello-learnr2"], "hello-learnr2\\.qmd$")
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
  expect_named(res, c("package", "name", "title", "format", "path", "package_dependencies"))
  expect_type(res$package_dependencies, "list")
})

# ---- package_dependencies ------------------------------------------------

test_that("a quarto tutorial needs no local packages: package_dependencies is character(0)", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_type(tutorials$package_dependencies, "list")
  expect_identical(
    tutorials$package_dependencies[[which(tutorials$name == "hello-learnr2")]],
    character(0)
  )
})

test_that("an rmarkdown tutorial's package_dependencies come from learnr", {
  skip_if_not_installed("learnr")
  # learnr ships its own classic .Rmd tutorials, so it doubles as the fixture
  # content package here and in the run_tutorial() tests below.
  tutorials <- available_tutorials(package = "learnr")
  expect_true(all(tutorials$format == "rmarkdown"))
  hello_deps <- tutorials$package_dependencies[[which(tutorials$name == "hello")]]
  expect_type(hello_deps, "character")
  expect_true("learnr" %in% hello_deps)
})

test_that("package_dependencies is NA for rmarkdown tutorials when learnr is absent or fails", {
  skip_if_not_installed("learnr")

  local_mocked_bindings(learnr_installed = function() FALSE)
  tutorials <- available_tutorials(package = "learnr")
  expect_true(all(vapply(tutorials$package_dependencies, identical, logical(1), NA_character_)))

  local_mocked_bindings(learnr_installed = function() TRUE)
  local_mocked_bindings(
    learnr_available_tutorials = function(package) stop("learnr could not read the package")
  )
  tutorials <- available_tutorials(package = "learnr")
  expect_true(all(vapply(tutorials$package_dependencies, identical, logical(1), NA_character_)))
})

test_that("learnr_available_tutorials() is a thin seam over learnr::available_tutorials()", {
  skip_if_not_installed("learnr")
  res <- learnr2:::learnr_available_tutorials("learnr")
  expect_true("hello" %in% res$name)
  expect_true("package_dependencies" %in% names(res))
})

test_that("tutorial_dependencies() maps quarto to character(0) and a missing doc to NA without touching learnr", {
  local_mocked_bindings(learnr_installed = function() stop("must not be called"))
  deps <- learnr2:::tutorial_dependencies("learnr2", c("a", "b"), c("quarto", NA))
  expect_identical(deps, list(character(0), NA_character_))
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

# ---- run_tutorial(): classic learnr tutorials ----------------------------

test_that("run_tutorial() hands an rmarkdown tutorial to learnr::run_tutorial()", {
  skip_if_not_installed("learnr")

  called_with <- NULL
  local_mocked_bindings(
    learnr_run_tutorial = function(name, package) {
      called_with <<- list(name = name, package = package)
      invisible(NULL)
    }
  )
  # Neither Quarto nor httpuv must be touched on this path.
  local_mocked_bindings(
    quarto_render = function(...) stop("quarto must not be called"),
    .package = "quarto"
  )
  local_mocked_bindings(
    runStaticServer = function(...) stop("httpuv must not be called"),
    .package = "httpuv"
  )

  res <- withVisible(suppressMessages(
    run_tutorial("hello", package = "learnr", open = TRUE)
  ))

  expect_identical(called_with, list(name = "hello", package = "learnr"))
  expect_false(res$visible)
  expect_match(res$value, "hello\\.Rmd$")
  expect_true(fs::file_exists(res$value))
})

test_that("run_tutorial() says what is happening before handing off to learnr", {
  skip_if_not_installed("learnr")
  local_mocked_bindings(learnr_run_tutorial = function(name, package) invisible(NULL))
  expect_message(
    run_tutorial("hello", package = "learnr", open = TRUE),
    "classic learnr tutorial"
  )
})

test_that("run_tutorial() errors with an install hint for an rmarkdown tutorial when learnr is absent", {
  skip_if_not_installed("learnr")
  local_mocked_bindings(learnr_installed = function() FALSE)
  expect_error(
    run_tutorial("hello", package = "learnr", open = TRUE),
    'install.packages\\("learnr"\\)'
  )
})

test_that("run_tutorial(open = FALSE) is an error for an rmarkdown tutorial", {
  skip_if_not_installed("learnr")
  local_mocked_bindings(
    learnr_run_tutorial = function(name, package) stop("learnr must not be called")
  )
  expect_error(
    run_tutorial("hello", package = "learnr", open = FALSE),
    "open = TRUE"
  )
})

test_that("run_tutorial() errors for a tutorial directory with no document", {
  local_mocked_bindings(
    available_tutorials = function(package = NULL, type = "all") {
      data.frame(
        package = "x", name = "empty", title = NA_character_,
        format = NA_character_, path = NA_character_,
        package_dependencies = I(list(NA_character_)),
        stringsAsFactors = FALSE
      )
    }
  )
  expect_error(run_tutorial("empty", package = "x"), "no .qmd or .Rmd document")
})
