#' Reopen a tutorial with a student's downloaded answers filled in
#'
#' Takes the JSON file a reader downloaded with the "Download My Answers"
#' button, works out which tutorial it came from, renders (or reuses the
#' cached render of) that tutorial exactly as [run_tutorial()] would, and
#' opens it with every answer in the file already submitted, as if the
#' reader had just typed them in. The reader can then carry on, correct
#' what needs correcting, and download a new file. The usual case is a
#' resubmission: a student whose file has one wrong URL fixes that answer
#' instead of redoing the tutorial.
#'
#' @section What is restored:
#' Every entry in the file's `answers` whose id matches a [question()] or a
#' `{webr}` exercise on the rendered page, plus the [student_info()] form.
#' A choice question gets its picked options back, a text question its
#' text, a reflection its text or pasted screenshot, an exercise its code.
#' Sections are unlocked through the last one holding a restored answer,
#' so the page opens where the reader left off. An entry whose id matches
#' nothing (the tutorial has changed since the download, say) is dropped
#' with a warning naming it. Answers never submitted (`null` in the file)
#' are left blank.
#'
#' Answers live in the browser's `localStorage`, keyed by the tutorial's
#' address (see "Progress persistence" in [question()]), so this writes a
#' small page, `learnr2-restore.html`, next to the rendered tutorial in the
#' cache; opening it stores the answers under the tutorial's own address
#' and forwards to the tutorial. Loading a file replaces whatever that
#' browser had saved for the same tutorial. When this function's own
#' server is stopped the page is deleted; if an already-running learnr2
#' server was used instead, it stays until the next load or re-render.
#'
#' @section The same thing without R:
#' Every tutorial page also has a **Load Answers** button beside **Start
#' Over**, and accepts a dropped `.json` file anywhere on the page. It does
#' in the browser what this function does from R, matching ids the same
#' way, so a reader of a published copy of a tutorial (on GitHub Pages,
#' say) can pick up a download without an R session. This function is for
#' the student in a Codespace, where the tutorial must be rendered and
#' served first, and for the "R Tutorials" VS Code extension's **Load
#' Answers File...** command, which calls it.
#'
#' @param path Path to a JSON file downloaded with
#'   [download_answers_button()]. It must name its `package` and
#'   `tutorial` (files downloaded before learnr2 recorded them cannot be
#'   loaded); a missing `version`, or one that differs from the installed
#'   package, is reported as a warning, since the tutorial's questions may
#'   have changed.
#' @param output_dir,open,refresh As for [run_tutorial()]. With
#'   `open = FALSE` the tutorial is rendered and the restore page written,
#'   but nothing is served or opened; the restore page's path is returned.
#'
#' @return The path of the restore page, invisibly.
#' @seealso [run_tutorial()], [download_answers_button()],
#'   [submission_time()].
#' @export
#' @examples
#' \dontrun{
#' load_tutorial("~/Downloads/orientation-2026-11-08T14-02-11-305Z.json")
#' }
load_tutorial <- function(path,
                          output_dir = tools::R_user_dir("learnr2", "cache"),
                          open = interactive(),
                          refresh = FALSE) {
  answers <- read_answers_file(path)
  package <- answers$package
  name <- answers$tutorial
  if (!is_string(package) || !is_string(name)) {
    stop("'", path, "' does not say which tutorial it came from (no `package` and ",
         "`tutorial` fields). It was downloaded with a learnr2 older than 0.1.4, ",
         "which did not record them; the reader will have to redo the tutorial.",
         call. = FALSE)
  }
  if (!is_string(answers$version)) {
    warning("'", path, "' does not record the version of ", package,
            " it was downloaded from, so the tutorial's questions may have changed.",
            call. = FALSE)
  }

  tutorials <- tryCatch(available_tutorials(package = package), error = function(e) NULL)
  if (is.null(tutorials) || nrow(tutorials) == 0) {
    stop("Package `", package, "` (which '", path, "' was downloaded from) is not ",
         "installed, or has no learnr2 tutorials. Install it, then try again.",
         call. = FALSE)
  }
  if (!name %in% tutorials$name) {
    stop("Package `", package, "` has no tutorial named `", name, "` (which '", path,
         "' was downloaded from). It has: ", paste(tutorials$name, collapse = ", "), ".",
         call. = FALSE)
  }
  tutorial <- tutorials[tutorials$name == name, , drop = FALSE]
  installed <- tutorial_identity(tutorial$path)$version
  if (is_string(answers$version) && !is.null(installed) && !identical(installed, answers$version)) {
    warning("'", path, "' was downloaded from ", package, " ", answers$version,
            " but version ", installed, " is installed; questions that changed between ",
            "the two will not be restored.", call. = FALSE)
  }

  root <- fs::path_abs(output_dir)
  rendered <- ensure_rendered(tutorial, root, refresh = refresh)
  widgets <- page_widgets(rendered$html)
  entries <- restore_entries(answers, widgets, path)
  restore <- write_restore_page(rendered$work_dir, entries)
  message("Restored ", length(entries), " answer(s) from '", path, "'.")

  if (!isTRUE(open)) {
    return(invisible(restore))
  }
  served <- serve_tutorial(tutorial, root, page = RESTORE_FILE)
  # Our own server has just stopped (Ctrl+C), so the page has done its job.
  if (isTRUE(attr(served, "served_here")) && fs::file_exists(restore)) {
    fs::file_delete(restore)
  }
  invisible(restore)
}

