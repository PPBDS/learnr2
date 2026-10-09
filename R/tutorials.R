#' List tutorials bundled with learnr2 (or any installed package)
#'
#' Scans one package -- or, by default, every package installed -- for a
#' bundled `inst/tutorials/` directory, the same convention 'learnr' uses,
#' and lists the learnr2 tutorials in it: each subdirectory that contains a
#' `.qmd` document. Classic 'learnr' tutorials (`.Rmd`) in the same
#' directory are not listed; learnr2 neither lists nor runs them (see
#' [run_tutorial()]).
#' This lets tools like the "R Tutorials" VS Code extension discover
#' tutorials from separately-installed content packages (in the style of
#' 'primer.tutorials') without knowing their names in advance.
#'
#' A package loaded from its source tree with `pkgload::load_all()` (as
#' `devtools::load_all()` and `devtools::test()` do) counts as well: its
#' tutorials are read from the source `inst/tutorials/`, so a content
#' package's own tests see its working tree, not a stale installed copy.
#' See the section below.
#'
#' @param package Name of a single package to scan. Defaults to `NULL`,
#'   which scans every installed package, plus any package currently loaded
#'   with `pkgload::load_all()`.
#' @param type Kept so existing callers keep working: `"all"` (the
#'   default) and `"quarto"` both list every learnr2 tutorial. learnr2 no
#'   longer handles classic learnr tutorials, so `"rmarkdown"` is an error;
#'   use `learnr::available_tutorials()` for those.
#'
#' @return A data frame with one row per tutorial and columns `package`,
#'   `name`, `title` (`NA` if the tutorial's `.qmd` has no YAML `title`),
#'   `format` (always `"quarto"`), `path` (the installed `.qmd` file),
#'   `ordering` (the number set by `learnr2: ordering:` in the YAML header;
#'   `NA` if absent -- see "Ordering" below), and `package_dependencies` (a
#'   list column of the R packages each tutorial needs installed locally:
#'   always `character(0)`, since a learnr2 tutorial runs its code in the
#'   reader's browser). `format` and `package_dependencies` carry no
#'   information any more; they are kept so that tools written when learnr2
#'   also listed classic tutorials, such as the "R Tutorials" VS Code
#'   extension, keep working.
#'   `name` can be passed to [run_tutorial()]; `path` to
#'   [render_tutorials()] and [check_tutorial()].
#'
#' @section Ordering:
#' By default a package's tutorials are listed in the order of their
#' directory names, so authors usually number them (`01-intro`,
#' `02-data`, ...). A tutorial can instead set its position in its YAML
#' header, without renaming its directory (a directory name is the
#' tutorial's id, so renaming one breaks links and render caches):
#'
#' ```yaml
#' learnr2:
#'   ordering: 3
#' ```
#'
#' `available_tutorials()` reports it in the `ordering` column. Tools that
#' list tutorials, such as the "R Tutorials" VS Code extension, sort a
#' package's tutorials by `ordering` (lowest first), with tutorials that
#' don't set it after those that do, in directory-name order. A value that
#' is not a single number is ignored (reported as `NA`); [check_tutorial()]
#' flags it.
#'
#' @section Packages loaded with pkgload:
#' `system.file()` resolves against the *installed* copy of a package, so a
#' content package under development used to be invisible here (or, worse,
#' silently read from an old install) when its own tests ran under
#' `devtools::test()`: 'pkgload' redirects `system.file()` only for code
#' inside the package being developed, not for learnr2's calls. This
#' function and [run_tutorial()] therefore check whether `package` is a
#' namespace loaded by `pkgload::load_all()` and, if so, read its tutorials from the
#' source tree's `inst/tutorials/` directly. Nothing changes for installed
#' packages, and 'pkgload' itself is not required.
#' @export
#' @examples
#' # Qualified with learnr2:: because the learnr package exports a function of
#' # the same name; this guarantees learnr2's version is used even if learnr is
#' # also attached and masks it on the search path.
#' learnr2::available_tutorials(package = "learnr2")
#' learnr2::available_tutorials(package = "learnr2", type = "quarto")
available_tutorials <- function(package = NULL, type = "all") {
  if (identical(type, "rmarkdown")) {
    stop('learnr2 does not list classic learnr (.Rmd) tutorials. ',
         'Use learnr::available_tutorials() for those.', call. = FALSE)
  }
  if (!is.character(type) || length(type) != 1 || !type %in% c("all", "quarto")) {
    stop('`type` must be "all" or "quarto".', call. = FALSE)
  }
  if (!is.null(package)) {
    if (!is.character(package) || length(package) != 1 || !nzchar(package)) {
      stop("`package` must be a single non-empty string.", call. = FALSE)
    }
    if (!nzchar(pkg_file(package = package))) {
      stop("No package found with name: \"", package, "\".", call. = FALSE)
    }
    packages <- package
  } else {
    packages <- union(dev_packages(), packages_with_tutorials())
  }

  rows <- lapply(packages, tutorials_in_package)
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(data.frame(
      package = character(0),
      name = character(0),
      title = character(0),
      format = character(0),
      path = character(0),
      ordering = numeric(0),
      package_dependencies = I(list()),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# One data frame row per learnr2 tutorial in `pkg`'s inst/tutorials/ -- each
# subdirectory holding a .qmd -- or NULL if there are none. Directories with
# only a classic learnr .Rmd (or no document) are skipped.
tutorials_in_package <- function(pkg) {
  root <- pkg_file("tutorials", package = pkg)
  if (!nzchar(root)) {
    return(NULL)
  }
  dirs <- fs::dir_ls(root, type = "directory")
  docs <- vapply(dirs, tutorial_doc, character(1), USE.NAMES = FALSE)
  keep <- !is.na(docs)
  if (!any(keep)) {
    return(NULL)
  }
  dirs <- dirs[keep]
  docs <- docs[keep]
  data.frame(
    package = pkg,
    name = fs::path_file(dirs),
    title = vapply(docs, tutorial_title, character(1), USE.NAMES = FALSE),
    format = "quarto",
    path = docs,
    ordering = vapply(docs, tutorial_ordering, numeric(1), USE.NAMES = FALSE),
    package_dependencies = I(rep(list(character(0)), length(docs))),
    stringsAsFactors = FALSE
  )
}

# system.file() that also sees a package loaded from its source tree with
# pkgload::load_all() -- what devtools::load_all() and devtools::test() do.
#
# pkgload makes such a package's *own* system.file() calls resolve to its
# source inst/, but learnr2's calls are not rewritten, so base system.file()
# finds either nothing (package not installed) or an installed copy that may
# be stale. pkgload marks a namespace it loaded with a `.__DEVTOOLS__`
# binding and registers the source directory as the namespace path; this
# reads both without needing pkgload itself. With no `...` it returns the
# package root, like system.file(package = pkg). Everything else goes to
# base system.file() unchanged.
pkg_file <- function(..., package) {
  root <- dev_package_path(package)
  if (is.null(root)) {
    return(system.file(..., package = package))
  }
  if (...length() == 0) {
    return(root)
  }
  path <- file.path(root, "inst", ...)
  if (file.exists(path)) path else ""
}

# Names of every installed package that ships a tutorials/ directory, found
# by listing the libraries on .libPaths() directly. utils::installed.packages()
# would also give the names, but it reads several files per installed
# package (its own help page warns against using it for this), whereas a
# tutorials/ directory is one file.exists() per package directory and most
# packages have none. First library wins for a name installed in several,
# matching system.file(). The libraries are a parameter only for testing.
packages_with_tutorials <- function(libs = .libPaths()) {
  found <- character(0)
  for (lib in libs) {
    pkgs <- list.dirs(lib, full.names = FALSE, recursive = FALSE)
    pkgs <- pkgs[!startsWith(pkgs, ".")]
    has_tutorials <- file.exists(file.path(lib, pkgs, "tutorials")) &
      file.exists(file.path(lib, pkgs, "DESCRIPTION"))
    found <- c(found, pkgs[has_tutorials])
  }
  unique(found)
}

# The source directory of `package` if pkgload::load_all() loaded it, else
# NULL. Checking isNamespaceLoaded() first means an unloaded or uninstalled
# package is simply not a dev package, with no error.
dev_package_path <- function(package) {
  if (!isNamespaceLoaded(package)) {
    return(NULL)
  }
  ns <- asNamespace(package)
  if (!exists(".__DEVTOOLS__", envir = ns, inherits = FALSE)) {
    return(NULL)
  }
  getNamespaceInfo(ns, "path")
}

# Every namespace currently loaded by pkgload::load_all().
dev_packages <- function() {
  loaded <- loadedNamespaces()
  loaded[!vapply(lapply(loaded, dev_package_path), is.null, logical(1))]
}

# The first .qmd directly inside `dir`, or NA if it has none.
tutorial_doc <- function(dir) {
  doc <- fs::dir_ls(dir, glob = "*.qmd")
  if (length(doc) == 0) NA_character_ else as.character(doc[1])
}

# TRUE if `package` has a tutorial directory `name` holding a classic learnr
# .Rmd and no .qmd: something run_tutorial() can name helpfully, rather than
# report as unknown.
is_classic_tutorial <- function(name, package) {
  dir <- pkg_file("tutorials", name, package = package)
  nzchar(dir) && fs::dir_exists(dir) &&
    is.na(tutorial_doc(dir)) && length(fs::dir_ls(dir, glob = "*.Rmd")) > 0
}

# The YAML `title:` of `doc`, or NA if `doc` is NA or has no YAML `title`.
tutorial_title <- function(doc) {
  if (is.na(doc)) {
    return(NA_character_)
  }
  front_matter <- tryCatch(
    rmarkdown::yaml_front_matter(doc),
    error = function(e) NULL
  )
  title <- front_matter$title
  if (is.null(title)) NA_character_ else as.character(title)
}

# The YAML `learnr2: ordering:` of `doc` as a number, or NA if `doc` is NA,
# has no such key, or the value is not a single number (see "Ordering" in
# ?available_tutorials; check_tutorial() reports a malformed one).
tutorial_ordering <- function(doc) {
  if (is.na(doc)) {
    return(NA_real_)
  }
  front_matter <- tryCatch(
    rmarkdown::yaml_front_matter(doc),
    error = function(e) NULL
  )
  ordering <- front_matter$learnr2$ordering
  if (is.numeric(ordering) && length(ordering) == 1 && !is.na(ordering)) {
    as.numeric(ordering)
  } else {
    NA_real_
  }
}

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
#' Every `{webr}` exercise compiles down to Observable JS (OJS), which
#' Quarto's runtime loads via ES modules -- and browsers refuse to load ES
#' modules from a `file://` URL. Opening the rendered HTML directly (e.g.
#' `utils::browseURL()` on the local path, or double-clicking the file) hits
#' this and shows an "OJS runtime" error, even though plain
#' [question()]/[student_info()] widgets (not OJS-based) work fine over
#' `file://`.
#'
#' An earlier version of this function used [quarto::quarto_preview()] to
#' both render and serve the tutorial via a background daemon process, on
#' the theory that it would keep running after `run_tutorial()` returned.
#' In practice that daemon did not reliably stay alive (confirmed: it could
#' exit within seconds, even with the calling R session still running and
#' pumping its event loop), silently leaving you back at a `file://` URL
#' with no server behind it. This function now renders with the same
#' one-shot [quarto::quarto_render()] call the package's own pkgdown
#' publishing script uses, and serves the result with httpuv's static
#' server -- an in-process server with no separate daemon to lose track
#' of. Its trade-off is that it blocks the caller while serving, matching
#' how the original 'learnr' package's `run_tutorial()` (built on a
#' blocking Shiny app) behaved -- stop the server to get your prompt back.
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

  # Start from nothing: fs::dir_copy() overwrites files but leaves behind
  # any that an earlier version of the tutorial had and this one does not.
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
serve_tutorial <- function(tutorial, root) {
  port <- learnr2_port()
  local <- tutorial_url(tutorial$package, tutorial$name, port)
  url <- public_tutorial_url(tutorial$package, tutorial$name, port)
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
    return(invisible(url))
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
  invisible(url)
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
# Two steps on purpose. "Is anything listening?" is answered by a plain TCP
# connect, which either succeeds or fails on every platform. An earlier
# version inferred it from the wording of base::url()'s failure message
# ("Couldn't connect to server", "Connection refused"), which held on
# macOS and Linux and not on Windows, where a free port was reported as
# "other" and run_tutorial() refused to start at all (caught by R CMD check
# on windows-latest). Only once something is listening does the HTTP fetch
# of the marker decide between "learnr2" and "other".
#
# "Listening, but not a learnr2 server" is re-checked a few times before it
# is believed. httpuv closes a stopped server's listening socket
# asynchronously, on its background thread, so for a moment after
# stopServer() (or after httpuv::randomPort(), which starts and stops a
# server to test a port) the socket can still accept a connection that
# nothing will ever answer. On Windows that moment is long enough to be
# seen, and it made a free port look held (R CMD check on windows-latest,
# 2026-10). A genuinely foreign listener just costs a second before the
# error.
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
# `url` is always the *local* address (127.0.0.1), even in a codespace where
# the address a person can type is the forwarded one (`public_url`, printed
# in the failure message). VS Code sets BROWSER in its terminals to a helper
# that opens the address in the browser on the user's own machine, and for
# a localhost address in a remote window that helper forwards the port as
# part of opening it -- the same thing clicking a localhost link in the
# terminal does. Handing it the forwarded https address instead skips that
# step, and the first request then races the automatic port forwarding:
# observed in a codespace as an empty 404 from the Codespaces proxy that
# turned into the tutorial on reload a second later. Outside VS Code, R's
# default browser (from R_BROWSER) is often xdg-open, which has nothing to
# open inside a container; the failure message then names the address to
# open by hand.
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
