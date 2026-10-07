# Covers R/tutorials.R: available_tutorials() and its internal helpers
# (tutorials_in_package, tutorial_doc, tutorial_format, tutorial_title), plus
# run_tutorial(). The heavy render + serve steps of run_tutorial() are mocked
# -- exercising Quarto/WebR for real belongs in tests/js/deployed-smoke.spec.js.
# Serving is likewise mocked at learnr2's own seams (probe_server(),
# open_in_browser(), block_serving()) plus httpuv's runStaticServer().

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

# ---- packages loaded with pkgload::load_all() ----------------------------

# A content package's own tests run under devtools::test(), which loads the
# package from source with pkgload::load_all() without installing it. Base
# system.file() then knows nothing about it (or finds a stale installed
# copy), so available_tutorials() and run_tutorial() used to come up empty
# there. These build a throwaway package in a temp dir, load_all() it, and
# check both read its tutorials from the source tree.
local_dev_tutorial_package <- function(name = "fakeTutorials",
                                      env = parent.frame()) {
  skip_if_not_installed("pkgload")
  root <- withr::local_tempdir(.local_envir = env)
  tutorial_dir <- fs::path(root, "inst", "tutorials", "demo")
  fs::dir_create(tutorial_dir)
  fs::dir_create(fs::path(root, "R"))
  writeLines(
    c(paste("Package:", name), "Version: 0.0.1", "Title: Fake Tutorials",
      "Description: A throwaway package for learnr2's tests.",
      "License: MIT", "Encoding: UTF-8"),
    fs::path(root, "DESCRIPTION")
  )
  writeLines(
    c("---", "title: \"Demo Tutorial\"", "format: live-html",
      "engine: knitr", "---", "", "Hello."),
    fs::path(tutorial_dir, "demo.qmd")
  )
  pkgload::load_all(root, quiet = TRUE)
  withr::defer(pkgload::unload(name), envir = env)
  root
}

test_that("available_tutorials() sees a package loaded with pkgload::load_all()", {
  root <- local_dev_tutorial_package()

  # Not installed, so base system.file() cannot find its tutorials (base::
  # explicitly: under devtools::test() pkgload shims the bare name in this
  # test environment). This is exactly the lookup that used to come up empty.
  expect_false(nzchar(base::system.file("tutorials", package = "fakeTutorials")))

  # ... but the dev package is found, from its source inst/tutorials/.
  tutorials <- available_tutorials(package = "fakeTutorials")
  expect_equal(nrow(tutorials), 1)
  expect_equal(tutorials$package, "fakeTutorials")
  expect_equal(tutorials$name, "demo")
  expect_equal(tutorials$title, "Demo Tutorial")
  expect_equal(tutorials$format, "quarto")
  # path_real() resolves symlinks (macOS's /var -> /private/var) on both sides.
  expect_equal(
    as.character(fs::path_real(tutorials$path)),
    as.character(fs::path_real(fs::path(root, "inst", "tutorials", "demo", "demo.qmd")))
  )
  expect_equal(
    as.character(fs::path_real(learnr2:::pkg_file("tutorials", package = "fakeTutorials"))),
    as.character(fs::path_real(fs::path(root, "inst", "tutorials")))
  )
  expect_identical(learnr2:::pkg_file("no-such-dir", package = "fakeTutorials"), "")

  # The no-package scan includes it alongside installed packages.
  all_tutorials <- available_tutorials()
  expect_true("fakeTutorials" %in% all_tutorials$package)
  expect_true("learnr2" %in% all_tutorials$package)
})

test_that("a dev package is invisible again once unloaded", {
  local({
    local_dev_tutorial_package()
    expect_equal(nrow(available_tutorials(package = "fakeTutorials")), 1)
  })
  expect_error(available_tutorials(package = "fakeTutorials"), "No package found")
})

test_that("run_tutorial() renders a dev package's tutorial from its source tree", {
  root <- local_dev_tutorial_package()
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

  html <- suppressMessages(
    run_tutorial("demo", package = "fakeTutorials",
                 output_dir = out_parent, open = FALSE)
  )
  expect_true(fs::file_exists(html))
  expect_match(rendered_input, "demo\\.qmd$")
  # The copy rendered came from the source tree, not from any installed copy.
  # (The cache is laid out as <output_dir>/<package>/<name>/.)
  expect_identical(
    readLines(fs::path(out_parent, "fakeTutorials", "demo", "demo.qmd")),
    readLines(fs::path(root, "inst", "tutorials", "demo", "demo.qmd"))
  )
})

