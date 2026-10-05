# Ported from the 'tutorial.helpers' package (R/show_file.R), with its tests
# and fixtures, so learnr2 users do not need tutorial.helpers installed.

#' Remove embedded pagedtable HTML artifacts from a vector of lines
#'
#' VS Code's interactive chunk execution can cache a chunk's rendered output
#' directly back into the .qmd/.Rmd source file. When the chunk's output is a
#' tibble, that cached output is a pagedtable HTML widget (a `<div
#' data-pagedtable="false">` block wrapping a `<script
#' data-pagedtable-source>` JSON blob). Because this cached output can end up
#' inside the same fenced region as the code itself, show_file()'s chunk
#' extraction can otherwise return this HTML noise instead of clean source
#' code. This helper strips any such blocks out of a character vector of
#' lines before they are printed.
#'
#' @param lines A character vector of lines (as returned by readLines()).
#' @return A character vector with any pagedtable HTML blocks removed.
#' @noRd
strip_pagedtable_html <- function(lines) {
  if (length(lines) == 0) {
    return(lines)
  }

  keep <- rep(TRUE, length(lines))
  depth <- 0
  in_block <- FALSE

  for (i in seq_along(lines)) {
    line <- lines[i]

    # A pagedtable block always starts with a <div data-pagedtable...> tag.
    if (!in_block && grepl("^\\s*<div\\s+data-pagedtable", line)) {
      in_block <- TRUE
      depth <- 0
    }

    if (in_block) {
      keep[i] <- FALSE
      # Track nested <div ...> / </div> tags so we find the *matching*
      # closing tag rather than the first </div> we see.
      depth <- depth + lengths(regmatches(line, gregexpr("<div\\b", line)))
      depth <- depth - lengths(regmatches(line, gregexpr("</div>", line)))
      if (depth <= 0) {
        in_block <- FALSE
      }
    }
  }

  lines[keep]
}

