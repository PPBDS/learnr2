# Running a tutorial: render it into the per-user cache (or reuse the
# cached render), serve the cache root on the fixed port, open the browser.
# Listing tutorials is R/tutorials.R; rendering itself is
# R/render_tutorials.R.

#' Run a bundled tutorial
#'
#' Runs a learnr2 tutorial bundled with an installed package: renders it
#' into a per-user cache -- or reuses that render, if nothing has changed --
#' and, when `open` is `TRUE`, serves it to a browser. learnr2 runs only its
#' own Quarto (`.qmd`) tutorials and does not depend on 'learnr'. Asked for
#' a classic 'learnr' tutorial (an `.Rmd`), it stops and says to run that
#' one with `learnr::run_tutorial()`.
#'
#' @param name Name of the tutorial to run. See [available_tutorials()]. If
#'   `NULL`, the available tutorials in `package` are listed.
#' @param package Name of the package the tutorial is bundled with. Defaults
#'   to `"learnr2"`; set this to run a tutorial from another installed
#'   package (e.g. a 'primer.tutorials'-style content package), or from one
#'   loaded with `pkgload::load_all()` (see [available_tutorials()]).
#' @param output_dir Root of the render cache. Each tutorial is rendered into
#'   `output_dir/<package>/<name>/`. Defaults to a persistent per-user
#'   directory (see [tools::R_user_dir()]), *not* [tempfile()]: a persistent
#'   location is what makes the render cache (below) work at all, and R
#'   deletes its session temp directory as soon as the R process exits,
#'   which races with the browser actually loading the page when
#'   `open = TRUE` is used from `Rscript`.
#' @param open Whether to serve the tutorial and open it in a browser.
#'   Defaults to `TRUE` when interactive. When `TRUE`, this call blocks (like
#'   [httpuv::runStaticServer()] or `shiny::runApp()`) until you interrupt it
#'   (Ctrl+C, or the console's Stop button) -- see the sections below for
#'   why. When `FALSE`, the tutorial is rendered (or found in the cache)
#'   and its path returned without serving or blocking. Note that under
#'   `Rscript` the default is `FALSE`, so pass `open = TRUE` explicitly
#'   there.
#' @param refresh Re-render the tutorial even if the cached render is
#'   current. Defaults to `FALSE`.
#'
#' @return Path to the rendered HTML file, invisibly.
#'
#' @section Render cache:
#' Rendering a Quarto tutorial takes several seconds on a laptop and well
#' over ten on a small cloud machine, and nothing about an installed
#' tutorial changes between one launch and the next. So the render is
#' cached: alongside the HTML in `output_dir/<package>/<name>/`, a stamp
#' file records the learnr2 version and a fingerprint of every file in the
#' installed tutorial directory. On the next launch, if both still match,
#' the cached HTML is served at once. Reinstalling the tutorial's package
#' or upgrading learnr2 invalidates the cache; so does `refresh = TRUE`.
#' Before any re-render the old copy is deleted, so files a previous
#' version of the tutorial had and the current one does not cannot linger.
#'
#' [prerender_tutorials()] fills the cache for every installed Quarto
#' tutorial ahead of time -- for instance while building a container image
#' -- so that even a student's first launch is instant.
#'
#' @section Serving, the fixed port, and saved answers:
#' A reader's answers and typed exercise code are saved in the browser's
#' `localStorage`, keyed by the page URL (see "Progress persistence" in
#' [question()]). For them to be found again tomorrow, the URL has to be
#' the same tomorrow. So learnr2 always serves on one fixed port, 7446
#' (`getOption("learnr2.port")` overrides it), and never falls back to a
#' random one; and it serves the whole cache root rather than a single
#' tutorial, so every tutorial has its own stable address,
#' `http://127.0.0.1:7446/<package>/<name>/`, and no two tutorials share
#' saved state or get wiped together by one tutorial's "Start Over".
#'
#' Because the server serves the whole cache, one server is enough for any
#' number of tutorials. If a learnr2 server is already running on the port
#' (say, in another terminal), this function renders into the cache if
#' needed and simply opens the tutorial's address in the browser, without
#' starting a second server or blocking. If the port is held by something
#' other than a learnr2 server, it stops with an error rather than silently
#' serving somewhere the browser has no saved answers for.
#'
#' The cache root itself (`http://127.0.0.1:7446/`) is a small page that
#' forwards to the tutorial launched most recently and lists every other
#' rendered tutorial in the cache. That root is what a tool that only knows
#' the port opens -- notably the "open in browser" notification VS Code and
#' GitHub Codespaces show when they detect a new local port -- so landing
#' on it has to reach the tutorial rather than a 404.
#'
#' @section Running in GitHub Codespaces (or another remote container):
#' The server runs inside the container, so `http://127.0.0.1:7446/...`
#' is only reachable from inside it; in the browser on your own machine
#' that address refuses to connect. Codespaces forwards the port to a
#' public address, `https://<codespace>-7446.app.github.dev/`, and this
#' function detects a codespace (the `CODESPACE_NAME` and
#' `GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN` environment variables) and
#' prints the tutorial's forwarded address. The browser is still opened on
#' the local address, through the helper VS Code puts in `BROWSER`, which
#' forwards the port as part of opening it, just as clicking a localhost
#' link in the terminal does; opening the forwarded address directly can
#' race the port forwarding and show an empty 404 until reloaded. The
#' forwarded root page forwards to the tutorial too, so the "Open in
#' Browser" button on the port notification lands in the right place.
#' Saved answers are keyed by page URL, so they live under the forwarded
#' address and are found again as long as the codespace keeps its name.
#'
#' @section Why this blocks and serves over local HTTP instead of opening the file directly:
#' Every `{webr}` exercise compiles down to Observable JS, which Quarto's
#' runtime loads as ES modules, and browsers refuse to load ES modules from
#' a `file://` URL: a rendered tutorial opened as a file shows an "OJS
#' runtime" error (plain [question()] and [student_info()] widgets would
#' work, the code cells would not). So the tutorial is served, by httpuv's
#' static server inside this R process. A background daemon
#' ([quarto::quarto_preview()]) was tried and did not reliably outlive the
#' call. The trade-off is that serving blocks the caller, as 'learnr''s own
#' `run_tutorial()` (a Shiny app) did; stop the server to get your prompt
#' back.
#'
#' @seealso [prerender_tutorials()] to fill the render cache in advance.
#' @export
#' @examples
#' # With no `name`, just lists the tutorials that can be run.
#' run_tutorial()
#'
#' # Render without serving (open = FALSE), into a temporary directory
#' # rather than the user cache. Calling it again would reuse this render;
#' # pass refresh = TRUE to force a new one. Runs only interactively, with the
#' # Quarto command line tool installed: a full tutorial takes several
#' # seconds to render.
#' if (interactive() && !is.null(quarto::quarto_path())) {
#'   out <- tempfile()
#'   html <- run_tutorial("hello-learnr2", output_dir = out, open = FALSE)
#'   file.exists(html)
#'   unlink(out, recursive = TRUE)
#' }
#'
#' # Not run: with open = TRUE, starts a local web server that blocks the
#' # session until interrupted.
#' \dontrun{
#' run_tutorial("hello-learnr2")
#' }
run_tutorial <- function(name = NULL,
                         package = "learnr2",
                         output_dir = tools::R_user_dir("learnr2", "cache"),
                         open = interactive(),
                         refresh = FALSE) {
  tutorials <- available_tutorials(package = package)
  if (is.null(name)) {
    message(
      "Available tutorials in ", package, ":\n",
      paste0("  - ", tutorials$name, collapse = "\n")
    )
    return(invisible(NULL))
  }
  if (!name %in% tutorials$name) {
    if (is_classic_tutorial(name, package)) {
      stop("\"", name, "\" in package ", package, " is a classic learnr ",
           "tutorial (an .Rmd), which learnr2 does not run. Run it with ",
           "learnr::run_tutorial(\"", name, "\", package = \"", package, "\").",
           call. = FALSE)
    }
    stop("Unknown tutorial: ", name, " in package ", package, ".\nAvailable: ",
         paste(tutorials$name, collapse = ", "), call. = FALSE)
  }
  tutorial <- tutorials[tutorials$name == name, , drop = FALSE]

  root <- fs::path_abs(output_dir)
  rendered <- ensure_rendered(tutorial, root, refresh = refresh)

  if (!isTRUE(open)) {
    return(invisible(rendered$html))
  }

  serve_tutorial(tutorial, root)
  invisible(rendered$html)
}

