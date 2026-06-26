#' List tutorials bundled with learnr2
#'
#' @return A character vector of tutorial names that can be passed to
#'   [run_tutorial()].
#' @export
#' @examples
#' available_tutorials()
available_tutorials <- function() {
  root <- system.file("tutorials", package = "learnr2")
  if (!nzchar(root)) {
    return(character(0))
  }
  dirs <- fs::dir_ls(root, type = "directory")
  fs::path_file(dirs)
}

#' Render and open a bundled tutorial
#'
#' Renders one of learnr2's built-in tutorials to a temporary directory and,
#' in an interactive session, opens the result in a browser. Because installed
#' tutorials live in a read-only package library, the tutorial is copied to a
#' writable location and the 'quarto-live' extension is added before rendering.
#'
#' @param name Name of the tutorial to run. See [available_tutorials()]. If
#'   `NULL`, the available tutorials are listed.
#' @param output_dir Directory in which to render the tutorial. Defaults to a
#'   fresh temporary directory.
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
                         output_dir = tempfile("learnr2-"),
                         open = interactive()) {
  tutorials <- available_tutorials()
  if (is.null(name)) {
    message("Available tutorials:\n", paste0("  - ", tutorials, collapse = "\n"))
    return(invisible(NULL))
  }
  if (!name %in% tutorials) {
    stop("Unknown tutorial: ", name, ".\nAvailable: ",
         paste(tutorials, collapse = ", "), call. = FALSE)
  }

  src <- system.file("tutorials", name, package = "learnr2")
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
