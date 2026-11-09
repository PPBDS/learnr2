# Small helpers used throughout the package.

`%||%` <- function(x, y) if (is.null(x)) y else x

# One non-empty, non-NA string?
is_string <- function(x) {
  is.character(x) && length(x) == 1 && !is.na(x) && nzchar(x)
}

# Stop unless `x` is one non-empty string; `name` is the argument's name in
# the message.
check_string <- function(x, name) {
  if (!is_string(x)) {
    stop("`", name, "` must be a single non-empty string.", call. = FALSE)
  }
  invisible(x)
}

# `x` may be NULL (meaning "use the default") or one non-empty string.
check_label <- function(x, name) {
  if (!is.null(x) && !is_string(x)) {
    stop("`", name, "` must be NULL or a single non-empty string.", call. = FALSE)
  }
  invisible(TRUE)
}