#' Render every installed Quarto tutorial into the cache
#'
#' Fills [run_tutorial()]'s render cache ahead of time, so that the first
#' launch of each tutorial is as fast as every later one. Intended for
#' environment builds -- a container image, a Codespaces prebuild, a lab
#' machine setup -- where the render cost can be paid once for everyone,
#' before any student is waiting. Tutorials whose cached render is already
#' current are skipped.
#'
#' @param package Name of a single package whose tutorials to render.
#'   Defaults to `NULL`, which renders the Quarto tutorials of every
#'   installed package.
#' @inheritParams run_tutorial
#'
#' @return A data frame, invisibly, with one row per Quarto tutorial and
#'   columns `package`, `name`, `html` (the rendered file) and `rendered`
#'   (`TRUE` if it was rendered on this call, `FALSE` if the cached copy was
#'   already current).
#'
#' @section Where the cache must live:
#' The default `output_dir` is a per-user directory (see
#' [tools::R_user_dir()]), so pre-rendering only helps if it runs *as the
#' user who will later run the tutorials*, with the same `HOME` -- in a
#' Dockerfile, as the image's runtime user, not root -- or with an
#' `output_dir` both can see. The cache is keyed on the installed tutorial
#' files and the learnr2 version, so it stays valid for as long as those
#' are the ones baked in alongside it.
#'
#' @seealso [run_tutorial()], whose "Render cache" section explains what
#'   makes a cached render current.
#' @export
#' @examples
#' # One package, into a temporary directory rather than the user cache.
#' # Called with no arguments, prerender_tutorials() renders every installed
#' # package's tutorials into the default per-user cache. Runs only
#' # interactively, with the Quarto command line tool installed: a full
#' # tutorial takes several seconds to render.
#' if (interactive() && !is.null(quarto::quarto_path())) {
#'   out <- tempfile()
#'   prerender_tutorials(package = "learnr2", output_dir = out)
#'   unlink(out, recursive = TRUE)
#' }
prerender_tutorials <- function(package = NULL,
                                output_dir = tools::R_user_dir("learnr2", "cache"),
                                refresh = FALSE) {
  tutorials <- available_tutorials(package = package)
  root <- fs::path_abs(output_dir)
  rows <- lapply(seq_len(nrow(tutorials)), function(i) {
    tutorial <- tutorials[i, , drop = FALSE]
    result <- ensure_rendered(tutorial, root, refresh = refresh)
    data.frame(
      package = tutorial$package,
      name = tutorial$name,
      html = result$html,
      rendered = result$rendered,
      stringsAsFactors = FALSE
    )
  })
  out <- if (length(rows) > 0) {
    do.call(rbind, rows)
  } else {
    data.frame(
      package = character(0), name = character(0),
      html = character(0), rendered = logical(0),
      stringsAsFactors = FALSE
    )
  }
  rownames(out) <- NULL
  message(
    sum(out$rendered), " tutorial(s) rendered, ", sum(!out$rendered),
    " already current, in ", root
  )
  invisible(out)
}

