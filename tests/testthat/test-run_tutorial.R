# Covers R/run_tutorial.R: run_tutorial(), prerender_tutorials(), the render
# cache (ensure_rendered(), stamps, fingerprints) and serving (serve_tutorial(),
# probe_server(), port_listening(), the root index, Codespaces addresses,
# open_in_browser()). Rendering and serving are stubbed at learnr2's own seams
# (see helper-stubs.R), except the "against a real httpuv server" tests, which
# serve a stub-rendered cache on a free loopback port for real: only a real
# server shows what the bare port answers with.

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

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

test_that("serving writes a root index.html that forwards to the launched tutorial and lists the rest", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  seen <- local_stub_serving()
  seen$marker_path_exists <- function() TRUE

  # A second, older render already in the cache from another package.
  other <- fs::path(out_parent, "other.pkg", "older")
  fs::dir_create(other)
  writeLines("<html></html>", fs::path(other, "index.html"))
  jsonlite::write_json(
    list(package = "other.pkg", name = "older", title = "An <older> one",
         learnr2_version = "0.0.0", fingerprint = "x",
         rendered_at = "2000-01-01 00:00:00 UTC", html = "older.html"),
    fs::path(other, "learnr2-tutorial.json"), auto_unbox = TRUE
  )

  suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE)
  )

  index <- fs::path(out_parent, "index.html")
  expect_true(fs::file_exists(index))
  html <- paste(readLines(index), collapse = "\n")
  expect_match(html, 'http-equiv="refresh" content="0; url=/learnr2/hello-learnr2/"', fixed = TRUE)
  expect_match(html, 'href="/learnr2/hello-learnr2/"', fixed = TRUE)
  expect_match(html, 'href="/other.pkg/older/">An &lt;older&gt; one', fixed = TRUE)
  # Newest render first.
  expect_lt(regexpr("hello-learnr2/\">", html, fixed = TRUE), regexpr("other.pkg/older", html, fixed = TRUE))
})

test_that("the root index is rewritten when a running server is reused", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  local_stub_serving(probe = list(
    state = "learnr2",
    server = list(root = as.character(fs::path_abs(out_parent)), port = 7446)
  ))
  index <- fs::path(out_parent, "index.html")
  writeLines("stale", index)

  suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE)
  )
  expect_match(paste(readLines(index), collapse = "\n"), "url=/learnr2/hello-learnr2/", fixed = TRUE)
})

test_that("rendered_tutorials() reads only <root>/<package>/<name>/ stamps and tolerates bad ones", {
  root <- withr::local_tempdir()
  good <- fs::path(root, "pkg", "one")
  fs::dir_create(good)
  jsonlite::write_json(list(package = "pkg", name = "one", rendered_at = "2026-01-01 00:00:00 UTC"),
                       fs::path(good, "learnr2-tutorial.json"), auto_unbox = TRUE)
  bad <- fs::path(root, "pkg", "broken")
  fs::dir_create(bad)
  writeLines("not json", fs::path(bad, "learnr2-tutorial.json"))
  deep <- fs::path(root, "pkg", "one", "nested")
  fs::dir_create(deep)
  jsonlite::write_json(list(package = "pkg", name = "nested"),
                       fs::path(deep, "learnr2-tutorial.json"), auto_unbox = TRUE)

  found <- learnr2:::rendered_tutorials(as.character(root))
  expect_length(found, 1)
  expect_identical(found[[1]]$name, "one")
  expect_identical(found[[1]]$title, "one")  # no title in the stamp: falls back to the name

  expect_identical(learnr2:::rendered_tutorials(as.character(withr::local_tempdir())), list())
  expect_identical(learnr2:::html_escape('a<b>&"c"'), "a&lt;b&gt;&amp;&quot;c&quot;")
})

test_that("in a GitHub Codespace the tutorial's address is the forwarded one", {
  withr::local_envvar(CODESPACE_NAME = "urban-trout-abc123",
                      GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN = "app.github.dev")
  expect_identical(
    learnr2:::public_tutorial_url("ims.tutorials", "02-study-design"),
    "https://urban-trout-abc123-7446.app.github.dev/ims.tutorials/02-study-design/"
  )
  expect_identical(learnr2:::codespace_base_url(8123), "https://urban-trout-abc123-8123.app.github.dev")

  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  seen <- local_stub_serving()
  seen$marker_path_exists <- function() TRUE
  expect_message(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE),
    "https://urban-trout-abc123-7446.app.github.dev/learnr2/hello-learnr2/",
    fixed = TRUE
  )
  # The browser is opened on the *local* address, so VS Code's BROWSER
  # helper forwards the port as part of opening it; the forwarded address
  # is what gets printed, and what a failure message would name.
  expect_identical(seen$url, "http://127.0.0.1:7446/learnr2/hello-learnr2/")
  expect_identical(seen$public_url, "https://urban-trout-abc123-7446.app.github.dev/learnr2/hello-learnr2/")
  # The server itself still binds the local port; only the address differs.
  expect_identical(seen$port, 7446L)
})