RESTORE_FILE <- "learnr2-restore.html"

read_answers_file <- function(path) {
  if (!is_string(path) || !file.exists(path)) {
    stop("`path` must be the path of a downloaded answers file.", call. = FALSE)
  }
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  parsed <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(parsed) || is.null(parsed$answers)) {
    stop("'", path, "' is not a learnr2 answers file (no `answers` field).", call. = FALSE)
  }
  parsed
}

# What the rendered page can take an answer for: questions (id -> type and
# whether it takes an image), student_info() forms (id and field keys) and
# persisted {webr} exercises (exercise label -> the id quarto-live keys the
# code under: the cell's `#| id:` option, else its <script type> name).
# Read from the same markup quiz.js reads, so the two agree.
page_widgets <- function(html) {
  page <- paste(readLines(html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  decode <- decode_payload
  attr_values <- function(attr) {
    m <- regmatches(page, gregexpr(paste0(attr, "=\"[^\"]+\""), page))[[1]]
    gsub(paste0("^", attr, "=\"|\"$"), "", m)
  }
  questions <- list()
  for (payload in Filter(Negate(is.null), lapply(attr_values("data-learnr2-question"), decode))) {
    if (is_string(payload$id)) {
      questions[[payload$id]] <- list(type = payload$type %||% "single",
                                      allowImage = isTRUE(payload$allowImage))
    }
  }
  info <- list()
  for (payload in Filter(Negate(is.null), lapply(attr_values("data-learnr2-info"), decode))) {
    if (is_string(payload$id)) {
      info[[length(info) + 1]] <- list(
        id = payload$id,
        keys = vapply(payload$fields, function(f) f$key, character(1))
      )
    }
  }
  exercises <- list()
  scripts <- regmatches(page, gregexpr(
    "<script type=\"(webr|pyodide)-[^\"]+-contents\">[^<]*</script>", page
  ))[[1]]
  for (script in scripts) {
    type <- sub("^<script type=\"([^\"]+)\".*$", "\\1", script)
    block <- decode(trimws(gsub("^<script[^>]*>|</script>$", "", script)))
    attrs <- block$attr
    if (!is.null(attrs) && is_string(attrs$exercise) && isTRUE(attrs$persist)) {
      exercises[[attrs$exercise]] <- if (is_string(attrs$id)) attrs$id else type
    }
  }
  list(questions = questions, info = info, exercises = exercises)
}

# The localStorage entries that reproduce `answers` on the page: a list of
# list(prefix, id, value, raw). The restore page builds each key as
# prefix + <tutorial address> + "#" + id, the address being its own, so a
# tutorial reached through a Codespaces forwarded port is keyed the way its
# own quiz.js will look for it. Shapes follow what quiz.js saves (see
# buildChoiceQuestion(), buildTextQuestion(), buildReflectionQuestion() and
# buildInfoForm()); quarto-live stores exercise code as a bare string.
restore_entries <- function(answers, widgets, path = "the answers file") {
  entries <- list()
  unmatched <- character(0)
  for (a in answers$answers) {
    id <- a$id
    value <- a$answer
    if (!is_string(id) || is.null(value)) next
    q <- widgets$questions[[id]]
    if (!is.null(q)) {
      state <- switch(q$type,
        single = , multiple = list(selected = as.list(unlist(value))),
        text = list(value = paste(unlist(value), collapse = "")),
        {
          text <- paste(unlist(value), collapse = "")
          if (grepl("^data:image/", text)) {
            list(value = "", image = text, submitted = TRUE)
          } else if (grepl("^data:audio/", text)) {
            list(value = "", audio = text, submitted = TRUE)
          } else {
            list(value = text, submitted = TRUE)
          }
        }
      )
      entries[[length(entries) + 1]] <- list(prefix = "learnr2-", id = id, value = state, raw = FALSE)
    } else if (!is.null(widgets$exercises[[id]])) {
      entries[[length(entries) + 1]] <- list(prefix = "editor-", id = widgets$exercises[[id]],
                                             value = paste(unlist(value), collapse = ""), raw = TRUE)
    } else {
      unmatched <- c(unmatched, id)
    }
  }
  info <- answers$info
  if (is.list(info) && length(widgets$info) > 0) {
    form <- widgets$info[[1]]
    values <- info[intersect(names(info), form$keys)]
    values <- Filter(function(v) is_string(v), values)
    if (length(values) > 0) {
      entries[[length(entries) + 1]] <- list(prefix = "learnr2-", id = form$id,
                                             value = c(values, list(submitted = TRUE)), raw = FALSE)
    }
  }
  # Where these answers came from, carried into the next download as
  # `loadedFrom` (see check_submission()).
  str_or_null <- function(x) if (is_string(x)) x else NULL
  entries[[length(entries) + 1]] <- list(
    prefix = "learnr2-", id = "loaded-from", raw = FALSE,
    value = list(
      time = str_or_null(answers$time),
      deviceId = str_or_null(answers$metadata$deviceId),
      fingerprint = str_or_null(answers$fingerprint),
      name = str_or_null(answers$info$name),
      email = str_or_null(answers$info$email)
    )
  )
  if (length(unmatched) > 0) {
    warning(
      length(unmatched), " answer(s) in '", path, "' match no question or exercise in the ",
      "rendered tutorial and were dropped: ", paste0("`", unmatched, "`", collapse = ", "),
      ". The tutorial has probably changed since the file was downloaded.",
      call. = FALSE
    )
  }
  entries
}

# A page that stores `entries` under the tutorial's own address and then
# forwards to it. It sits next to the rendered tutorial, so its address is
# the tutorial's plus RESTORE_FILE, which the script strips off.
write_restore_page <- function(work_dir, entries) {
  json <- jsonlite::toJSON(entries, auto_unbox = TRUE, null = "null")
  json <- gsub("</", "<\\/", as.character(json), fixed = TRUE)
  page <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\"><head><meta charset=\"utf-8\"><title>Restoring answers</title></head>",
    "<body>",
    "<p>Restoring your answers&hellip; <a id=\"learnr2-target\" href=\"./\">Open the tutorial</a> if nothing happens.</p>",
    "<noscript><p>JavaScript is needed to restore the answers.</p></noscript>",
    paste0("<script type=\"application/json\" id=\"learnr2-restore\">", json, "</script>"),
    "<script>",
    "(function () {",
    "  var entries = JSON.parse(document.getElementById(\"learnr2-restore\").textContent);",
    paste0("  var pageUrl = window.location.href.split(\"#\")[0].replace(/", RESTORE_FILE,
           "(\\?.*)?$/, \"\");"),
    "  entries.forEach(function (e) {",
    "    var key = e.prefix + pageUrl + \"#\" + e.id;",
    "    window.localStorage.setItem(key, e.raw ? e.value : JSON.stringify(e.value));",
    "  });",
    "  document.getElementById(\"learnr2-target\").href = pageUrl;",
    "  window.location.replace(pageUrl);",
    "})();",
    "</script>",
    "</body></html>"
  )
  path <- fs::path(work_dir, RESTORE_FILE)
  writeLines(page, path, useBytes = TRUE)
  as.character(path)
}