# ---------------------------------------------------------------------------
# Render cache
# ---------------------------------------------------------------------------

# Written into each rendered tutorial's directory; what makes a render
# "current" (see render_is_current()).
STAMP_FILE <- "learnr2-tutorial.json"

# Written at the cache root while a server is serving it, and fetched over
# HTTP by probe_server() to recognise a running learnr2 server.
SERVER_FILE <- "learnr2-server.json"

tutorial_work_dir <- function(root, package, name) {
  fs::path(root, package, name)
}

# Render `tutorial` into root/<package>/<name>/ unless a current render is
# already there (or `refresh`). Returns list(html, work_dir, rendered).
ensure_rendered <- function(tutorial, root, refresh = FALSE) {
  src <- fs::path_dir(tutorial$path)
  work_dir <- tutorial_work_dir(root, tutorial$package, tutorial$name)
  html <- fs::path(work_dir, fs::path_ext_set(fs::path_file(tutorial$path), "html"))
  fingerprint <- tutorial_fingerprint(src)

  stamp <- read_stamp(work_dir)
  if (!isTRUE(refresh) && render_is_current(stamp, fingerprint) && fs::file_exists(html)) {
    message(
      "Using \"", tutorial$name, "\" as rendered ", stamp$rendered_at,
      " (pass refresh = TRUE to re-render)."
    )
    return(list(html = as.character(html), work_dir = as.character(work_dir), rendered = FALSE))
  }

  # Start from nothing: fs::dir_copy() overwrites files but would leave
  # behind any the previous version of the tutorial had and this one lacks.
  if (fs::dir_exists(work_dir)) {
    fs::dir_delete(work_dir)
  }
  rendered <- render_tutorials(src, output_dir = fs::path_dir(work_dir))[[1]]

  # The tutorial's address is its directory, …/<package>/<name>/, so the
  # static server needs an index.html there to land on.
  fs::file_copy(rendered, fs::path(work_dir, "index.html"), overwrite = TRUE)
  write_stamp(work_dir, tutorial, fingerprint, html = fs::path_file(rendered))
  list(html = as.character(rendered), work_dir = as.character(work_dir), rendered = TRUE)
}

