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
#'   Required: there is no default, so nothing is written anywhere you did
#'   not name. Pass `"."` for the current working directory.
#' @param title Human-readable title placed in the document's YAML header.
#'   Defaults to `name`.
#' @param open Whether to open the new `.qmd` file in your editor: RStudio,
#'   Positron or VS Code. Elsewhere its path is printed instead. Defaults to
#'   `TRUE` in an interactive session.
#'   Defaults to `TRUE` when interactive.
#'
#' @return The path to the created `.qmd` file, invisibly.
#' @export
#' @examples
#' # Scaffold into a temporary directory, without opening the new file.
#' dir <- tempfile()
#' qmd <- create_tutorial("my-first-tutorial", dir = dir, open = FALSE)
#' list.files(dirname(qmd), all.files = TRUE, no.. = TRUE)
#' unlink(dir, recursive = TRUE)
create_tutorial <- function(name,
                            dir,
                            title = name,
                            open = interactive()) {
  if (missing(name) || !is.character(name) || length(name) != 1 || !nzchar(name)) {
    stop("`name` must be a single non-empty string.", call. = FALSE)
  }
  check_dir_arg(dir, missing(dir))

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

# Best-effort open of a file in the user's editor, with no IDE package
# needed. RStudio and Positron both send utils::file.edit() to their editor
# (each sets an environment variable we can detect). VS Code, including a
# Codespace, puts a `code` command on the PATH of its terminals that opens a
# file in the editor. Anywhere else -- a plain terminal, where file.edit()
# would start vi -- just say where the file is. (This used to try
# rstudioapi::navigateToFile() first, which is what the RSTUDIO branch
# already does, and fall back to utils::browseURL(), which handed the .qmd
# to whatever app the operating system associates with it.)
open_file <- function(path) {
  if (nzchar(Sys.getenv("RSTUDIO")) || nzchar(Sys.getenv("POSITRON"))) {
    utils::file.edit(path)
  } else if (identical(Sys.getenv("TERM_PROGRAM"), "vscode") && has_code_command()) {
    open_in_vscode(path)
  } else {
    message("Open it in your editor: ", path)
  }
  invisible(path)
}

# Seams so tests can check the VS Code branch without running `code`
# (base functions such as Sys.which() can't be mocked).
has_code_command <- function() {
  nzchar(Sys.which("code"))
}

open_in_vscode <- function(path) {
  system2("code", shQuote(path), wait = FALSE)
}
