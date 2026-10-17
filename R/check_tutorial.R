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
#' * `ordering` -- if the YAML header sets `learnr2: ordering:`, it is a
#'   single number (see "Ordering" in [available_tutorials()]).
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
#' * `prefix` -- every learnr2 function in an `{r}` chunk is called with
#'   its `learnr2::` prefix. A tutorial never attaches the package, so a
#'   bare `question()` fails at render time.
#' * `options` -- [tutorial_options()] is called at most once.
#' * `divs` -- every `.hint` and `.solution` fenced div names an
#'   `exercise=` that some `{webr}` cell defines, and no graded exercise
#'   (one with a `check: true` cell) has a `.solution` div, which the
#'   grader cannot read.
#'
#' Three further checks report *warnings* rather than errors: with
#' `error = TRUE` they are shown as one warning and do not stop. They cover
#' house style that a tutorial can violate and still work:
#' * `fences` -- every fenced code block names a language (```` ```bash ````,
#'   ```` ```r ````) or is marked ```` ```{.output} ````. A bare ```` ``` ````
#'   block renders as plain text with no way to tell a command from its
#'   output. See the "Code, commands and output" section of
#'   `vignette("translating")`.
#' * `mentions` -- the prose does not mention 'learnr' or
#'   'tutorial.helpers'. Students should never hear of either. Text inside
#'   a code block is not checked, since a quoted file may well name them.
#' * `yaml` -- the YAML header has none of the classic learnr keys
#'   (`output`, `runtime`, `tutorial`, `progressive`, `allow_skip`) and no
#'   document-wide `execute: echo: false`, which is not known to be safe
#'   for `{webr}` cells.
#'
#' @param paths Character vector of tutorials to check: paths to `.qmd`
#'   files, or to directories containing them, as for [render_tutorials()].
#' @param skip Character vector of check names (see "Checks") to leave out,
#'   e.g. `"minutes"` for a tutorial that deliberately has no "how many
#'   minutes" question.
#' @param error If `TRUE` (the default), stop with an error listing every
#'   error-level problem found, after reporting any warning-level ones as
#'   a warning. If `FALSE`, just return them all.
#'
#' @return A data frame of problems with columns `path`, `check`,
#'   `severity` (`"error"` or `"warning"`) and `message`, invisibly. It has
#'   zero rows when every check passed.
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
  problems$severity <- ifelse(problems$check %in% warning_checks, "warning", "error")
  problems <- problems[, c("path", "check", "severity", "message")]
  rownames(problems) <- NULL

  if (isTRUE(error)) {
    warn <- problems[problems$severity == "warning", , drop = FALSE]
    if (nrow(warn) > 0) {
      warning(
        nrow(warn), " style problem(s) found:\n", format_problems(warn),
        call. = FALSE
      )
    }
    err <- problems[problems$severity == "error", , drop = FALSE]
    if (nrow(err) > 0) {
      stop(
        nrow(err), " problem(s) found:\n", format_problems(err),
        call. = FALSE
      )
    }
  }
  invisible(problems)
}

# Checks whose problems are reported as warnings, not errors (see ?check_tutorial).
warning_checks <- c("fences", "mentions", "yaml")

format_problems <- function(problems) {
  paste0("  ", fs::path_file(problems$path), " [", problems$check, "] ",
         problems$message, collapse = "\n")
}

# ---- parsing ----------------------------------------------------------------

# Everything the checks need from one .qmd: its path, its lines, YAML front
# matter (NULL if unparseable), and its chunks -- a list of
#   list(engine, header, label, options, body, line)
# where `header` is whatever followed the engine inside the `{...}` of the
# opening fence (the old inline-option style, e.g. "my-label, echo=FALSE"),
# `options` is a named list of the chunk's `#| key: value` lines (values as
# strings, quotes stripped) and `body` is the remaining lines.
parse_tutorial <- function(qmd) {
  lines <- readLines(qmd, warn = FALSE, encoding = "UTF-8")
  yaml <- tryCatch(rmarkdown::yaml_front_matter(qmd), error = function(e) NULL)
  blocks <- parse_blocks(lines)
  list(path = qmd, lines = lines, yaml = yaml, chunks = parse_chunks(lines),
       blocks = blocks$blocks, in_block = blocks$in_block)
}