# A digest of every file in the installed tutorial directory (not just the
# .qmd: includes, images and data files render into the page too).
tutorial_fingerprint <- function(src) {
  files <- sort(as.character(fs::dir_ls(src, recurse = TRUE, type = "file", all = TRUE)))
  listing <- paste(fs::path_rel(files, src), unname(tools::md5sum(files)))
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeLines(listing, tmp)
  unname(tools::md5sum(tmp))
}

learnr2_version_string <- function() {
  as.character(utils::packageVersion("learnr2"))
}

read_stamp <- function(work_dir) {
  path <- fs::path(work_dir, STAMP_FILE)
  if (!fs::file_exists(path)) {
    return(NULL)
  }
  tryCatch(jsonlite::fromJSON(path), error = function(e) NULL)
}

write_stamp <- function(work_dir, tutorial, fingerprint, html) {
  stamp <- list(
    package = tutorial$package,
    name = tutorial$name,
    title = if (is.null(tutorial$title) || is.na(tutorial$title)) tutorial$name else tutorial$title,
    learnr2_version = learnr2_version_string(),
    fingerprint = fingerprint,
    rendered_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    html = as.character(html)
  )
  jsonlite::write_json(stamp, fs::path(work_dir, STAMP_FILE), auto_unbox = TRUE, pretty = TRUE)
}

# A render is current when it was made by this learnr2 from exactly these
# tutorial files. Anything else -- no stamp, unreadable stamp, other
# version, other files -- means render again.
render_is_current <- function(stamp, fingerprint) {
  !is.null(stamp) &&
    identical(stamp$learnr2_version, learnr2_version_string()) &&
    identical(stamp$fingerprint, fingerprint)
}

# ---------------------------------------------------------------------------
# Serving
# ---------------------------------------------------------------------------

# Fixed, never random: saved answers are keyed by page URL, so a different
# port tomorrow would look like lost work. See ?run_tutorial.
learnr2_port <- function() {
  as.integer(getOption("learnr2.port", 7446L))
}

tutorial_url <- function(package, name, port = learnr2_port()) {
  sprintf("http://127.0.0.1:%d/%s/%s/", port, package, name)
}

# The address a reader's browser can actually reach. Inside a GitHub
# Codespace the server is in the container and 127.0.0.1 in the reader's
# own browser is their laptop, so hand out the forwarded address Codespaces
# publishes for the port instead (see ?run_tutorial).
public_tutorial_url <- function(package, name, port = learnr2_port()) {
  base <- codespace_base_url(port)
  if (is.null(base)) {
    return(tutorial_url(package, name, port))
  }
  sprintf("%s/%s/%s/", base, package, name)
}

codespace_base_url <- function(port) {
  codespace <- Sys.getenv("CODESPACE_NAME")
  domain <- Sys.getenv("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN")
  if (!nzchar(codespace) || !nzchar(domain)) {
    return(NULL)
  }
  sprintf("https://%s-%d.%s", codespace, as.integer(port), domain)
}

