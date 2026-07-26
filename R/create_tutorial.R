#' Create a new learnr2 tutorial
#'
#' Scaffolds a new interactive tutorial: a directory containing a starter
#' `.qmd` document wired up for `format: live-html`, with the bundled
#' 'quarto-live' extension copied alongside it so it renders out of the box.
#' The starter document opens with [student_info()] and ends with a
#' "how many minutes did this take" question plus
#' [download_answers_button()], so every new tutorial collects name/email
#' (and an optional ID) and lets the reader turn in their answers by
#' default; delete either section if a given tutorial doesn't need it.
#'
#' @param name Name of the tutorial. Used for the directory and the `.qmd`
#'   file name, so it should be a valid file name (e.g. `"my-tutorial"`).
#' @param dir Parent directory in which to create the tutorial directory.
#'   Defaults to the current working directory.
#' @param title Human-readable title placed in the document's YAML header.
#'   Defaults to `name`.
#' @param open Whether to open the new `.qmd` file in an interactive session.
#'   Defaults to `TRUE` when interactive.
#'
#' @return The path to the created `.qmd` file, invisibly.
#' @export
#' @examples
#' \dontrun{
#' create_tutorial("my-first-tutorial")
#' }
create_tutorial <- function(name,
                            dir = ".",
                            title = name,
                            open = interactive()) {
  if (missing(name) || !is.character(name) || length(name) != 1 || !nzchar(name)) {
    stop("`name` must be a single non-empty string.", call. = FALSE)
  }

  tutorial_dir <- fs::path(fs::path_abs(dir), name)
  if (fs::dir_exists(tutorial_dir) &&
      length(fs::dir_ls(tutorial_dir)) > 0) {
    stop("Directory already exists and is not empty: ", tutorial_dir,
         call. = FALSE)
  }
  fs::dir_create(tutorial_dir)

  template <- readLines(
    system.file("templates", "tutorial.qmd", package = "learnr2"),
    encoding = "UTF-8"
  )
  contents <- gsub("{{title}}", title, template, fixed = TRUE)
  contents <- gsub("{{name}}", name, contents, fixed = TRUE)

  qmd <- fs::path(tutorial_dir, name, ext = "qmd")
  writeLines(contents, qmd, useBytes = TRUE)

  add_live_extension(tutorial_dir)

  message("Created tutorial: ", qmd)
  if (isTRUE(open)) {
    open_file(qmd)
  }
  invisible(qmd)
}

# Best-effort open of a file in the user's editor / RStudio.
open_file <- function(path) {
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable() &&
      rstudioapi::hasFun("navigateToFile")) {
    rstudioapi::navigateToFile(path)
  } else if (nzchar(Sys.getenv("RSTUDIO"))) {
    utils::file.edit(path)
  } else {
    utils::browseURL(path)
  }
  invisible(path)
}