test_that("pkg_file() falls back to system.file() for installed and unknown packages", {
  # utils is installed and never pkgload-loaded, so both must agree exactly.
  # (learnr2 itself is a dev package under devtools::test(), so it is not a
  # clean installed example here.)
  expect_identical(
    learnr2:::pkg_file("DESCRIPTION", package = "utils"),
    base::system.file("DESCRIPTION", package = "utils")
  )
  expect_true(nzchar(learnr2:::pkg_file("DESCRIPTION", package = "utils")))
  expect_identical(
    learnr2:::pkg_file(package = "utils"),
    base::system.file(package = "utils")
  )
  expect_identical(learnr2:::pkg_file(package = "not-a-real-package-xyz"), "")
  expect_null(learnr2:::dev_package_path("not-a-real-package-xyz"))
  expect_null(learnr2:::dev_package_path("utils"))
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

# Stubs quarto::quarto_render so no test runs Quarto; the stub writes the
# .html that render_tutorials() expects to find and records what it was
# asked to render.
local_stub_quarto <- function(env = parent.frame()) {
  calls <- new.env()
  calls$inputs <- character(0)
  local_mocked_bindings(
    quarto_render = function(input, ...) {
      writeLines("<html><body>stub</body></html>", fs::path_ext_set(input, "html"))
      calls$inputs <- c(calls$inputs, as.character(input))
      invisible()
    },
    .package = "quarto",
    .env = env
  )
  calls
}

test_that("run_tutorial(open = FALSE) renders into <output_dir>/<package>/<name>/ with an index.html and a stamp", {
  out_parent <- withr::local_tempdir()
  calls <- local_stub_quarto()

  res <- withVisible(suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2",
                 output_dir = out_parent, open = FALSE)
  ))

  expect_false(res$visible)
  work_dir <- fs::path(out_parent, "learnr2", "hello-learnr2")
  expect_equal(
    as.character(fs::path_abs(res$value)),
    as.character(fs::path_abs(fs::path(work_dir, "hello-learnr2.html")))
  )
  expect_true(fs::file_exists(res$value))
  expect_true(fs::file_exists(fs::path(work_dir, "hello-learnr2.qmd")))
  expect_true(fs::dir_exists(fs::path(work_dir, "_extensions", "r-wasm")))
  expect_match(calls$inputs, "hello-learnr2\\.qmd$")
  # The tutorial's address is its directory, so index.html must be there.
  expect_true(fs::file_exists(fs::path(work_dir, "index.html")))

  stamp <- jsonlite::fromJSON(fs::path(work_dir, "learnr2-tutorial.json"))
  expect_identical(stamp$package, "learnr2")
  expect_identical(stamp$name, "hello-learnr2")
  expect_identical(stamp$learnr2_version, as.character(packageVersion("learnr2")))
  expect_identical(stamp$html, "hello-learnr2.html")
  expect_type(stamp$fingerprint, "character")
})

test_that("run_tutorial() reuses a current render instead of rendering again", {
  out_parent <- withr::local_tempdir()
  calls <- local_stub_quarto()

  suppressMessages(run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = FALSE))
  expect_length(calls$inputs, 1)

  expect_message(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = FALSE),
    "as rendered"
  )
  expect_length(calls$inputs, 1)
})

test_that("run_tutorial(refresh = TRUE) re-renders from a clean directory", {
  out_parent <- withr::local_tempdir()
  calls <- local_stub_quarto()
  work_dir <- fs::path(out_parent, "learnr2", "hello-learnr2")

  suppressMessages(run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = FALSE))
  # Something an older version of the tutorial might have left behind.
  fs::file_create(fs::path(work_dir, "stale-from-last-version.png"))

  suppressMessages(run_tutorial("hello-learnr2", package = "learnr2",
                                output_dir = out_parent, open = FALSE, refresh = TRUE))
  expect_length(calls$inputs, 2)
  expect_false(fs::file_exists(fs::path(work_dir, "stale-from-last-version.png")))
  expect_true(fs::file_exists(fs::path(work_dir, "index.html")))
})

