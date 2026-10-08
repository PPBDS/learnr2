#' Render tutorials, as a test that they build
#'
#' Renders each tutorial with Quarto, exactly the way [run_tutorial()] and
#' the package's own GitHub Pages publishing do: the tutorial's directory is
#' copied under `output_dir`, the bundled 'quarto-live' extension is added
#' next to the copy with [add_live_extension()], and the copy is rendered
#' with [quarto::quarto_render()]. A tutorial that fails to render stops with
#' an error naming it. This is the learnr2 counterpart of
#' `tutorial.helpers::knit_tutorials()`: "testing" a tutorial means
#' confirming it renders without error, which catches a large class of
#' mistakes that look fine in the `.qmd` source (see also [check_tutorial()]
#' for the static checks that complement it).
#'
#' Nothing here boots WebR or exercises the rendered page in a browser --
#' that happens in the reader's browser, not at render time -- so a
#' successful render proves the document builds, not that every exercise
#' behaves. Each tutorial's render time is reported, since a slow one is
#' usually the first sign of something that will also be slow for readers.
#'
#' @param paths Character vector of tutorials to render: paths to `.qmd`
#'   files, or to the directories that contain them (the first `.qmd` in
#'   each directory is used). [available_tutorials()]'s `path` column and
#'   [create_tutorial()]'s return value are both accepted directly.
#' @param output_dir Directory to render into. Each tutorial is copied to
#'   `output_dir/<tutorial-directory-name>/` first, so the installed source
#'   is never written to. Defaults to a fresh directory under the session's
#'   temporary directory, which is also the only place CRAN permits a test
#'   to write.
#' @param quiet Passed to [quarto::quarto_render()]. Defaults to `TRUE`;
#'   set `FALSE` to see Quarto's own progress output, e.g. in CI logs.
#'
#' @return A character vector of paths to the rendered `.html` files, named
#'   by tutorial (the directory name), invisibly.
#' @export
#' @section In a content package's tests:
#' A package of tutorials can check every one of them from
#' `tests/testthat/test-tutorials.R`:
#'
#' ```r
#' tutorials <- available_tutorials(package = "my.tutorials")
#' render_tutorials(tutorials$path)
#' check_tutorial(tutorials$path)
#' ```
#'
#' Guard that test with `testthat::skip_on_cran()` and
#' `testthat::skip_if(is.null(quarto::quarto_path()))`, since it needs the
#' Quarto command line tool.
#'
#' @examples
#' # Scaffold a tutorial, then render it the way a test would. Needs the
#' # Quarto command line tool, so this is skipped where it isn't installed.
#' if (!is.null(quarto::quarto_path())) {
#'   dir <- tempfile()
#'   qmd <- create_tutorial("render-me", dir = dir, open = FALSE)
#'   html <- render_tutorials(qmd)
#'   file.exists(html)
#'   unlink(c(dir, dirname(html)), recursive = TRUE)
#' }
render_tutorials <- function(paths,
                             output_dir = tempfile("learnr2-render-"),
                             quiet = TRUE) {
  qmds <- resolve_tutorial_paths(paths)
  output_dir <- fs::path_abs(output_dir)
  fs::dir_create(output_dir)

  rendered <- character(0)
  for (qmd in qmds) {
    src_dir <- fs::path_dir(qmd)
    name <- fs::path_file(src_dir)
    work_dir <- fs::path(output_dir, name)

    # fs::dir_copy() copies the *contents* of `src_dir` into the destination,
    # so pointing it at `work_dir` gives work_dir/<name>.qmd (plus images/,
    # or anything else the tutorial keeps beside its .qmd).
    fs::dir_copy(src_dir, work_dir, overwrite = TRUE)
    add_live_extension(work_dir)
    qmd_copy <- fs::path(work_dir, fs::path_file(qmd))

    message("Rendering ", name, " (", qmd, ") ...")
    started <- Sys.time()
    tryCatch(
      quarto::quarto_render(input = as.character(qmd_copy), quiet = quiet),
      error = function(e) {
        stop("Failed to render ", qmd, ": ", conditionMessage(e), call. = FALSE)
      }
    )
    html <- fs::path_ext_set(qmd_copy, "html")
    if (!fs::file_exists(html)) {
      stop("Rendering ", qmd, " produced no ", fs::path_file(html), ".", call. = FALSE)
    }
    elapsed <- round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1)
    message("Rendered ", name, " in ", elapsed, "s: ", html)

    rendered[name] <- as.character(html)
  }

  message("Rendered ", length(rendered), " tutorial(s).")
  invisible(rendered)
}

# Normalise `paths` (files and/or directories) to the .qmd files they denote,
# erroring on anything that isn't a tutorial. Shared by render_tutorials()
# and check_tutorial().
resolve_tutorial_paths <- function(paths) {
  if (!is.character(paths) || anyNA(paths)) {
    stop("`paths` must be a character vector of tutorial paths.", call. = FALSE)
  }
  if (length(paths) == 0) {
    return(character(0))
  }
  missing_paths <- paths[!fs::file_exists(paths)]
  if (length(missing_paths) > 0) {
    stop("Tutorial path(s) not found: ", paste(missing_paths, collapse = ", "),
         call. = FALSE)
  }
  vapply(paths, function(p) {
    if (fs::is_dir(p)) {
      doc <- tutorial_doc(p)
      if (is.na(doc) || !identical(fs::path_ext(doc), "qmd")) {
        stop("No .qmd tutorial found in directory ", p, ".", call. = FALSE)
      }
      return(as.character(fs::path_abs(doc)))
    }
    if (!identical(tolower(fs::path_ext(p)), "qmd")) {
      stop("Not a .qmd tutorial: ", p, ".", call. = FALSE)
    }
    as.character(fs::path_abs(p))
  }, character(1), USE.NAMES = FALSE)
}
