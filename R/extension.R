#' Path to the bundled 'quarto-live' extension
#'
#' learnr2 ships a copy of the 'quarto-live' Quarto extension so that authors do
#' not need to run `quarto add` themselves. This returns the path, inside the
#' installed package, to the `_extensions` directory that contains it.
#'
#' @return A length-one character path to the bundled `_extensions` directory.
#' @export
#' @examples
#' live_extension_dir()
live_extension_dir <- function() {
  path <- system.file("extdata", "_extensions", package = "learnr2")
  if (!nzchar(path)) {
    stop("Could not locate the bundled quarto-live extension. ",
         "Is learnr2 installed correctly?", call. = FALSE)
  }
  path
}

#' Add the 'quarto-live' extension to a project
#'
#' Copies the bundled 'quarto-live' extension into `dir/_extensions/` so that
#' Quarto documents in `dir` can use `format: live-html`. This is the
#' non-interactive equivalent of `quarto add r-wasm/quarto-live`.
#'
#' @param dir Directory of the Quarto project or document. Required: there
#'   is no default, so nothing is written anywhere you did not name. Pass
#'   `"."` for the current working directory.
#' @param overwrite Overwrite an existing copy of the extension? Defaults to
#'   `TRUE`.
#'
#' @return The path to the project's `_extensions` directory, invisibly.
#' @export
#' @examples
#' dir <- tempfile()
#' add_live_extension(dir)
#' list.files(dir, recursive = TRUE, all.files = TRUE)[1:3]
#' unlink(dir, recursive = TRUE)
add_live_extension <- function(dir, overwrite = TRUE) {
  check_dir_arg(dir, missing(dir))
  dir <- fs::path_abs(dir)
  fs::dir_create(dir)

  src <- fs::path(live_extension_dir(), "r-wasm")
  dest_ext <- fs::path(dir, "_extensions")
  dest <- fs::path(dest_ext, "r-wasm")

  fs::dir_create(dest_ext)
  if (fs::dir_exists(dest)) {
    if (!overwrite) {
      return(invisible(dest_ext))
    }
    fs::dir_delete(dest)
  }
  fs::dir_copy(src, dest)
  invisible(dest_ext)
}

# `dir` is deliberately not defaulted in any function that writes: CRAN
# policy forbids writing into the working directory (or anywhere under the
# user's home) unless the user named the place. `missing` is passed in by
# the caller because missing() only works on the caller's own arguments.
check_dir_arg <- function(dir, missing) {
  if (missing || !is.character(dir) || length(dir) != 1 || is.na(dir) || !nzchar(dir)) {
    stop("`dir` must be a single directory path (it has no default; pass ",
         "\".\" for the current working directory).", call. = FALSE)
  }
  invisible(dir)
}
