#' List tutorials bundled with learnr2 (or any installed package)
#'
#' Scans one package -- or, by default, every package installed -- for a
#' bundled `inst/tutorials/` directory, the same convention 'learnr' uses.
#' This lets tools like the "R Tutorials" VS Code extension discover
#' tutorials from separately-installed content packages (in the style of
#' 'primer.tutorials') without knowing their names in advance.
#'
#' @param package Name of a single package to scan. Defaults to `NULL`,
#'   which scans every installed package.
#' @param type Which authoring format to include: `"quarto"` (tutorials
#'   whose top-level document is a `.qmd`), `"rmarkdown"` (a `.Rmd`), or
#'   `"all"` (the default) for both.
#'
#' @return A data frame with one row per tutorial and columns `package`,
#'   `name`, `title` (`NA` if the tutorial's `.qmd`/`.Rmd` has no YAML
#'   `title`), and `format` (`"quarto"` or `"rmarkdown"`). `name` can be
#'   passed to [run_tutorial()].
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
    if (!nzchar(system.file(package = package))) {
      stop("No package found with name: \"", package, "\".", call. = FALSE)
    }
    packages <- package
  } else {
    packages <- rownames(utils::installed.packages())
  }

  rows <- lapply(packages, tutorials_in_package)
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(data.frame(
      package = character(0),
      name = character(0),
      title = character(0),
      format = character(0),
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
  root <- system.file("tutorials", package = pkg)
  if (!nzchar(root)) {
    return(NULL)
  }
  dirs <- fs::dir_ls(root, type = "directory")
  if (length(dirs) == 0) {
    return(NULL)
  }
  docs <- lapply(dirs, tutorial_doc)
  data.frame(
    package = pkg,
    name = fs::path_file(dirs),
    title = vapply(docs, tutorial_title, character(1), USE.NAMES = FALSE),
    format = vapply(docs, tutorial_format, character(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
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

#' Render and open a bundled tutorial
#'
#' Renders a tutorial bundled with an installed package to a temporary
#' directory and, in an interactive session, opens the result in a browser.
#' Because installed tutorials live in a read-only package library, the
#' tutorial is copied to a writable location and the 'quarto-live' extension
#' is added before rendering.
#'
#' @param name Name of the tutorial to run. See [available_tutorials()]. If
#'   `NULL`, the available tutorials in `package` are listed.
#' @param package Name of the package the tutorial is bundled with. Defaults
#'   to `"learnr2"`; set this to run a tutorial from another installed
#'   package (e.g. a 'primer.tutorials'-style content package).
#' @param output_dir Directory in which to render the tutorial. Defaults to a
#'   persistent per-user cache directory (see [tools::R_user_dir()]), *not*
#'   [tempfile()] -- R deletes its own session temp directory as soon as the
#'   R process exits, which races with (and often loses to) the browser
#'   actually loading the page when `open = TRUE` is used non-interactively
#'   (e.g. via `Rscript`), producing a "file not found" page. Pass your own
#'   `output_dir` for a one-off location instead.
#' @param open Whether to serve the rendered tutorial and open it in a
#'   browser. Defaults to `TRUE` when interactive. When `TRUE`, this call
#'   blocks (like [httpuv::runStaticServer()] or `shiny::runApp()`) until you
#'   interrupt it (Ctrl+C, or the console's Stop button) -- see the section
#'   below for why. When `FALSE`, the tutorial is rendered and the path
#'   returned without serving or blocking.
#'
#' @return Path to the rendered HTML file, invisibly.
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
#' \dontrun{
#' run_tutorial("hello-learnr2")
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

  src <- system.file("tutorials", name, package = package)
  output_dir <- fs::path_abs(output_dir)
  fs::dir_create(output_dir)

  # fs::dir_copy() copies the *contents* of `src` into the destination,
  # so point it at `work_dir` directly to get work_dir/<name>.qmd.
  work_dir <- fs::path(output_dir, name)
  fs::dir_copy(src, work_dir, overwrite = TRUE)

  add_live_extension(work_dir)

  qmd <- fs::dir_ls(work_dir, glob = "*.qmd")[1]
  quarto::quarto_render(input = as.character(qmd), quiet = TRUE)

  html <- fs::path_ext_set(qmd, "html")
  message("Rendered: ", html)

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