#' Display all or part of a text file
#'
#' Prints a text file -- or the part of it an author most often wants to see
#' -- to the console. By default (`chunk = "auto"`), a file containing fenced
#' code chunks (a `.qmd` or `.Rmd`) shows just its *last* code chunk, which is
#' by far the most common use ("show me the code you just wrote"), while a
#' file with no code chunks (a `.gitignore`, `.yml`, `.R`, ...) is shown
#' whole. Everything else is opt-in: a row range, a regular-expression
#' filter, all chunks, one chunk picked out by its label, or the YAML header.
#'
#' @details
#' The arguments are resolved in a fixed order. `chunk = "YAML"` is handled
#' first; then `start == 0` (whole file); then `start < 0` (the last
#' `abs(start)` lines); then `chunk` when it selects code chunks (`"All"`,
#' `"Last"`, or a label); and finally the `start`/`end` row range. The
#' `pattern` filter applies within the whole-file, last-lines, and row-range
#' cases, and is ignored when `chunk` selects code chunks or the YAML header.
#'
#' `chunk = "auto"` resolves to `"Last"` only when the file contains at least
#' one fenced code chunk *and* none of `start`, `end`, or `pattern` were
#' supplied. Passing any of those three is taken as a request to see rows,
#' not chunks, so e.g. `show_file("analysis.qmd", end = 4)` always means the
#' first four lines, and `show_file("analysis.qmd", pattern = "library")`
#' always searches the whole file.
#'
#' A chunk's label is read from any of the usual places: the positional
#' label in the fence header (```` ```{r setup} ````), a `label =` option in
#' the header (```` ```{r, label = "setup"} ````), or a `#| label: setup`
#' line inside the chunk. Chunks of any language are recognized (`r`,
#' `python`, `bash`, ...), not just R.
#'
#' Rendered output that VS Code's interactive chunk execution caches back
#' into a `.qmd` file (a pagedtable HTML widget) is stripped before anything
#' is printed, so a chunk shows only its source.
#'
#' @param path Path to the text file.
#' @param start Integer: the first row (inclusive) to show. Default is 1.
#'   If negative, show the last `abs(start)` lines of the file instead. If 0,
#'   show the entire file. Supplying `start` switches `chunk = "auto"` off.
#' @param end Integer: the last row (inclusive) to show. Default is the last
#'   row of the file. Supplying `end` switches `chunk = "auto"` off.
#' @param pattern A regular expression; only rows matching it are shown.
#'   Default is `NULL` (no filtering). Applied to the whole-file
#'   (`start == 0`), last-lines (`start < 0`), and row-range cases; ignored
#'   when `chunk` selects code chunks or the YAML header. Supplying
#'   `pattern` switches `chunk = "auto"` off.
#' @param chunk What to show. One of:
#'   * `"auto"` (the default): the last code chunk if the file has any and
#'     no row arguments were given; otherwise the whole file.
#'   * `"None"`: no chunk processing; show rows (the whole file by default).
#'   * `"All"`: the code of every chunk, separated by blank lines.
#'   * `"Last"`: the code of the last chunk only.
#'   * `"YAML"`: the YAML header, without its `---` delimiters.
#'   * Any other string: the code of the chunk with that label. It is an
#'     error if no chunk has that label.
#' @return Called for its side effect of printing to the console; returns
#'   `NULL`, invisibly. Prints nothing if no rows match `pattern`, or if the
#'   selected chunk is empty. A file that is empty, or contains only blank
#'   lines, prints `File is empty.`
#'
#' @examples
#' # A small Quarto document to look at:
#' qmd <- tempfile(fileext = ".qmd")
#' writeLines(c(
#'   "---",
#'   "title: \"An example\"",
#'   "---",
#'   "Some prose, with an example in it.",
#'   "```{r setup}",
#'   "library(dplyr)",
#'   "x <- 1:10",
#'   "```",
#'   "More prose.",
#'   "```{r}",
#'   "#| label: summary",
#'   "mean(x)",
#'   "```"
#' ), qmd)
#'
#' # The default shows the last code chunk, the most common thing to want
#' show_file(qmd)
#'
#' # Every chunk, or one picked out by its label
#' show_file(qmd, chunk = "All")
#' show_file(qmd, chunk = "setup")
#' show_file(qmd, chunk = "summary")
#'
#' # The YAML header, without its delimiters
#' show_file(qmd, chunk = "YAML")
#'
#' # Rows instead of chunks: the whole file, a range, a filter, the tail
#' show_file(qmd, chunk = "None")
#' show_file(qmd, start = 4, end = 8)
#' show_file(qmd, pattern = "example")
#' show_file(qmd, start = -3)
#'
#' # A file with no code chunks is shown whole by default
#' gitignore <- tempfile(fileext = ".gitignore")
#' writeLines(c(".Rproj.user", ".Rhistory", "*.html"), gitignore)
#' show_file(gitignore)
#'
#' unlink(c(qmd, gitignore))
#' @export
show_file <- function(path, start = 1, end = NULL, pattern = NULL, chunk = "auto") {
  if (!file.exists(path)) {
    stop("File does not exist.", call. = FALSE)
  }

  keyword_chunks <- c("auto", "None", "All", "Last", "YAML")
  if (!is.character(chunk) || length(chunk) != 1 || is.na(chunk) || !nzchar(chunk)) {
    stop(
      "`chunk` must be a single string: one of ",
      paste0('"', keyword_chunks, '"', collapse = ", "),
      ", or a chunk label.",
      call. = FALSE
    )
  }

  # Any explicit row argument means "show me rows", so "auto" must not turn
  # into "Last" underneath it. Decided here, before `start`/`end`/`pattern`
  # are touched, since missing() only answers for the original call.
  rows_requested <- !missing(start) || !missing(end) || !missing(pattern)

  contents <- readLines(path)

  # VS Code's interactive chunk execution can cache a chunk's rendered
  # output directly back into the .qmd/.Rmd source file. When the chunk's
  # output is a tibble, that cached output is a pagedtable HTML widget (a
  # `<div data-pagedtable="false">` block wrapping a `<script
  # data-pagedtable-source>` JSON blob), and it can end up inside the same
  # fenced region as the code itself. Strip any such blocks here, up front,
  # so every code path below (YAML, whole-file, tail, chunk extraction, and
  # row-range) sees clean source text rather than rendered-output noise.
  contents <- strip_pagedtable_html(contents)

  # Remove trailing empty lines from the contents
  while (length(contents) > 0 && contents[length(contents)] == "") {
    contents <- contents[-length(contents)]
  }

  if (length(contents) == 0) {
    cat("File is empty.\n")
    return(invisible(NULL))
  }

  if (chunk == "auto") {
    chunk <- if (!rows_requested && has_code_chunks(contents)) "Last" else "None"
  }

  # If chunk is "YAML", extract and return the YAML header
  if (chunk == "YAML") {
    if (!grepl("^---\\s*$", contents[1])) {
      stop("No YAML header found.", call. = FALSE)
    }

    # Find the closing --- for the YAML header. seq_len(length(contents))[-1]
    # gives the indices from 2 to the end, and is empty (rather than c(2, 1))
    # when the file has only a single line.
    yaml_end <- NULL
    for (i in seq_len(length(contents))[-1]) {
      if (grepl("^---\\s*$", contents[i])) {
        yaml_end <- i
        break
      }
    }

    if (is.null(yaml_end)) {
      stop("No YAML header found.", call. = FALSE)
    }

    # Extract YAML content (excluding the --- delimiters)
    if (yaml_end > 2) {
      yaml_content <- contents[2:(yaml_end - 1)]
      cat(yaml_content, sep = "\n")
    }
    return(invisible(NULL))
  }

  # If start is 0, print the entire file
  if (start == 0) {
    selected_contents <- contents
    if (!is.null(pattern)) {
      selected_contents <- selected_contents[grepl(pattern, selected_contents)]
    }
    if (length(selected_contents) > 0) {
      cat(selected_contents, sep = "\n")
    }
    return(invisible(NULL))
  }

  # If start is negative, print the last abs(start) lines
  if (start < 0) {
    selected_contents <- utils::tail(contents, abs(start))
    if (!is.null(pattern)) {
      selected_contents <- selected_contents[grepl(pattern, selected_contents)]
    }
    if (length(selected_contents) > 0) {
      cat(selected_contents, sep = "\n")
    }
    return(invisible(NULL))
  }

  # "All", "Last", or a chunk label: print code from inside the fences.
  if (chunk != "None") {
    code_chunks <- extract_code_chunks(contents)

    if (chunk == "All") {
      for (i in seq_along(code_chunks)) {
        cat(code_chunks[[i]]$code, sep = "\n")
        if (i < length(code_chunks)) {
          cat("\n")
        }
      }
    } else if (chunk == "Last") {
      if (length(code_chunks) > 0) {
        cat(code_chunks[[length(code_chunks)]]$code, sep = "\n")
      }
    } else {
      labels <- vapply(code_chunks, function(ch) ch$label, character(1))
      hit <- which(labels == chunk)
      if (length(hit) == 0) {
        stop(
          "No code chunk labelled \"", chunk, "\" found in ", path, ". ",
          "(To select by position instead, use chunk = \"Last\" or \"All\".)",
          call. = FALSE
        )
      }
      cat(code_chunks[[hit[1]]]$code, sep = "\n")
    }
    return(invisible(NULL))
  }

  # Get the total number of rows
  total_rows <- length(contents)

  # Set default value for end if not provided
  if (is.null(end)) {
    end <- total_rows
  }

  # Check if start and end are within the valid range
  if (start < 1 || start > total_rows || end < 1 || end > total_rows) {
    stop("start and end must be within the valid range of rows.", call. = FALSE)
  }

  # Check if start is smaller or equal to end
  if (start > end) {
    stop("start must be smaller or equal to end.", call. = FALSE)
  }

  # Extract the specified range of rows
  selected_contents <- contents[start:end]

  # Filter the selected rows based on the pattern (if provided)
  if (!is.null(pattern)) {
    selected_contents <- selected_contents[grepl(pattern, selected_contents)]
  }

  # Print the selected contents to the console if there are matching rows
  if (length(selected_contents) > 0) {
    cat(selected_contents, sep = "\n")
  }
  invisible(NULL)
}

