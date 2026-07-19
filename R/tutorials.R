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
#'
#' @return A data frame with one row per tutorial and columns `package`,
#'   `name`, and `title` (`NA` if the tutorial's `.qmd`/`.Rmd` has no YAML
#'   `title`). `name` can be passed to [run_tutorial()].
#' @export
#' @examples
#' # Qualified with learnr2:: because the learnr package exports a function of
#' # the same name; this guarantees learnr2's version is used even if learnr is
#' # also attached and masks it on the search path.
#' learnr2::available_tutorials(package = "learnr2")
available_tutorials <- function(package = NULL) {
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
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
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
  data.frame(
    package = pkg,
    name = fs::path_file(dirs),
    title = vapply(dirs, tutorial_title, character(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
}

# The YAML `title:` of the first .qmd/.Rmd directly inside `dir`, or NA.
tutorial_title <- function(dir) {
  doc <- fs::dir_ls(dir, glob = "*.qmd")
  if (length(doc) == 0) {
    doc <- fs::dir_ls(dir, glob = "*.Rmd")
  }
  if (length(doc) == 0) {
    return(NA_character_)
  }
  front_matter <- tryCatch(
    rmarkdown::yaml_front_matter(doc[1]),
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
#' @param open Whether to open the rendered HTML in a browser. Defaults to
#'   `TRUE` when interactive.
#'
#' @return Path to the rendered HTML file, invisibly.
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
  if (isTRUE(open)) {
    utils::browseURL(html)
  }
  message("Rendered: ", html)
  invisible(as.character(html))
}
