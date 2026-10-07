#' List tutorials bundled with learnr2 (or any installed package)
#'
#' Scans one package -- or, by default, every package installed -- for a
#' bundled `inst/tutorials/` directory, the same convention 'learnr' uses.
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
#' @param type Which authoring format to include: `"quarto"` (tutorials
#'   whose top-level document is a `.qmd`), `"rmarkdown"` (a `.Rmd`), or
#'   `"all"` (the default) for both.
#'
#' @return A data frame with one row per tutorial and columns `package`,
#'   `name`, `title` (`NA` if the tutorial's `.qmd`/`.Rmd` has no YAML
#'   `title`), `format` (`"quarto"` or `"rmarkdown"`), `path` (the
#'   installed `.qmd`/`.Rmd` file; `NA` if the directory has neither), and
#'   `package_dependencies` (a list column: for each tutorial, the character
#'   vector of R packages that must be installed locally before it can run).
#'   `name` can be passed to [run_tutorial()]; `path` to
#'   [render_tutorials()] and [check_tutorial()].
#'
#' @section Classic learnr tutorials:
#' A `"quarto"` tutorial's exercises run in the reader's browser via WebR, so
#' it needs no R packages installed locally beyond learnr2 itself and its
#' `package_dependencies` is `character(0)`. An `"rmarkdown"` tutorial is a
#' classic 'learnr' tutorial (an `.Rmd` with `runtime: shiny_prerendered`),
#' which runs as a Shiny app in the local R session. Its
#' `package_dependencies` are whatever 'learnr' finds by scanning the
#' tutorial's directory (`learnr::available_tutorials()`), which always
#' includes 'learnr' itself. If 'learnr' is not installed there is nothing
#' to ask, and such a tutorial could not run anyway, so the entry is `NA`.
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
  if (!is.character(type) || length(type) != 1 || !type %in% c("all", "rmarkdown", "quarto")) {
    stop('`type` must be one of "all", "rmarkdown", or "quarto".', call. = FALSE)
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
    packages <- union(dev_packages(), rownames(utils::installed.packages()))
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
      package_dependencies = I(list()),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (type != "all") {
    out <- out[!is.na(out$format) & out$format == type, , drop = FALSE]
    rownames(out) <- NULL
  }
  out
}

