# Stubs and fixtures shared by several test files (testthat sources every
# helper-*.R before the tests). Rendering and serving are mocked at
# learnr2's own seams -- probe_server(), open_in_browser(), block_serving() --
# plus quarto::quarto_render() and httpuv's static server, so no test boots
# WebR, opens a browser or binds the real port 7446.

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
  # A classic learnr tutorial and an empty directory alongside it: neither
  # is a learnr2 tutorial, so neither may be listed.
  classic_dir <- fs::path(root, "inst", "tutorials", "classic")
  fs::dir_create(classic_dir)
  writeLines(
    c("---", "title: \"Classic\"", "output: learnr::tutorial",
      "runtime: shiny_prerendered", "---"),
    fs::path(classic_dir, "tutorial.Rmd")
  )
  fs::dir_create(fs::path(root, "inst", "tutorials", "empty"))
  pkgload::load_all(root, quiet = TRUE)
  withr::defer(pkgload::unload(name), envir = env)
  root
}

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

# Everything serve_tutorial() does for real that a test must not: probe the
# port, start httpuv, open a browser, block. Returns an env recording calls.
local_stub_serving <- function(probe = list(state = "free", server = NULL), env = parent.frame()) {
  seen <- new.env()
  local_mocked_bindings(
    probe_server = function(port) probe,
    open_in_browser = function(url, public_url = url) { seen$url <- url; seen$public_url <- public_url; invisible() },
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

# A port nothing listens on. httpuv::randomPort() finds one by starting and
# stopping a server on it, and httpuv closes the listener asynchronously, so
# the port can still accept a connection for a moment afterwards (long
# enough to be seen on Windows). Wait until a connect actually fails.
free_port <- function() {
  port <- httpuv::randomPort()
  for (i in 1:100) {
    if (!learnr2:::port_listening(port, timeout = 1)) return(port)
    Sys.sleep(0.05)
  }
  stop("port ", port, " never became free after randomPort()")
}

# GET `url`: list(status = 200L, body) or list(status = <HTTP code>, body = "").
http_get <- function(url) {
  old <- options(timeout = 5, warn = 1)
  on.exit(options(old), add = TRUE)
  tryCatch(
    {
      con <- base::url(url, open = "rb")
      on.exit(close(con), add = TRUE)
      list(status = 200L, body = paste(readLines(con, warn = FALSE), collapse = "\n"))
    },
    warning = function(w) list(status = http_status_from(conditionMessage(w)), body = ""),
    error = function(e) list(status = http_status_from(conditionMessage(e)), body = "")
  )
}

http_status_from <- function(msg) {
  m <- regmatches(msg, regexpr("HTTP status was '([0-9]{3})", msg))
  if (length(m) == 0) stop("request failed: ", msg)
  as.integer(sub("HTTP status was '", "", m, fixed = TRUE))
}