test_that("outside a codespace the address is the local one", {
  withr::local_envvar(CODESPACE_NAME = "", GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN = "")
  expect_null(learnr2:::codespace_base_url(7446))
  expect_identical(learnr2:::public_tutorial_url("learnr2", "hello-learnr2"),
                   "http://127.0.0.1:7446/learnr2/hello-learnr2/")
})

test_that("open_in_browser() prefers a BROWSER helper from the environment, else R's browser option", {
  seen <- new.env()
  local_mocked_bindings(
    browseURL = function(url, browser = getOption("browser"), ...) { seen$browser <- browser; invisible() },
    .package = "utils"
  )
  withr::local_envvar(BROWSER = "/vscode/helpers/browser.sh")
  learnr2:::open_in_browser("http://127.0.0.1:7446/")
  expect_identical(seen$browser, "/vscode/helpers/browser.sh")

  withr::local_envvar(BROWSER = "")
  withr::local_options(browser = "my-browser")
  learnr2:::open_in_browser("http://127.0.0.1:7446/")
  expect_identical(seen$browser, "my-browser")
})

test_that("open_in_browser() reports, rather than fails, when no browser can be opened", {
  local_mocked_bindings(browseURL = function(...) stop("no display"), .package = "utils")
  expect_message(learnr2:::open_in_browser("http://127.0.0.1:7446/x/"), "open http://127.0.0.1:7446/x/ yourself")
  # ... naming the address a person can actually reach, when that differs.
  expect_message(
    learnr2:::open_in_browser("http://127.0.0.1:7446/x/", "https://cs-7446.app.github.dev/x/"),
    "open https://cs-7446.app.github.dev/x/ yourself"
  )
})

# ---- the served root, against a real httpuv server -----------------------
#
# The tests above stub httpuv, so they can only show that files were written,
# not what a browser gets. The regression they would miss is the one that was
# reported from GitHub Codespaces: the port notification's "Open in Browser"
# opens the bare root of the port, and that root answered 404 because the
# cache root had no page of its own. These tests serve a (stub-rendered)
# cache with httpuv for real, on a random free port, and fetch it.


test_that("a cache root with no index page is what used to 404 (documents the mistake)", {
  root <- withr::local_tempdir()
  fs::dir_create(fs::path(root, "learnr2", "hello-learnr2"))
  writeLines("<p>tutorial</p>", fs::path(root, "learnr2", "hello-learnr2", "index.html"))
  port <- free_port()
  server <- httpuv::runStaticServer(as.character(root), port = port, browse = FALSE, background = TRUE)
  withr::defer(httpuv::stopServer(server))

  expect_identical(http_get(sprintf("http://127.0.0.1:%d/", port))$status, 404L)
  expect_identical(http_get(sprintf("http://127.0.0.1:%d/learnr2/hello-learnr2/", port))$status, 200L)
})

test_that("run_tutorial(open = TRUE) serves a root that forwards to the tutorial, for real", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  port <- free_port()
  withr::local_options(learnr2.port = port)
  base <- sprintf("http://127.0.0.1:%d", port)

  # Real httpuv, real probe; only the browser and the blocking loop are
  # stubbed. The blocking stub is where the server is live, so it is where
  # the fetches happen.
  seen <- new.env()
  local_mocked_bindings(
    open_in_browser = function(url, public_url = url) { seen$url <- url; seen$public_url <- public_url; invisible() },
    block_serving = function() {
      seen$root <- http_get(paste0(base, "/"))
      seen$tutorial <- http_get(paste0(base, "/learnr2/hello-learnr2/"))
      seen$probe <- learnr2:::probe_server(port)
      invisible()
    }
  )

  suppressMessages(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE)
  )

  # The bare port -- what a port-forwarding notification opens -- must not 404.
  expect_identical(seen$root$status, 200L)
  expect_match(seen$root$body, 'content="0; url=/learnr2/hello-learnr2/"', fixed = TRUE)
  expect_match(seen$root$body, 'href="/learnr2/hello-learnr2/"', fixed = TRUE)
  # The forward target is the rendered tutorial.
  expect_identical(seen$tutorial$status, 200L)
  expect_match(seen$tutorial$body, "stub")
  # And the live server is recognisable as a learnr2 server serving this root.
  expect_identical(seen$probe$state, "learnr2")
  expect_identical(as.character(fs::path_abs(seen$probe$server$root)), as.character(fs::path_abs(out_parent)))
  expect_identical(seen$url, sprintf("%s/learnr2/hello-learnr2/", base))

  # Stopped and cleaned up on return.
  expect_identical(learnr2:::probe_server(port)$state, "free")
  expect_false(fs::file_exists(fs::path(out_parent, "learnr2-server.json")))
})