# An opening fence of any language: ```{r}, ```{r label, opts}, ```{python}...
chunk_fence_regex <- "^```\\{"

has_code_chunks <- function(lines) {
  any(grepl(chunk_fence_regex, lines))
}

# Split `lines` into the code chunks between ```{...} / ``` fences. Returns
# a list of list(label = <string, "" if unlabelled>, code = <character>),
# in document order. An opening fence met while already inside a chunk (a
# missing closing fence) closes the previous chunk, matching the original
# tutorial.helpers behaviour; a closing fence is ``` plus optional trailing
# whitespace. Empty chunks are dropped.
extract_code_chunks <- function(lines) {
  chunks <- list()
  in_chunk <- FALSE
  current <- character()
  current_label <- ""

  flush <- function() {
    if (length(current) > 0) {
      label <- current_label
      # A `#| label: x` line inside the chunk wins over the fence header.
      opt <- grep("^#\\|\\s*label\\s*:", current, value = TRUE)
      if (length(opt) > 0) {
        label <- trimws(sub("^#\\|\\s*label\\s*:\\s*", "", opt[1]))
        label <- gsub("^[\"']|[\"']$", "", label)
      }
      chunks[[length(chunks) + 1]] <<- list(label = label, code = current)
    }
    current <<- character()
    current_label <<- ""
  }

  for (line in lines) {
    if (grepl(chunk_fence_regex, line)) {
      flush()
      in_chunk <- TRUE
      current_label <- fence_label(line)
    } else if (grepl("^```\\s*$", line)) {
      flush()
      in_chunk <- FALSE
    } else if (in_chunk) {
      current <- c(current, line)
    }
  }
  flush()
  chunks
}

# The label named in an opening fence, or "" if there is none. Handles
# ```{r label}, ```{r label, opts}, ```{r, label = "x"}, ```{r label="x"}.
fence_label <- function(fence) {
  inner <- sub("^```\\{([^}]*)\\}.*$", "\\1", fence)
  # Explicit label = option, anywhere in the header, quoted or not.
  # Note [[:space:]], not \s: inside a bracket expression R's default (TRE)
  # regex engine treats \s as the two literal characters "\" and "s".
  m <- regmatches(inner, regexec("label[[:space:]]*=[[:space:]]*[\"']?([^\"',}[:space:]]+)", inner))[[1]]
  if (length(m) == 2) {
    return(m[2])
  }
  # Otherwise the positional label: the token after the engine name, as
  # long as it isn't itself an `opt = value` pair.
  rest <- sub("^\\s*[A-Za-z0-9_.]+", "", inner)   # drop engine
  rest <- sub("^\\s*,?\\s*", "", rest)             # drop separator
  first <- sub("[,[:space:]].*$", "", rest)        # first token
  if (nzchar(first) && !grepl("=", first)) first else ""
}