test_that("a render by another learnr2 version, or of other tutorial files, is not current", {
  out_parent <- withr::local_tempdir()
  calls <- local_stub_quarto()
  stamp_path <- fs::path(out_parent, "learnr2", "hello-learnr2", "learnr2-tutorial.json")
  run <- function() suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = FALSE)
  )

  run()
  stamp <- jsonlite::fromJSON(stamp_path)

  stamp$learnr2_version <- "0.0.0"
  jsonlite::write_json(stamp, stamp_path, auto_unbox = TRUE)
  run()
  expect_length(calls$inputs, 2)

  stamp <- jsonlite::fromJSON(stamp_path)
  stamp$fingerprint <- "not-these-files"
  jsonlite::write_json(stamp, stamp_path, auto_unbox = TRUE)
  run()
  expect_length(calls$inputs, 3)

  # An unreadable stamp also means render again.
  writeLines("{ not json", stamp_path)
  run()
  expect_length(calls$inputs, 4)
})

test_that("tutorial_fingerprint() changes when any file in the tutorial directory changes", {
  d <- withr::local_tempdir()
  writeLines("---\ntitle: A\n---", fs::path(d, "a.qmd"))
  fs::dir_create(fs::path(d, "images"))
  writeLines("png", fs::path(d, "images", "x.png"))
  f1 <- learnr2:::tutorial_fingerprint(d)
  expect_identical(learnr2:::tutorial_fingerprint(d), f1)

  writeLines("png2", fs::path(d, "images", "x.png"))
  f2 <- learnr2:::tutorial_fingerprint(d)
  expect_false(identical(f1, f2))

  writeLines("more", fs::path(d, "_extra.qmd"))
  expect_false(identical(learnr2:::tutorial_fingerprint(d), f2))
})

test_that("render_is_current() needs a stamp from this learnr2 for these files", {
  v <- as.character(packageVersion("learnr2"))
  expect_false(learnr2:::render_is_current(NULL, "abc"))
  expect_true(learnr2:::render_is_current(list(learnr2_version = v, fingerprint = "abc"), "abc"))
  expect_false(learnr2:::render_is_current(list(learnr2_version = v, fingerprint = "abd"), "abc"))
  expect_false(learnr2:::render_is_current(list(learnr2_version = "0.0.0", fingerprint = "abc"), "abc"))
})

# ---- prerender_tutorials() --------------------------------------------

test_that("prerender_tutorials(package = 'learnr2') renders every Quarto tutorial once", {
  out_parent <- withr::local_tempdir()
  calls <- local_stub_quarto()
  quarto_tutorials <- available_tutorials(package = "learnr2", type = "quarto")

  res <- withVisible(suppressMessages(
    prerender_tutorials(package = "learnr2", output_dir = out_parent)
  ))
  expect_false(res$visible)
  out <- res$value
  expect_s3_class(out, "data.frame")
  expect_named(out, c("package", "name", "html", "rendered"))
  expect_setequal(out$name, quarto_tutorials$name)
  expect_true(all(out$rendered))
  expect_true(all(fs::file_exists(out$html)))
  expect_length(calls$inputs, nrow(quarto_tutorials))

  expect_message(
    again <- prerender_tutorials(package = "learnr2", output_dir = out_parent),
    "0 tutorial\\(s\\) rendered"
  )
  expect_false(any(again$rendered))
  expect_length(calls$inputs, nrow(quarto_tutorials))
})

test_that("prerender_tutorials() returns a typed zero-row frame when there is nothing to render", {
  local_stub_quarto()
  res <- suppressMessages(prerender_tutorials(package = "utils", output_dir = withr::local_tempdir()))
  expect_identical(nrow(res), 0L)
  expect_named(res, c("package", "name", "html", "rendered"))
})

# ---- serving ------------------------------------------------------------

# Everything serve_tutorial() does for real that a test must not: probe the
# port, start httpuv, open a browser, block. Returns an env recording calls.
local_stub_serving <- function(probe = list(state = "free", server = NULL), env = parent.frame()) {
  seen <- new.env()
  local_mocked_bindings(
    probe_server = function(port) probe,
    open_in_browser = function(url) { seen$url <- url; invisible() },
    block_serving = function() { seen$marker_while_serving <- seen$marker_path_exists(); invisible() },
    .env = env
  )
  local_mocked_bindings(
    runStaticServer = function(dir, host = "127.0.0.1", port = NULL, ..., background = FALSE, browse = TRUE) {
      seen$dir <- dir; seen$port <- port; seen$background <- background; seen$browse <- browse
      structure(list(), class = "stub-server")
    },
    stopServer = function(server) { seen$stopped <- TRUE; invisible() },
    .package = "httpuv",
    .env = env
  )
  seen
}

