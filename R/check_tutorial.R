#' Check that a tutorial has the recommended components
#'
#' Static checks on a tutorial's `.qmd` source for the mistakes that look
#' fine in the file and only show up later -- in the rendered page, in a
#' reader's browser, or when a reader's saved progress silently resets.
#' Each one is a rule from this package's authoring guide; this function
#' encodes them so a content package can enforce them in its tests, the way
#' `tutorial.helpers::check_tutorial_defaults()` did for 'learnr' tutorials.
#' Pair it with [render_tutorials()]: rendering proves the document builds,
#' these checks catch what a successful render does not.
#'
#' @section Checks:
#' Each check has a name, used in `skip`:
#' * `format` -- the YAML header has `format: live-html`.
#' * `engine` -- the YAML header has `engine: knitr`.
#' * `include` -- the document includes the 'quarto-live' runtime partial,
#'   `{{< include _extensions/r-wasm/live/_knitr.qmd >}}`. Without it no
#'   `{webr}` cell works.
#' * `gradethis` -- if any `{webr}` cell has `check: true`, the document also
#'   includes `_extensions/r-wasm/live/_gradethis.qmd`.
#' * `student_info` -- an `{r}` chunk calls `learnr2::student_info()`.
#' * `minutes` -- an `{r}` chunk has the "how many minutes" question, i.e. a
#'   `learnr2::question()` with `validate = "integer"`.
#' * `download` -- an `{r}` chunk calls `learnr2::download_answers_button()`.
#' * `labels` -- every `{r}` and `{webr}` chunk has its own `#| label:` line,
#'   and no two chunks share a label. A question's chunk label is the key
#'   its saved answer is stored under, so a missing or duplicated label
#'   loses or merges readers' progress.
#' * `echo` -- every `{r}` chunk that renders a learnr2 widget
#'   ([question()], [quiz()], [student_info()], [download_answers_button()],
#'   [tutorial_options()]) has `#| echo: false`, so the reader sees the
#'   widget, not the R code
#'   that produced it.
#' * `persist` -- every `{webr}` exercise cell (one with `#| exercise:` that
#'   is not a `setup`, `check`, `solution`, or `hint` cell) has
#'   `#| persist: true`, without which the reader's code is never saved and
#'   never appears in a download.
#' * `solution` -- every exercise that has a `check: true` cell also has a
#'   `solution: true` cell. A `.solution` div is not enough: the grader
#'   fails with "No solution code was found".
#' * `packages` -- every non-base package a `{webr}` cell uses (via
#'   `library()`, `require()`, or `pkg::`) is listed under `webr: packages:`
#'   in the YAML header, the only place WebR learns what to install.
#'   `gradethis` is exempt, since the `_gradethis.qmd` include provides it.
#'
#' @param paths Character vector of tutorials to check: paths to `.qmd`
#'   files, or to directories containing them, as for [render_tutorials()].
#' @param skip Character vector of check names (see "Checks") to leave out,
#'   e.g. `"minutes"` for a tutorial that deliberately has no "how many
#'   minutes" question.
#' @param error If `TRUE` (the default), stop with an error listing every
#'   problem found. If `FALSE`, just return them.
#'
#' @return A data frame of problems with columns `path`, `check`, and
#'   `message`, invisibly. It has zero rows when every check passed.
#' @export
#' @examples
#' qmd <- create_tutorial("checked", dir = tempfile(), open = FALSE)
#' check_tutorial(qmd)
#'
#' # Break the template, then see the problems instead of an error.
#' lines <- readLines(qmd)
#' writeLines(lines[!grepl("^#\\| echo: false", lines)], qmd)
#' problems <- check_tutorial(qmd, error = FALSE)
#' problems[, c("check", "message")]
#'
#' unlink(dirname(dirname(qmd)), recursive = TRUE)
check_tutorial <- function(paths, skip = NULL, error = TRUE) {
  checks <- names(tutorial_checks)
  if (!is.null(skip)) {
    unknown <- setdiff(skip, checks)
    if (!is.character(skip) || length(unknown) > 0) {
      stop("`skip` must name checks from: ", paste(checks, collapse = ", "), ".",
           call. = FALSE)
    }
    checks <- setdiff(checks, skip)
  }

  qmds <- resolve_tutorial_paths(paths)
  problems <- lapply(qmds, function(qmd) {
    doc <- parse_tutorial(qmd)
    rows <- lapply(checks, function(check) {
      msgs <- tutorial_checks[[check]](doc)
      if (length(msgs) == 0) {
        return(NULL)
      }
      data.frame(path = qmd, check = check, message = msgs, stringsAsFactors = FALSE)
    })
    do.call(rbind, rows)
  })
  problems <- do.call(rbind, problems)
  if (is.null(problems)) {
    problems <- data.frame(path = character(0), check = character(0),
                           message = character(0), stringsAsFactors = FALSE)
  }
  rownames(problems) <- NULL

  if (nrow(problems) > 0 && isTRUE(error)) {
    stop(
      nrow(problems), " problem(s) found:\n",
      paste0("  ", fs::path_file(problems$path), " [", problems$check, "] ",
             problems$message, collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(problems)
}

# ---- parsing ----------------------------------------------------------------

# Everything the checks need from one .qmd: its lines, YAML front matter
# (NULL if unparseable), and its chunks -- a list of
#   list(engine, label, options, body, line)
# where `options` is a named list of the chunk's `#| key: value` lines
# (values as strings, quotes stripped) and `body` is the remaining lines.
parse_tutorial <- function(qmd) {
  lines <- readLines(qmd, warn = FALSE, encoding = "UTF-8")
  yaml <- tryCatch(rmarkdown::yaml_front_matter(qmd), error = function(e) NULL)
  list(path = qmd, lines = lines, yaml = yaml, chunks = parse_chunks(lines))
}

parse_chunks <- function(lines) {
  chunks <- list()
  i <- 1L
  n <- length(lines)
  while (i <= n) {
    m <- regmatches(lines[i], regexec("^```\\{([A-Za-z0-9_.]+)([^}]*)\\}", lines[i]))[[1]]
    if (length(m) == 0) {
      i <- i + 1L
      next
    }
    start <- i
    engine <- m[2]
    header <- trimws(m[3])
    i <- i + 1L
    body <- character(0)
    while (i <= n && !grepl("^```\\s*$", lines[i])) {
      body <- c(body, lines[i])
      i <- i + 1L
    }
    i <- i + 1L  # closing fence

    is_opt <- grepl("^#\\|", body)
    # Options are the leading run of `#|` lines only.
    lead <- cumprod(is_opt) == 1
    opts <- list()
    for (line in body[lead]) {
      kv <- regmatches(line, regexec("^#\\|\\s*([A-Za-z0-9_.-]+)\\s*:\\s*(.*)$", line))[[1]]
      if (length(kv) == 3) {
        opts[[kv[2]]] <- gsub("^[\"']|[\"']$", "", trimws(kv[3]))
      }
    }
    label <- opts$label
    if (is.null(label)) {
      label <- NA_character_
    }
    chunks[[length(chunks) + 1]] <- list(
      engine = engine, header = header, label = label, options = opts,
      body = body[!lead], line = start
    )
  }
  chunks
}

# "l. 12 (label)" / "l. 12 (unlabelled {webr} chunk)" for messages.
chunk_ref <- function(chunk) {
  what <- if (is.na(chunk$label)) {
    paste0("unlabelled {", chunk$engine, "} chunk")
  } else {
    chunk$label
  }
  paste0("line ", chunk$line, " (", what, ")")
}

opt_true <- function(chunk, name) {
  v <- chunk$options[[name]]
  !is.null(v) && tolower(v) %in% c("true", "yes")
}

chunks_of <- function(doc, engine) {
  Filter(function(ch) identical(ch$engine, engine), doc$chunks)
}

widget_pattern <- "learnr2::(question|quiz|student_info|download_answers_button|tutorial_options)\\("

is_widget_chunk <- function(chunk) {
  any(grepl(widget_pattern, chunk$body))
}

# Packages a {webr} body uses: library(x), require(x), requireNamespace("x"),
# and x::. Base/recommended-with-R packages and gradethis are not counted.
base_packages <- c(
  "base", "stats", "utils", "graphics", "grDevices", "methods", "datasets",
  "tools", "parallel", "compiler", "grid", "splines", "stats4", "tcltk"
)

webr_packages_used <- function(doc) {
  bodies <- unlist(lapply(chunks_of(doc, "webr"), function(ch) ch$body))
  if (length(bodies) == 0) {
    return(character(0))
  }
  bodies <- sub("#.*$", "", bodies)  # drop comments
  calls <- regmatches(bodies, gregexpr(
    "(library|require|requireNamespace)\\(\\s*[\"']?([A-Za-z][A-Za-z0-9.]*)[\"']?", bodies
  ))
  from_calls <- sub(".*\\(\\s*[\"']?", "", unlist(calls))
  from_calls <- sub("[\"']$", "", from_calls)
  colons <- regmatches(bodies, gregexpr("\\b([A-Za-z][A-Za-z0-9.]*)::", bodies))
  from_colons <- sub("::$", "", unlist(colons))
  pkgs <- unique(c(from_calls, from_colons))
  setdiff(pkgs, c(base_packages, "gradethis"))
}

webr_packages_declared <- function(doc) {
  pkgs <- doc$yaml$webr$packages
  if (is.null(pkgs)) character(0) else as.character(unlist(pkgs))
}

# ---- the checks -------------------------------------------------------------
# Each takes a parsed tutorial and returns a character vector of problem
# messages (zero-length when the check passes).

tutorial_checks <- list(
  format = function(doc) {
    fmt <- doc$yaml$format
    fmt_names <- if (is.list(fmt)) names(fmt) else as.character(fmt)
    if (!"live-html" %in% fmt_names) {
      "YAML header must have `format: live-html`."
    }
  },

  engine = function(doc) {
    if (!identical(as.character(doc$yaml$engine), "knitr")) {
      "YAML header must have `engine: knitr`."
    }
  },

  include = function(doc) {
    if (!any(grepl("\\{\\{<\\s*include\\s+_extensions/r-wasm/live/_knitr\\.qmd\\s*>\\}\\}", doc$lines))) {
      "Missing `{{< include _extensions/r-wasm/live/_knitr.qmd >}}` after the YAML header."
    }
  },

  gradethis = function(doc) {
    has_check <- any(vapply(chunks_of(doc, "webr"), opt_true, logical(1), "check"))
    has_include <- any(grepl("\\{\\{<\\s*include\\s+_extensions/r-wasm/live/_gradethis\\.qmd\\s*>\\}\\}", doc$lines))
    if (has_check && !has_include) {
      "A `check: true` cell needs `{{< include _extensions/r-wasm/live/_gradethis.qmd >}}` too."
    }
  },

  student_info = function(doc) {
    if (!any(vapply(chunks_of(doc, "r"), function(ch) any(grepl("learnr2::student_info\\(", ch$body)), logical(1)))) {
      "No `{r}` chunk calls `learnr2::student_info()`."
    }
  },

  minutes = function(doc) {
    is_minutes <- vapply(chunks_of(doc, "r"), function(ch) {
      any(grepl("learnr2::question\\(", ch$body)) &&
        any(grepl("validate\\s*=\\s*[\"']integer[\"']", ch$body))
    }, logical(1))
    if (!any(is_minutes)) {
      "No \"how many minutes\" question: a `learnr2::question()` with `validate = \"integer\"`."
    }
  },

  download = function(doc) {
    if (!any(vapply(chunks_of(doc, "r"), function(ch) any(grepl("learnr2::download_answers_button\\(", ch$body)), logical(1)))) {
      "No `{r}` chunk calls `learnr2::download_answers_button()`."
    }
  },

  labels = function(doc) {
    chunks <- Filter(function(ch) ch$engine %in% c("r", "webr"), doc$chunks)
    msgs <- character(0)
    for (ch in chunks) {
      if (is.na(ch$label)) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": no `#| label:` line."))
      }
    }
    labels <- vapply(chunks, function(ch) ch$label, character(1))
    dups <- unique(labels[!is.na(labels) & duplicated(labels)])
    for (d in dups) {
      at <- vapply(chunks[which(labels == d)], function(ch) ch$line, integer(1))
      msgs <- c(msgs, paste0("label `", d, "` is used by more than one chunk (lines ",
                             paste(at, collapse = ", "), ")."))
    }
    msgs
  },

  echo = function(doc) {
    msgs <- character(0)
    for (ch in chunks_of(doc, "r")) {
      if (is_widget_chunk(ch) && !identical(tolower(ch$options$echo %||% ""), "false")) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": widget chunk needs `#| echo: false`."))
      }
    }
    msgs
  },

  persist = function(doc) {
    msgs <- character(0)
    for (ch in chunks_of(doc, "webr")) {
      is_exercise <- !is.null(ch$options$exercise) &&
        !any(vapply(c("setup", "check", "solution", "hint"), opt_true, logical(1), chunk = ch))
      if (is_exercise && !opt_true(ch, "persist")) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": exercise cell needs `#| persist: true`."))
      }
    }
    msgs
  },

  solution = function(doc) {
    webr <- chunks_of(doc, "webr")
    checked <- unique(unlist(lapply(webr, function(ch) if (opt_true(ch, "check")) ch$options$exercise)))
    solved <- unique(unlist(lapply(webr, function(ch) if (opt_true(ch, "solution")) ch$options$exercise)))
    vapply(setdiff(checked, solved), function(ex) {
      paste0("exercise `", ex, "` has a `check: true` cell but no `solution: true` cell ",
             "(a `.solution` div is not enough for the grader).")
    }, character(1))
  },

  packages = function(doc) {
    undeclared <- setdiff(webr_packages_used(doc), webr_packages_declared(doc))
    if (length(undeclared) > 0) {
      paste0("package(s) used in {webr} cells but not listed under `webr: packages:`: ",
             paste(undeclared, collapse = ", "), ".")
    }
  }
)

`%||%` <- function(x, y) if (is.null(x)) y else x