# One data frame row per tutorial subdirectory of `pkg`'s inst/tutorials/,
# or NULL if `pkg` bundles no tutorials at all.
tutorials_in_package <- function(pkg) {
  root <- pkg_file("tutorials", package = pkg)
  if (!nzchar(root)) {
    return(NULL)
  }
  dirs <- fs::dir_ls(root, type = "directory")
  if (length(dirs) == 0) {
    return(NULL)
  }
  docs <- lapply(dirs, tutorial_doc)
  tutorial_names <- fs::path_file(dirs)
  format <- vapply(docs, tutorial_format, character(1), USE.NAMES = FALSE)
  data.frame(
    package = pkg,
    name = tutorial_names,
    title = vapply(docs, tutorial_title, character(1), USE.NAMES = FALSE),
    format = format,
    path = unname(unlist(docs)),
    package_dependencies = I(tutorial_dependencies(pkg, tutorial_names, format)),
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

# The R packages each of `pkg`'s tutorials needs installed locally, as a list
# of character vectors parallel to `names`/`format`. A quarto tutorial runs
# its exercises in the browser (WebR), so it needs nothing beyond learnr2:
# character(0). An rmarkdown tutorial is a classic learnr tutorial, and learnr
# is the authority on what it needs (learnr::available_tutorials() scans the
# directory with renv) -- NA when learnr is not installed to ask, or cannot
# read the package. A directory with no document at all is NA too.
tutorial_dependencies <- function(pkg, names, format) {
  deps <- rep(list(character(0)), length(names))
  is_rmd <- !is.na(format) & format == "rmarkdown"
  deps[is.na(format) | is_rmd] <- list(NA_character_)
  if (!any(is_rmd) || !learnr_installed()) {
    return(deps)
  }
  learnr_tutorials <- tryCatch(
    learnr_available_tutorials(pkg),
    error = function(e) NULL
  )
  if (is.null(learnr_tutorials)) {
    return(deps)
  }
  idx <- match(names[is_rmd], learnr_tutorials$name)
  found <- !is.na(idx)
  deps[which(is_rmd)[found]] <- lapply(
    learnr_tutorials$package_dependencies[idx[found]],
    function(d) if (is.null(d)) character(0) else as.character(d)
  )
  deps
}

# Seams around learnr, which is only Suggested, so tests can mock it without
# loading it. These are the only places learnr is referenced. They are
# deliberately not named like learnr's own functions: learnr and learnr2 both
# export available_tutorials() and run_tutorial(), so a
# local_mocked_bindings(..., .package = "learnr") of either name would also
# replace learnr2's own binding in the test environment. (base:: bindings
# can't be mocked, hence the requireNamespace() wrapper too.)
learnr_installed <- function() {
  requireNamespace("learnr", quietly = TRUE)
}

learnr_available_tutorials <- function(package) {
  learnr::available_tutorials(package = package)
}

# Blocks while the Shiny app runs, like learnr::run_tutorial() itself. Not
# unit-tested: calling it for real launches Shiny and a browser.
learnr_run_tutorial <- function(name, package) {
  learnr::run_tutorial(name, package = package)
}

# The first .qmd/.Rmd directly inside `dir` (.qmd takes precedence if a
# tutorial somehow has both), or NA if it has neither.
tutorial_doc <- function(dir) {
  doc <- fs::dir_ls(dir, glob = "*.qmd")
  if (length(doc) == 0) {
    doc <- fs::dir_ls(dir, glob = "*.Rmd")
  }
  if (length(doc) == 0) NA_character_ else as.character(doc[1])
}

# "quarto" or "rmarkdown" based on `doc`'s extension, or NA if `doc` is NA.
tutorial_format <- function(doc) {
  if (is.na(doc)) {
    return(NA_character_)
  }
  if (identical(fs::path_ext(doc), "qmd")) "quarto" else "rmarkdown"
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

#' Run a bundled tutorial
#'
#' Runs a tutorial bundled with an installed package, whichever of the two
#' formats [available_tutorials()] reports it is. A `"quarto"` tutorial
#' (learnr2's own format) is rendered into a per-user cache -- or reused
#' from it, if it was rendered before and nothing has changed -- and, when
#' `open` is `TRUE`, served to a browser. An `"rmarkdown"` tutorial -- a
#' classic 'learnr' tutorial -- is handed to `learnr::run_tutorial()`, so a
#' tool built on learnr2 (such as the "R Tutorials" VS Code extension) can
#' run both kinds through this one function and depend only on learnr2.
#'
#' @param name Name of the tutorial to run. See [available_tutorials()]. If
#'   `NULL`, the available tutorials in `package` are listed.
#' @param package Name of the package the tutorial is bundled with. Defaults
#'   to `"learnr2"`; set this to run a tutorial from another installed
#'   package (e.g. a 'primer.tutorials'-style content package), or from one
#'   loaded with `pkgload::load_all()` (see [available_tutorials()]).
#' @param output_dir Root of the render cache for `"quarto"` tutorials
#'   (ignored for an `"rmarkdown"` one). Each tutorial is rendered into
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
#'   why. When `FALSE`, a `"quarto"` tutorial is rendered (or found in the
#'   cache) and its path returned without serving or blocking; an
#'   `"rmarkdown"` tutorial has no render-only mode (it is a Shiny app), so
#'   `open = FALSE` is an error for one. Note that under `Rscript` the
#'   default is `FALSE`, so pass `open = TRUE` explicitly there.
#' @param refresh Re-render a `"quarto"` tutorial even if the cached render
#'   is current. Defaults to `FALSE`.
#'
#' @return Path to the rendered HTML file for a `"quarto"` tutorial, or to
#'   the `.Rmd` source for an `"rmarkdown"` one, invisibly.
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
#' @section Classic learnr tutorials:
#' Many existing content packages (those built on 'tutorial.helpers', for
#' instance) bundle classic 'learnr' tutorials: `.Rmd` files with
#' `runtime: shiny_prerendered` that run as a Shiny app in the local R
#' session. learnr2 cannot run those itself -- the Shiny machinery lives in
#' 'learnr' -- so for an `"rmarkdown"` tutorial this function calls
#' `learnr::run_tutorial(name, package = package)`, which blocks while the
#' app runs just as the `"quarto"` path blocks while serving.
#'
#' 'learnr' is only a suggested dependency of learnr2, not a required one,
#' because a package that bundles classic learnr tutorials already depends
#' on 'learnr' itself (directly, or via 'tutorial.helpers'). So whenever an
#' `"rmarkdown"` tutorial is installed, 'learnr' is too; this function only
#' errors with an install hint if that invariant is somehow broken.
#'
#' @seealso [prerender_tutorials()] to fill the render cache in advance.
#' @export
#' @examples
#' # With no `name`, just lists the tutorials that can be run.
#' run_tutorial()
#'
#' # Not run: needs the Quarto command line tool, and, when `open = TRUE`,
#' # starts a local web server that blocks the session until interrupted.
#' \dontrun{
#' run_tutorial("hello-learnr2")
#'
#' # Force a re-render even though the cached copy is current.
#' run_tutorial("hello-learnr2", refresh = TRUE)
#'
#' # A classic learnr tutorial from a content package is handed to learnr.
#' run_tutorial("hello", package = "learnr", open = TRUE)
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
    stop("Unknown tutorial: ", name, " in package ", package, ".\nAvailable: ",
         paste(tutorials$name, collapse = ", "), call. = FALSE)
  }
  tutorial <- tutorials[tutorials$name == name, , drop = FALSE]

  if (is.na(tutorial$format)) {
    stop("Tutorial ", name, " in package ", package,
         " has no .qmd or .Rmd document to run.", call. = FALSE)
  }
  if (identical(tutorial$format, "rmarkdown")) {
    return(run_learnr_tutorial(name, package, tutorial$path, open))
  }

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
#' current are skipped. Classic `"rmarkdown"` tutorials are not rendered:
#' they are Shiny apps and have nothing to cache.
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
#' \dontrun{
#' # Everything installed, into the default per-user cache.
#' prerender_tutorials()
#'
#' # One package, forcing a rebuild.
#' prerender_tutorials(package = "learnr2", refresh = TRUE)
#' }
prerender_tutorials <- function(package = NULL,
                                output_dir = tools::R_user_dir("learnr2", "cache"),
                                refresh = FALSE) {
  tutorials <- available_tutorials(package = package, type = "quarto")
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

# Serve the cache root on the fixed port and open `tutorial`'s address --
# or, if a learnr2 server is already serving that root, just open it there.
serve_tutorial <- function(tutorial, root) {
  port <- learnr2_port()
  url <- tutorial_url(tutorial$package, tutorial$name, port)
  root <- as.character(fs::path_abs(root))

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
    open_in_browser(url)
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
  open_in_browser(url)
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

# What, if anything, answers on `port`: list(state, server) with state one
# of "free" (nothing listening), "learnr2" (a learnr2 server; `server` is
# its marker, with the root it serves) or "other" (something else).
probe_server <- function(port) {
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
    warning = function(w) classify_probe_failure(conditionMessage(w)),
    error = function(e) classify_probe_failure(conditionMessage(e))
  )
}

# base::url() reports "Couldn't connect to server" / "Connection refused"
# when nothing is listening; an HTTP error status, a timeout or a parse
# failure all mean something is listening that is not a learnr2 server.
classify_probe_failure <- function(msg) {
  if (grepl("connect", msg, ignore.case = TRUE) || grepl("refused", msg, ignore.case = TRUE)) {
    list(state = "free", server = NULL)
  } else {
    list(state = "other", server = NULL)
  }
}

# Seams around the two things a unit test must never do for real: open a
# browser, and block in httpuv's event loop until interrupted.
open_in_browser <- function(url) {
  tryCatch(
    utils::browseURL(url),
    error = function(e) message("Could not open a browser (", conditionMessage(e), "); open ", url, " yourself.")
  )
}

block_serving <- function() {
  httpuv::service(0)
}

# ---------------------------------------------------------------------------
# Classic learnr tutorials
# ---------------------------------------------------------------------------

# The "rmarkdown" branch of run_tutorial(): a classic learnr tutorial, which
# only learnr can run (it is a Shiny app). See the "Classic learnr tutorials"
# section of ?run_tutorial for why learnr is merely Suggested.
run_learnr_tutorial <- function(name, package, path, open) {
  if (!learnr_installed()) {
    stop(
      "Tutorial \"", name, "\" in package \"", package, "\" is a classic ",
      "learnr tutorial (an .Rmd run as a Shiny app), which needs the learnr ",
      "package. Install it with: install.packages(\"learnr\")",
      call. = FALSE
    )
  }
  if (!isTRUE(open)) {
    stop(
      "Tutorial \"", name, "\" in package \"", package, "\" is a classic ",
      "learnr tutorial, which runs as a Shiny app and cannot be rendered ",
      "without being served. Call run_tutorial() with open = TRUE.",
      call. = FALSE
    )
  }
  message(
    "\"", name, "\" is a classic learnr tutorial; handing it to ",
    "learnr::run_tutorial().\n",
    "Press Ctrl+C (or the console's Stop button) to stop it."
  )
  learnr_run_tutorial(name, package)
  invisible(as.character(path))
}