# Serve the cache root on the fixed port and open `tutorial`'s address --
# or, if a learnr2 server is already serving that root, just open it there.
# `page` is a file inside the tutorial's directory to open instead of the
# tutorial itself (load_tutorial()'s restore page). The result carries
# attribute `served_here`: TRUE when this call ran the server until it was
# stopped, FALSE when an existing server was used.
serve_tutorial <- function(tutorial, root, page = NULL) {
  port <- learnr2_port()
  local <- paste0(tutorial_url(tutorial$package, tutorial$name, port), page)
  url <- paste0(public_tutorial_url(tutorial$package, tutorial$name, port), page)
  root <- as.character(fs::path_abs(root))
  write_root_index(root, tutorial$package, tutorial$name)

  running <- probe_server(port)
  if (identical(running$state, "learnr2")) {
    served_root <- as.character(fs::path_abs(running$server$root))
    if (!identical(served_root, root)) {
      stop(
        "A learnr2 server is already running on port ", port, ", but it is ",
        "serving ", served_root, " rather than ", root, ". Stop it (Ctrl+C in ",
        "its terminal) or run this tutorial with that output_dir.",
        call. = FALSE
      )
    }
    message(
      "A learnr2 server is already running on port ", port, "; opening ",
      url, " there."
    )
    open_in_browser(local, url)
    return(invisible(structure(url, served_here = FALSE)))
  }
  if (identical(running$state, "other")) {
    stop(
      "Port ", port, " is in use by something other than a learnr2 tutorial ",
      "server. learnr2 always serves tutorials on this port so that the ",
      "answers saved in the browser can be found again (see ?run_tutorial); ",
      "free the port and try again.",
      call. = FALSE
    )
  }

  write_server_marker(root, port)
  on.exit(remove_server_marker(root), add = TRUE)
  server <- httpuv::runStaticServer(root, port = port, browse = FALSE, background = TRUE)
  on.exit(httpuv::stopServer(server), add = TRUE)

  message(
    "Opening ", url, "\n",
    "Press Ctrl+C (or the console's Stop button) to stop the server."
  )
  open_in_browser(local, url)
  block_serving()
  invisible(structure(url, served_here = TRUE))
}

write_server_marker <- function(root, port) {
  marker <- list(
    learnr2_version = learnr2_version_string(),
    root = root,
    port = port,
    pid = Sys.getpid(),
    started_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  )
  fs::dir_create(root)
  jsonlite::write_json(marker, fs::path(root, SERVER_FILE), auto_unbox = TRUE, pretty = TRUE)
}

remove_server_marker <- function(root) {
  path <- fs::path(root, SERVER_FILE)
  if (fs::file_exists(path)) {
    fs::file_delete(path)
  }
}

# <root>/index.html: what the server shows at its root. Whoever opens the
# bare port -- a person typing it, or VS Code's / Codespaces' "open in
# browser" notification for a newly detected port, which only knows the
# port -- is forwarded to the tutorial launched most recently, with every
# other rendered tutorial linked underneath in case that was not the one
# they wanted. Rewritten on every launch so the forward always points at the
# latest one. Without it httpuv answers the root with a bare 404.
write_root_index <- function(root, package, name) {
  target <- sprintf("/%s/%s/", package, name)
  items <- vapply(rendered_tutorials(root), function(t) {
    sprintf('<li><a href="/%s/%s/">%s</a> <small>(%s)</small></li>',
            t$package, t$name, html_escape(t$title), html_escape(t$package))
  }, character(1))
  page <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\"><head><meta charset=\"utf-8\">",
    sprintf("<meta http-equiv=\"refresh\" content=\"0; url=%s\">", target),
    "<title>learnr2 tutorials</title></head><body>",
    sprintf("<p>Opening <a href=\"%s\">%s/%s</a>&hellip;</p>", target, package, name),
    "<p>Rendered tutorials:</p>",
    "<ul>", items, "</ul>",
    "</body></html>"
  )
  fs::dir_create(root)
  writeLines(page, fs::path(root, "index.html"))
  invisible(fs::path(root, "index.html"))
}