test_that("run_tutorial(open = TRUE) serves the cache root on the fixed port and opens the tutorial's own address", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  seen <- local_stub_serving()
  marker <- fs::path(out_parent, "learnr2-server.json")
  seen$marker_path_exists <- function() fs::file_exists(marker)

  suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE)
  )

  expect_equal(as.character(fs::path_abs(seen$dir)), as.character(fs::path_abs(out_parent)))
  expect_identical(seen$port, 7446L)
  expect_true(seen$background)
  expect_false(seen$browse)
  expect_identical(seen$url, "http://127.0.0.1:7446/learnr2/hello-learnr2/")
  # The marker that lets a later run_tutorial() recognise this server exists
  # while serving and is cleaned up afterwards.
  expect_true(seen$marker_while_serving)
  expect_false(fs::file_exists(marker))
  expect_true(seen$stopped)
})

test_that("the learnr2.port option changes the port and the address", {
  withr::local_options(learnr2.port = 8123)
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  seen <- local_stub_serving()
  seen$marker_path_exists <- function() TRUE

  suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE)
  )
  expect_identical(seen$port, 8123L)
  expect_identical(seen$url, "http://127.0.0.1:8123/learnr2/hello-learnr2/")
})

test_that("with a learnr2 server already serving the cache root, run_tutorial() just opens the address", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  seen <- local_stub_serving(probe = list(
    state = "learnr2",
    server = list(root = as.character(fs::path_abs(out_parent)), port = 7446)
  ))

  expect_message(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE),
    "already running"
  )
  expect_identical(seen$url, "http://127.0.0.1:7446/learnr2/hello-learnr2/")
  expect_null(seen$dir)  # no second server
})

test_that("a learnr2 server serving a different root, or a foreign process on the port, is an error", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()

  local_stub_serving(probe = list(state = "learnr2", server = list(root = "/somewhere/else")))
  expect_error(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE),
    "serving /somewhere/else"
  )

  local_stub_serving(probe = list(state = "other", server = NULL))
  expect_error(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE),
    "something other than a learnr2"
  )
})

test_that("classify_probe_failure() tells nothing-listening from something-else-listening", {
  # The messages base::url() produces, observed with libcurl.
  expect_identical(
    learnr2:::classify_probe_failure("URL 'http://127.0.0.1:7446/learnr2-server.json': status was 'Couldn't connect to server'")$state,
    "free"
  )
  expect_identical(learnr2:::classify_probe_failure("Connection refused")$state, "free")
  expect_identical(
    learnr2:::classify_probe_failure("cannot open URL 'http://127.0.0.1:7446/learnr2-server.json': HTTP status was '404 Not Found'")$state,
    "other"
  )
  expect_identical(learnr2:::classify_probe_failure("Timeout was reached")$state, "other")
  expect_identical(learnr2:::classify_probe_failure("lexical error: invalid char in json text")$state, "other")
})

test_that("probe_server() reports a port nothing listens on as free", {
  port <- httpuv::randomPort()
  expect_identical(learnr2:::probe_server(port), list(state = "free", server = NULL))
})

test_that("tutorial_url() and learnr2_port() agree on the default port", {
  expect_identical(learnr2:::learnr2_port(), 7446L)
  expect_identical(learnr2:::tutorial_url("ims.tutorials", "01-hello-data"), "http://127.0.0.1:7446/ims.tutorials/01-hello-data/")
})

test_that("the server marker is written at the cache root and removable", {
  root <- withr::local_tempdir()
  learnr2:::write_server_marker(as.character(root), 7446L)
  marker <- jsonlite::fromJSON(fs::path(root, "learnr2-server.json"))
  expect_identical(marker$root, as.character(root))
  expect_identical(marker$port, 7446L)
  learnr2:::remove_server_marker(as.character(root))
  expect_false(fs::file_exists(fs::path(root, "learnr2-server.json")))
  # Removing an absent marker is not an error.
  expect_no_error(learnr2:::remove_server_marker(as.character(root)))
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