# Every fenced block in the document -- chunks, verbatim blocks and plain
# code blocks alike -- as list(line, fence, info) where `info` is whatever
# followed the opening backticks ("" for a bare fence, "{r}", "bash",
# "{.output}", ...), plus a logical vector marking every line that is inside
# a block (fences included). A block closes at the first line that is
# exactly its opening fence, so a three-backtick line inside a four-backtick
# block is content, not a fence.
parse_blocks <- function(lines) {
  blocks <- list()
  in_block <- logical(length(lines))
  i <- 1L
  n <- length(lines)
  while (i <= n) {
    m <- regmatches(lines[i], regexec("^(`{3,})(.*)$", lines[i]))[[1]]
    if (length(m) == 0) {
      i <- i + 1L
      next
    }
    fence <- m[2]
    start <- i
    in_block[i] <- TRUE
    i <- i + 1L
    while (i <= n && trimws(lines[i]) != fence) {
      in_block[i] <- TRUE
      i <- i + 1L
    }
    if (i <= n) in_block[i] <- TRUE
    i <- i + 1L
    blocks[[length(blocks) + 1]] <- list(line = start, fence = fence, info = trimws(m[3]))
  }
  list(blocks = blocks, in_block = in_block)
}

parse_chunks <- function(lines) {
  chunks <- list()
  i <- 1L
  n <- length(lines)
  while (i <= n) {
    # A block fenced by four or more backticks, such as ````{verbatim}, is
    # literal text: a ```{r} line inside it shows chunk syntax and is not a
    # chunk. Skip to its matching closing fence.
    outer <- regmatches(lines[i], regexpr("^````+", lines[i]))
    if (length(outer) == 1) {
      i <- i + 1L
      while (i <= n && trimws(lines[i]) != outer) {
        i <- i + 1L
      }
      i <- i + 1L
      next
    }
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

# "line 12 (label)" / "line 12 (unlabelled {webr} chunk)" for messages.
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

widget_functions <- c("question", "quiz", "student_info", "download_answers_button",
                      "tutorial_options")
widget_pattern <- paste0(
  "(^|[^A-Za-z0-9_.:])(learnr2::)?(", paste(widget_functions, collapse = "|"), ")\\("
)

is_widget_chunk <- function(chunk) {
  any(grepl(widget_pattern, chunk$body))
}

# learnr2 functions called in an {r} chunk body without the learnr2:: prefix.
unprefixed_calls <- function(body) {
  fns <- c(widget_functions, "answer")
  pattern <- paste0("(^|[^A-Za-z0-9_.:])(", paste(fns, collapse = "|"), ")\\(")
  hits <- regmatches(body, gregexpr(pattern, body))
  calls <- sub("^[^A-Za-z]*", "", unlist(hits))
  unique(sub("\\($", "", calls))
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

  ordering = function(doc) {
    l2 <- doc$yaml$learnr2
    if (!is.null(l2) && !is.list(l2)) {
      return("YAML `learnr2:` must be a mapping (e.g. `learnr2:` then an indented `ordering: 3`).")
    }
    ordering <- l2$ordering
    if (!is.null(ordering) && !(is.numeric(ordering) && length(ordering) == 1 && !is.na(ordering))) {
      "YAML `learnr2: ordering:` must be a single number, e.g. `ordering: 3`."
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
      if (nzchar(ch$header)) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": options inside `{", ch$engine, " ",
                               ch$header, "}`; put each on its own `#| key: value` line ",
                               "(the label as `#| label:`)."))
      }
      if (is.na(ch$label)) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": no `#| label:` line."))
      } else if (identical(ch$label, "progressive-sections")) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": the label `progressive-sections` is ",
                               "reserved (it keys the saved Continue progress)."))
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
  },

  prefix = function(doc) {
    msgs <- character(0)
    for (ch in chunks_of(doc, "r")) {
      bare <- unprefixed_calls(sub("#.*$", "", ch$body))
      if (length(bare) > 0) {
        msgs <- c(msgs, paste0(chunk_ref(ch), ": call ",
                               paste0("`learnr2::", bare, "()`", collapse = ", "),
                               " with the prefix; a tutorial never attaches learnr2."))
      }
    }
    msgs
  },

  options = function(doc) {
    calls <- Filter(function(ch) any(grepl("tutorial_options\\(", ch$body)), chunks_of(doc, "r"))
    if (length(calls) > 1) {
      paste0("`learnr2::tutorial_options()` is called ", length(calls), " times (lines ",
             paste(vapply(calls, function(ch) ch$line, integer(1)), collapse = ", "),
             "); call it once.")
    }
  },

  divs = function(doc) {
    webr <- chunks_of(doc, "webr")
    defined <- unique(unlist(lapply(webr, function(ch) ch$options$exercise)))
    checked <- unique(unlist(lapply(webr, function(ch) if (opt_true(ch, "check")) ch$options$exercise)))
    div_lines <- grep("^:::+\\s*\\{\\s*\\.(hint|solution)\\b", doc$lines)
    msgs <- character(0)
    for (i in div_lines) {
      m <- regmatches(doc$lines[i], regexec("\\.(hint|solution)\\b.*exercise\\s*=\\s*[\"']([^\"']+)[\"']", doc$lines[i]))[[1]]
      if (length(m) == 0) {
        msgs <- c(msgs, paste0("line ", i, ": `.hint`/`.solution` div has no `exercise=\"...\"`."))
        next
      }
      kind <- m[2]
      ex <- m[3]
      if (!ex %in% defined) {
        msgs <- c(msgs, paste0("line ", i, ": `.", kind, "` div names exercise `", ex,
                               "`, which no `{webr}` cell defines."))
      } else if (kind == "solution" && ex %in% checked) {
        msgs <- c(msgs, paste0("line ", i, ": exercise `", ex, "` is graded (`check: true`), ",
                               "so its solution must be a `solution: true` cell, not a ",
                               "`.solution` div the grader cannot read."))
      }
    }
    msgs
  },

  fences = function(doc) {
    bare <- Filter(function(b) !nzchar(b$info), doc$blocks)
    if (length(bare) == 0) {
      return(character(0))
    }
    at <- vapply(bare, function(b) b$line, integer(1))
    shown <- if (length(at) > 8) c(at[1:8], "...") else at
    paste0(length(bare), " code block(s) with no language (line",
           if (length(at) > 1) "s " else " ", paste(shown, collapse = ", "),
           "): tag what the reader types as ```bash or ```r, and expected output as ",
           "```{.output}.")
  },

  mentions = function(doc) {
    prose <- doc$lines
    prose[doc$in_block] <- ""
    # The YAML header is not prose either (a classic `output: learnr::tutorial`
    # is the yaml check's business).
    fences <- which(grepl("^---\\s*$", prose))
    if (length(fences) >= 2 && fences[1] == 1) {
      prose[seq_len(fences[2])] <- ""
    }
    # HTML comments are notes to authors, not text students see.
    prose <- gsub("<!--.*?-->", "", prose)
    hits <- grep("\\btutorial\\.helpers\\b|\\blearnr\\b", prose, perl = TRUE)
    if (length(hits) == 0) {
      return(character(0))
    }
    shown <- if (length(hits) > 8) c(hits[1:8], "...") else hits
    paste0("prose mentions learnr or tutorial.helpers (line",
           if (length(hits) > 1) "s " else " ", paste(shown, collapse = ", "),
           "): students should never hear of either; see `vignette(\"translating\")`.")
  },

  yaml = function(doc) {
    y <- doc$yaml
    msgs <- character(0)
    old <- intersect(c("output", "runtime", "tutorial", "progressive", "allow_skip"), names(y))
    if (length(old) > 0) {
      msgs <- c(msgs, paste0("YAML header still has classic learnr key(s): ",
                             paste0("`", old, ":`", collapse = ", "),
                             "; delete them (learnr2 reveals sections itself; see ",
                             "`learnr2::tutorial_options()` for `allow_skip`)."))
    }
    echo <- y$execute$echo
    if (!is.null(echo) && isFALSE(echo)) {
      msgs <- c(msgs, paste0("YAML `execute: echo: false` applies to every chunk, including ",
                             "{webr} cells; put `#| echo: false` on each widget chunk instead."))
    }
    msgs
  }
)

`%||%` <- function(x, y) if (is.null(x)) y else x