# Every <root>/<package>/<name>/ with a readable stamp: list of
# list(package, name, title), most recently rendered first.
rendered_tutorials <- function(root) {
  root <- as.character(fs::path_norm(root))
  stamps <- fs::dir_ls(root, recurse = 2, type = "file", glob = paste0("*/", STAMP_FILE))
  stamps <- stamps[vapply(stamps, function(p) {
    # Exactly <root>/<package>/<name>/<STAMP_FILE>.
    identical(as.character(fs::path_dir(fs::path_dir(fs::path_dir(p)))), as.character(root))
  }, logical(1))]
  found <- lapply(stamps, function(p) {
    stamp <- tryCatch(jsonlite::fromJSON(p), error = function(e) NULL)
    if (is.null(stamp$package) || is.null(stamp$name)) return(NULL)
    title <- stamp$title %||% stamp$name
    list(package = stamp$package, name = stamp$name,
         title = if (is.na(title) || !nzchar(title)) stamp$name else title,
         rendered_at = stamp$rendered_at %||% "")
  })
  found <- Filter(Negate(is.null), unname(found))
  found[order(vapply(found, function(t) t$rendered_at, character(1)), decreasing = TRUE)]
}

html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

# What, if anything, answers on `port`: list(state, server) with state one
# of "free" (nothing listening), "learnr2" (a learnr2 server; `server` is
# its marker, with the root it serves) or "other" (something else).
#
# Two steps: a plain TCP connect decides "listening or not" (never the
# wording of an error message, which differs on Windows), then fetching the
# marker decides "learnr2 or other". "Other" is re-checked a few times
# before it is believed: httpuv closes a stopped listener asynchronously,
# so a port can briefly accept connections nothing answers (long enough to
# matter on Windows). A genuinely foreign listener just costs a second.
probe_server <- function(port, attempts = 5L, wait = 0.2) {
  result <- list(state = "free", server = NULL)
  for (attempt in seq_len(attempts)) {
    if (!port_listening(port)) {
      return(list(state = "free", server = NULL))
    }
    result <- fetch_server_marker(port)
    if (identical(result$state, "learnr2")) {
      return(result)
    }
    Sys.sleep(wait)
  }
  result
}

# GET the marker from a port something listens on: list(state, server)
# with state "learnr2" (marker read and parsed) or "other" (anything else).
fetch_server_marker <- function(port) {
  target <- sprintf("http://127.0.0.1:%d/%s", port, SERVER_FILE)
  old <- options(timeout = 2)
  on.exit(options(old), add = TRUE)
  tryCatch(
    {
      con <- url(target, open = "rb")
      on.exit(close(con), add = TRUE)
      txt <- readLines(con, warn = FALSE, encoding = "UTF-8")
      list(state = "learnr2", server = jsonlite::fromJSON(paste(txt, collapse = "\n")))
    },
    warning = function(w) list(state = "other", server = NULL),
    error = function(e) list(state = "other", server = NULL)
  )
}

# TRUE if a TCP connection to 127.0.0.1:port can be opened. A connection to
# a port nothing listens on is refused immediately on every platform;
# `timeout` only bounds the odd case of a listener that accepts slowly.
port_listening <- function(port, timeout = 2) {
  con <- tryCatch(
    suppressWarnings(
      socketConnection(host = "127.0.0.1", port = port, server = FALSE,
                       blocking = TRUE, open = "r+b", timeout = timeout)
    ),
    error = function(e) NULL
  )
  if (is.null(con)) {
    return(FALSE)
  }
  close(con)
  TRUE
}

# Seams around the two things a unit test must never do for real: open a
# browser, and block in httpuv's event loop until interrupted.
#
# `url` is always the *local* address, even in a codespace, where
# `public_url` is the forwarded one a person could type. VS Code's BROWSER
# helper forwards the port as part of opening a localhost address; handed
# the forwarded address instead, the first request races the forwarding
# and lands on the proxy's 404. Where no browser can be opened (xdg-open
# inside a container), the message names the address to open by hand.
open_in_browser <- function(url, public_url = url) {
  browser <- Sys.getenv("BROWSER")
  if (!nzchar(browser)) browser <- getOption("browser")
  tryCatch(
    utils::browseURL(url, browser = browser),
    error = function(e) {
      message("Could not open a browser (", conditionMessage(e), "); open ",
              public_url, " yourself.")
    }
  )
}

block_serving <- function() {
  httpuv::service(0)
}
