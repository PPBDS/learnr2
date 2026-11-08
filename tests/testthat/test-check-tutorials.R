# Covers R/check_tutorials.R: check_tutorials() and check_download_header().

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

# A fake source package with one well-formed tutorial, as a pkgload checkout
# would look: <pkg>/inst/tutorials/<name>/<name>.qmd plus a DESCRIPTION.
local_fake_package <- function(tutorial_lines, name = "demo", version = "1.2.3",
                               env = parent.frame()) {
  root <- fs::path(withr::local_tempdir(.local_envir = env), "fake.tutorials")
  dir <- fs::path(root, "inst", "tutorials", name)
  fs::dir_create(dir)
  writeLines(c("Package: fake.tutorials", paste("Version:", version)), fs::path(root, "DESCRIPTION"))
  qmd <- fs::path(dir, paste0(name, ".qmd"))
  writeLines(tutorial_lines, qmd)
  rows <- data.frame(package = "fake.tutorials", name = name, title = "Demo",
                     format = "quarto", path = as.character(qmd), ordering = NA_real_,
                     stringsAsFactors = FALSE)
  local_mocked_bindings(available_tutorials = function(package = NULL, type = "all") rows, .env = env)
  rows
}

# Stand in for Quarto: write an html carrying a download button whose
# payload `header` says, as the real render would, what the page is.
local_stub_render <- function(header = NULL, fail = FALSE, env = parent.frame()) {
  local_mocked_bindings(
    quarto_render = function(input, ...) {
      if (fail) stop("quarto exploded")
      payload <- c(list(filenamePrefix = "demo", label = NULL), header)
      json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
      div <- paste0('<div class="learnr2-download-answers" data-learnr2-download="',
                    jsonlite::base64_enc(charToRaw(as.character(json))), '"></div>')
      writeLines(c("<html><body>", div, "</body></html>"), fs::path_ext_set(input, "html"))
      invisible()
    },
    .package = "quarto", .env = env
  )
}

# The create_tutorial() template, read from the installed (or load_all())
# package: under R CMD check the tests run from the installed copy, where
# there is no inst/ directory to reach by relative path.
good <- readLines(system.file("templates", "tutorial.qmd", package = "learnr2"))
good <- sub("{{title}}", "Demo", good, fixed = TRUE)

test_that("check_tutorials() passes a well-formed package whose render names it correctly", {
  rows <- local_fake_package(good)
  local_stub_render(header = list(package = "fake.tutorials", version = "1.2.3", tutorial = "demo"))
  res <- withVisible(suppressMessages(check_tutorials("fake.tutorials", output_dir = withr::local_tempdir())))
  expect_false(res$visible)
  expect_named(res$value, c("path", "check", "severity", "message"))
  expect_identical(nrow(res$value), 0L)
})

test_that("check_tutorials() reports static problems, render failures and a wrong download header", {
  broken <- good[!grepl("^#\\| echo: false", good)]
  rows <- local_fake_package(broken)
  local_stub_render(header = list(package = "other", version = "9.9", tutorial = "demo"))
  res <- suppressMessages(check_tutorials("fake.tutorials", output_dir = withr::local_tempdir(), error = FALSE))
  expect_true("echo" %in% res$check)
  sub <- res[res$check == "submission", ]
  expect_identical(nrow(sub), 2L)
  expect_match(sub$message[1], "`package` is `other`, expected `fake.tutorials`")
  expect_match(sub$message[2], "`version` is `9.9`, expected `1.2.3`")
  expect_true(all(res$severity[res$check %in% c("echo", "submission")] == "error"))
  expect_error(suppressMessages(check_tutorials("fake.tutorials", output_dir = withr::local_tempdir())),
               "problem\\(s\\) found")

  local_stub_render(fail = TRUE)
  res <- suppressMessages(check_tutorials("fake.tutorials", output_dir = withr::local_tempdir(), error = FALSE))
  expect_true("render" %in% res$check)
  expect_match(res$message[res$check == "render"], "quarto exploded")
})

test_that("check_tutorials() can skip rendering, or just the submission check", {
  rows <- local_fake_package(good)
  local_mocked_bindings(quarto_render = function(...) stop("should not render"), .package = "quarto")
  expect_identical(nrow(check_tutorials("fake.tutorials", render = FALSE)), 0L)
  expect_identical(nrow(check_tutorials("fake.tutorials", skip = "render")), 0L)
  local_stub_render(header = list(package = "wrong", version = "1.2.3", tutorial = "demo"))
  expect_identical(nrow(suppressMessages(check_tutorials("fake.tutorials", skip = "submission",
                                                          output_dir = withr::local_tempdir()))), 0L)
})

test_that("check_tutorials() errors when the package has no tutorials", {
  local_mocked_bindings(available_tutorials = function(package = NULL, type = "all") {
    data.frame(package = character(0), name = character(0), path = character(0))
  })
  expect_error(check_tutorials("empty.pkg"), "No learnr2 tutorials found in package `empty.pkg`")
})

test_that("decode_payload() copes with htmltools' entity-escaped line wrapping", {
  json <- paste0('{"id":"x","long":"', strrep("a", 120), '"}')
  wrapped <- gsub("\n", "&#10;", jsonlite::base64_enc(charToRaw(json)))
  expect_true(grepl("&#10;", wrapped, fixed = TRUE))
  expect_equal(learnr2:::decode_payload(wrapped)$id, "x")
  expect_null(learnr2:::decode_payload("!!!"))
})

test_that("check_download_header() explains a missing button or an undecodable payload", {
  html <- withr::local_tempfile(fileext = ".html")
  tut <- data.frame(package = "p", name = "n", path = "/nowhere/n/n.qmd", stringsAsFactors = FALSE)
  writeLines("<html></html>", html)
  expect_match(learnr2:::check_download_header(html, tut), "no download button")
  writeLines('<div data-learnr2-download="!!!not base64!!!"></div>', html)
  expect_match(learnr2:::check_download_header(html, tut), "could not be decoded")
})
