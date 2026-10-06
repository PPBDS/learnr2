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
#' (learnr2's own format) is rendered to `output_dir` and, when `open` is
#' `TRUE`, served to a browser. Because installed tutorials live in a
#' read-only package library, the tutorial is copied to a writable location
#' and the 'quarto-live' extension is added before rendering. An
#' `"rmarkdown"` tutorial -- a classic 'learnr' tutorial -- is handed to
#' `learnr::run_tutorial()`, so a tool built on learnr2 (such as the "R
#' Tutorials" VS Code extension) can run both kinds through this one function
#' and depend only on learnr2. See the section below.
#'
#' @param name Name of the tutorial to run. See [available_tutorials()]. If
#'   `NULL`, the available tutorials in `package` are listed.
#' @param package Name of the package the tutorial is bundled with. Defaults
#'   to `"learnr2"`; set this to run a tutorial from another installed
#'   package (e.g. a 'primer.tutorials'-style content package), or from one
#'   loaded with `pkgload::load_all()` (see [available_tutorials()]).
#' @param output_dir Directory in which to render a `"quarto"` tutorial
#'   (ignored for an `"rmarkdown"` one). Defaults to a persistent per-user
#'   cache directory (see [tools::R_user_dir()]), *not* [tempfile()] -- R
#'   deletes its own session temp directory as soon as the R process exits,
#'   which races with (and often loses to) the browser actually loading the
#'   page when `open = TRUE` is used non-interactively (e.g. via `Rscript`),
#'   producing a "file not found" page. Pass your own `output_dir` for a
#'   one-off location instead.
#' @param open Whether to serve the tutorial and open it in a browser.
#'   Defaults to `TRUE` when interactive. When `TRUE`, this call blocks (like
#'   [httpuv::runStaticServer()] or `shiny::runApp()`) until you interrupt it
#'   (Ctrl+C, or the console's Stop button) -- see the section below for why.
#'   When `FALSE`, a `"quarto"` tutorial is rendered and its path returned
#'   without serving or blocking; an `"rmarkdown"` tutorial has no
#'   render-only mode (it is a Shiny app), so `open = FALSE` is an error.
#'   Note that under `Rscript` the default is `FALSE`, so pass `open = TRUE`
#'   explicitly there.
#'
#' @return Path to the rendered HTML file for a `"quarto"` tutorial, or to
#'   the `.Rmd` source for an `"rmarkdown"` one, invisibly.
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
#' publishing script uses, and serves the result with
#' [httpuv::runStaticServer()] -- an in-process server with no separate
#' daemon to lose track of. Its trade-off is that it blocks the caller
#' while serving, matching how the original 'learnr' package's
#' `run_tutorial()` (built on a blocking Shiny app) behaved -- stop the
#' server to get your prompt back.
#'
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
#' # A classic learnr tutorial from a content package is handed to learnr.
#' run_tutorial("hello", package = "learnr", open = TRUE)
#' }
run_tutorial <- function(name = NULL,
                         package = "learnr2",
                         output_dir = tools::R_user_dir("learnr2", "cache"),
                         open = interactive()) {
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

  src <- pkg_file("tutorials", name, package = package)
  output_dir <- fs::path_abs(output_dir)

  # render_tutorials() copies `src` to output_dir/<name>/, adds the
  # quarto-live extension there, and renders -- the same steps the package's
  # own Pages publishing and a content package's tests use.
  html <- render_tutorials(src, output_dir = output_dir)[[1]]
  work_dir <- fs::path_dir(html)

  if (!isTRUE(open)) {
    return(invisible(as.character(html)))
  }

  # See "Why this blocks and serves over local HTTP instead of opening the
  # file directly" above. httpuv's static server has no index.html of its
  # own to fall back to, so it would otherwise open to a bare directory
  # listing -- copy the rendered file over so browse = TRUE lands directly
  # on the tutorial.
  fs::file_copy(html, fs::path(work_dir, "index.html"), overwrite = TRUE)

  message(
    "Serving ", work_dir, "\n",
    "Press Ctrl+C (or the console's Stop button) to stop the server."
  )
  httpuv::runStaticServer(as.character(work_dir), browse = TRUE, background = FALSE)

  invisible(as.character(html))
}

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
