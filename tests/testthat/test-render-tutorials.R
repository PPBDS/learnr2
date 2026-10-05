# Covers R/render_tutorials.R: render_tutorials(), resolve_tutorial_paths().
# Quarto is mocked everywhere except the one real-render test at the bottom,
# which is what actually proves the bundled tutorials build.

test_that("resolve_tutorial_paths() accepts .qmd files and tutorial directories, and rejects the rest", {
  d <- withr::local_tempdir()
  qmd <- fs::path(d, "lesson.qmd")
  writeLines("---\ntitle: x\n---", qmd)

  expect_identical(learnr2:::resolve_tutorial_paths(qmd), as.character(fs::path_abs(qmd)))
  expect_identical(learnr2:::resolve_tutorial_paths(d), as.character(fs::path_abs(qmd)))
  expect_identical(learnr2:::resolve_tutorial_paths(character(0)), character(0))

  expect_error(learnr2:::resolve_tutorial_paths(fs::path(d, "nope.qmd")), "not found")
  expect_error(learnr2:::resolve_tutorial_paths(withr::local_tempdir()), "No .qmd tutorial found")
  rmd <- fs::path(d, "old.Rmd"); fs::file_create(rmd)
  expect_error(learnr2:::resolve_tutorial_paths(rmd), "Not a .qmd tutorial")
  expect_error(learnr2:::resolve_tutorial_paths(NA_character_), "character vector")
  expect_error(learnr2:::resolve_tutorial_paths(1), "character vector")
})

test_that("render_tutorials() copies each tutorial, adds the extension, renders, and returns named html paths", {
  src_parent <- withr::local_tempdir()
  qmd <- create_tutorial("demo", dir = src_parent, open = FALSE)
  fs::dir_create(fs::path(fs::path_dir(qmd), "images"))
  fs::file_create(fs::path(fs::path_dir(qmd), "images", "pic.png"))
  out <- withr::local_tempdir()

  inputs <- character(0)
  local_mocked_bindings(
    quarto_render = function(input, quiet = TRUE, ...) {
      inputs <<- c(inputs, input)
      writeLines("<html></html>", fs::path_ext_set(input, "html"))
      invisible()
    },
    .package = "quarto"
  )

  res <- withVisible(suppressMessages(render_tutorials(qmd, output_dir = out)))
  expect_false(res$visible)
  expect_named(res$value, "demo")
  expect_true(fs::file_exists(res$value[["demo"]]))
  expect_match(res$value[["demo"]], "demo/demo\\.html$")

  # Rendered from the copy under output_dir, never from the source.
  expect_match(inputs, "^.*/demo/demo\\.qmd$")
  expect_true(startsWith(inputs, as.character(fs::path_abs(out))))
  expect_false(fs::file_exists(fs::path_ext_set(qmd, "html")))
  # The whole tutorial directory travels, plus the extension.
  expect_true(fs::file_exists(fs::path(out, "demo", "images", "pic.png")))
  expect_true(fs::dir_exists(fs::path(out, "demo", "_extensions", "r-wasm", "live")))
})

test_that("render_tutorials() takes directories too, renders several, and reports timing", {
  src_parent <- withr::local_tempdir()
  a <- create_tutorial("a", dir = src_parent, open = FALSE)
  b <- create_tutorial("b", dir = src_parent, open = FALSE)
  local_mocked_bindings(
    quarto_render = function(input, ...) {
      writeLines("<html></html>", fs::path_ext_set(input, "html")); invisible()
    },
    .package = "quarto"
  )
  expect_message(
    expect_message(
      res <- render_tutorials(c(fs::path_dir(a), b), output_dir = withr::local_tempdir()),
      "Rendered a in [0-9.]+s"
    ),
    "Rendered 2 tutorial\\(s\\)"
  )
  expect_named(res, c("a", "b"))
})

test_that("render_tutorials() errors naming the tutorial when Quarto fails or produces no html", {
  src_parent <- withr::local_tempdir()
  qmd <- create_tutorial("broken", dir = src_parent, open = FALSE)

  local_mocked_bindings(
    quarto_render = function(input, ...) stop("boom from quarto"),
    .package = "quarto"
  )
  expect_error(
    suppressMessages(render_tutorials(qmd, output_dir = withr::local_tempdir())),
    "Failed to render .*broken\\.qmd: boom from quarto"
  )

  local_mocked_bindings(quarto_render = function(input, ...) invisible(), .package = "quarto")
  expect_error(
    suppressMessages(render_tutorials(qmd, output_dir = withr::local_tempdir())),
    "produced no broken\\.html"
  )
})

test_that("render_tutorials() with no paths renders nothing and returns an empty vector", {
  expect_message(res <- render_tutorials(character(0)), "Rendered 0 tutorial\\(s\\)")
  expect_identical(res, character(0))
})

# ---- the real thing ----------------------------------------------------
# Every bundled tutorial must actually build with Quarto. Skipped on CRAN
# (slow, and Quarto isn't there) and wherever Quarto isn't installed; runs
# in this package's own CI, where R-CMD-check.yaml sets Quarto up. Nothing
# else in the suite renders for real, so this is the only test that would
# catch a bundled tutorial that is syntactically plausible but won't render.
test_that("every bundled tutorial passes check_tutorial() and renders with Quarto", {
  skip_on_cran()
  skip_if(is.null(quarto::quarto_path()), "Quarto is not installed")

  tutorials <- available_tutorials(package = "learnr2")
  expect_gt(nrow(tutorials), 0)

  for (i in seq_len(nrow(tutorials))) {
    # hello-learnr2 is a feature tour: it deliberately shows the R source of
    # its widget chunks, and has no "minutes" question.
    skip <- if (tutorials$name[i] == "hello-learnr2") c("echo", "minutes") else NULL
    expect_no_error(check_tutorial(tutorials$path[i], skip = skip))
  }

  html <- suppressMessages(render_tutorials(tutorials$path, output_dir = withr::local_tempdir()))
  expect_named(html, tutorials$name)
  expect_true(all(fs::file_exists(html)))
  for (h in html) {
    page <- paste(readLines(h, warn = FALSE), collapse = "\n")
    # The quarto-live runtime and learnr2's own widget script both made it in.
    expect_match(page, "live-runtime", fixed = TRUE)
    expect_match(page, "quiz.js", fixed = TRUE)
  }
})