test_that("a second run_tutorial() against a live server reuses it and refreshes the root forward, for real", {
  out_parent <- withr::local_tempdir()
  local_stub_quarto()
  port <- free_port()
  withr::local_options(learnr2.port = port)
  base <- sprintf("http://127.0.0.1:%d", port)

  # Stand in for a server left running in another terminal, with one
  # tutorial from some other content package already rendered into the
  # same cache: the stamp and html a previous run_tutorial() would have
  # left behind, written by hand so the test needs no second bundled tutorial.
  other_dir <- fs::path(out_parent, "other.tutorials", "intro")
  fs::dir_create(other_dir)
  writeLines("<p>other</p>", fs::path(other_dir, "index.html"))
  jsonlite::write_json(
    list(package = "other.tutorials", name = "intro", title = "Intro",
         learnr2_version = learnr2:::learnr2_version_string(), fingerprint = "x",
         rendered_at = "2026-10-01 12:00:00 UTC", html = "index.html"),
    fs::path(other_dir, "learnr2-tutorial.json"), auto_unbox = TRUE, pretty = TRUE
  )
  learnr2:::write_server_marker(as.character(fs::path_abs(out_parent)), port)
  withr::defer(learnr2:::remove_server_marker(as.character(fs::path_abs(out_parent))))
  server <- httpuv::runStaticServer(as.character(out_parent), port = port, browse = FALSE, background = TRUE)
  withr::defer(httpuv::stopServer(server))

  seen <- new.env()
  local_mocked_bindings(
    open_in_browser = function(url, public_url = url) { seen$url <- url; seen$public_url <- public_url; invisible() },
    block_serving = function() stop("must not start a second server")
  )
  expect_message(
    run_tutorial("hello-learnr2", package = "learnr2", output_dir = out_parent, open = TRUE),
    "already running"
  )
  root <- http_get(paste0(base, "/"))
  expect_identical(root$status, 200L)
  expect_match(root$body, 'url=/learnr2/hello-learnr2/"', fixed = TRUE)
  expect_match(root$body, 'href="/other.tutorials/intro/"', fixed = TRUE)
  expect_identical(http_get(paste0(base, "/other.tutorials/intro/"))$status, 200L)
  expect_identical(http_get(paste0(base, "/learnr2/hello-learnr2/"))$status, 200L)
})

test_that("port_listening() is a plain TCP connect: FALSE for a free port, TRUE for a live server", {
  port <- free_port()
  expect_false(learnr2:::port_listening(port))

  server <- httpuv::startServer("127.0.0.1", port, list(call = function(req) {
    list(status = 200L, headers = list("Content-Type" = "text/plain"), body = "hi")
  }))
  withr::defer(httpuv::stopServer(server))
  expect_true(learnr2:::port_listening(port))
})

test_that("probe_server() reports a port nothing listens on as free", {
  port <- free_port()
  expect_identical(learnr2:::probe_server(port), list(state = "free", server = NULL))
})

test_that("probe_server() waits out a listener that is still closing before calling it 'other'", {
  # Simulate httpuv's asynchronous close: the first look sees a listener
  # that answers nothing, the next sees nothing listening.
  state <- new.env()
  state$looks <- 0
  state$closes_after <- 2   # looks 1 and 2 see a listener; look 3 does not
  local_mocked_bindings(
    port_listening = function(port, ...) {
      state$looks <- state$looks + 1
      state$looks <= state$closes_after
    },
    fetch_server_marker = function(port) list(state = "other", server = NULL)
  )
  expect_identical(learnr2:::probe_server(1, wait = 0), list(state = "free", server = NULL))
  expect_identical(state$looks, 3)

  # But a listener that stays, and never answers with the marker, is "other"
  # after `attempts` looks, not forever.
  state$looks <- 0
  state$closes_after <- Inf
  expect_identical(learnr2:::probe_server(1, attempts = 3, wait = 0), list(state = "other", server = NULL))
  expect_identical(state$looks, 3)
})

test_that("probe_server() reports a listener that is not a learnr2 server as other", {
  # Something answering, but with no marker (404), and something answering
  # with the marker path but not JSON: both are "other", never "learnr2".
  port <- free_port()
  server <- httpuv::startServer("127.0.0.1", port, list(call = function(req) {
    list(status = 404L, headers = list("Content-Type" = "text/plain"), body = "nope")
  }))
  withr::defer(httpuv::stopServer(server))
  expect_identical(learnr2:::probe_server(port), list(state = "other", server = NULL))

  port2 <- free_port()
  server2 <- httpuv::startServer("127.0.0.1", port2, list(call = function(req) {
    list(status = 200L, headers = list("Content-Type" = "text/plain"), body = "not json")
  }))
  withr::defer(httpuv::stopServer(server2))
  expect_identical(learnr2:::probe_server(port2), list(state = "other", server = NULL))
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

test_that("run_tutorial() refuses a classic learnr tutorial, naming learnr::run_tutorial()", {
  local_dev_tutorial_package()
  local_mocked_bindings(
    quarto_render = function(...) stop("quarto must not be called"),
    .package = "quarto"
  )
  expect_error(
    run_tutorial("classic", package = "fakeTutorials", open = FALSE),
    'classic learnr tutorial.*learnr::run_tutorial\\("classic", package = "fakeTutorials"\\)'
  )
  # An empty directory is just unknown.
  expect_error(run_tutorial("empty", package = "fakeTutorials", open = FALSE), "Unknown tutorial")
})
