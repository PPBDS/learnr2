# Covers R/load_tutorial.R: load_tutorial(), read_answers_file(),
# page_widgets(), restore_entries() and write_restore_page().

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

# A rendered page's widgets, built from the real widget markup plus a
# {webr} exercise's script tag as quarto-live emits it.
fake_page <- function(dir) {
  withr::local_options(list(learnr2.lang = NULL))
  # question_id() keeps every id used in the session unique by suffixing
  # repeats, so a second page built here would get intro-1-2, ...; start
  # each page from a clean registry.
  registry <- learnr2:::question_registry
  rm(list = ls(registry), envir = registry)
  q1 <- question("Pick", answer("a", correct = TRUE), answer("b"), id = "intro-1")
  q2 <- question("Type", answer("yes", correct = TRUE), type = "text", id = "intro-2")
  q3 <- question("Explain", type = "reflection", id = "intro-3")
  q4 <- question("Shot", type = "reflection", allow_image = TRUE, id = "intro-4")
  block <- jsonlite::base64_enc(charToRaw(jsonlite::toJSON(
    list(attr = list(exercise = "ex1", persist = TRUE), code = "1 + 1"), auto_unbox = TRUE
  )))
  html <- fs::path(dir, "demo.html")
  writeLines(c(
    "<html><body>",
    as.character(learnr2:::question_div(q1)), as.character(learnr2:::question_div(q2)),
    as.character(learnr2:::question_div(q3)), as.character(learnr2:::question_div(q4)),
    as.character(learnr2:::info_div(student_info())),
    paste0('<script type="webr-7-contents">', block, "</script>"),
    "</body></html>"
  ), html)
  html
}

write_answers <- function(dir, ...) {
  file <- list(package = "fake.tutorials", version = "1.2.3", tutorial = "demo", title = "Demo",
               learnr2Version = "0.1.4",
               info = list(name = "Ada", email = "ada@example.com", id = NULL),
               answers = list(
                 list(id = "intro-1", answer = list("a")),
                 list(id = "intro-2", answer = "yes"),
                 list(id = "intro-3", answer = "Because."),
                 list(id = "intro-4", answer = "data:image/webp;base64,AAAA"),
                 list(id = "ex1", answer = "2 + 2"),
                 list(id = "gone-5", answer = "stale"),
                 list(id = "never-6", answer = NULL)
               ),
               metadata = list(), time = "abc")
  # Top-level fields given in `...` replace the defaults outright (NULL
  # removes one); modifyList() would merge an `answers` list element-wise.
  overrides <- list(...)
  for (key in names(overrides)) file[key] <- list(overrides[[key]])
  path <- fs::path(dir, "answers.json")
  jsonlite::write_json(file, path, auto_unbox = TRUE, null = "null", pretty = TRUE)
  as.character(path)
}

test_that("page_widgets() reads questions, the info form and persisted exercises from a rendered page", {
  html <- fake_page(withr::local_tempdir())
  w <- learnr2:::page_widgets(html)
  expect_setequal(names(w$questions), c("intro-1", "intro-2", "intro-3", "intro-4"))
  expect_equal(w$questions[["intro-1"]]$type, "single")
  expect_equal(w$questions[["intro-2"]]$type, "text")
  expect_true(w$questions[["intro-4"]]$allowImage)
  expect_equal(w$info[[1]]$id, "learnr2-info-student-info")
  expect_equal(w$info[[1]]$keys, c("name", "email", "id"))
  expect_equal(w$exercises, list(ex1 = "webr-7-contents"))
})

test_that("restore_entries() rebuilds quiz.js's saved shapes and drops what matches nothing", {
  dir <- withr::local_tempdir()
  w <- learnr2:::page_widgets(fake_page(dir))
  answers <- jsonlite::fromJSON(write_answers(dir), simplifyVector = FALSE)
  expect_warning(entries <- learnr2:::restore_entries(answers, w, "f.json"),
                 "1 answer\\(s\\) in 'f.json' match no question.*`gone-5`")
  by_id <- stats::setNames(entries, vapply(entries, function(e) e$id, character(1)))
  expect_setequal(names(by_id), c("intro-1", "intro-2", "intro-3", "intro-4", "webr-7-contents",
                                  "learnr2-info-student-info", "loaded-from"))
  # Where the answers came from travels with them, for check_submission().
  expect_equal(by_id[["loaded-from"]]$value$time, "abc")
  expect_equal(by_id[["loaded-from"]]$value$name, "Ada")
  expect_null(by_id[["loaded-from"]]$value$fingerprint)
  expect_equal(by_id[["intro-1"]]$value, list(selected = list("a")))
  expect_equal(by_id[["intro-2"]]$value, list(value = "yes"))
  expect_equal(by_id[["intro-3"]]$value, list(value = "Because.", submitted = TRUE))
  expect_equal(by_id[["intro-4"]]$value, list(value = "", image = "data:image/webp;base64,AAAA", submitted = TRUE))
  # A recording restores as the audio shape buildReflectionQuestion() reads.
  voice <- answers
  voice$answers <- list(list(id = "intro-4", answer = "data:audio/webm;codecs=opus;base64,AAAA"))
  voice_entries <- learnr2:::restore_entries(voice, w)
  expect_equal(voice_entries[[1]]$value, list(value = "", audio = "data:audio/webm;codecs=opus;base64,AAAA", submitted = TRUE))
  expect_true(by_id[["webr-7-contents"]]$raw)
  expect_equal(by_id[["webr-7-contents"]]$prefix, "editor-")
  expect_equal(by_id[["webr-7-contents"]]$value, "2 + 2")
  expect_equal(by_id[["learnr2-info-student-info"]]$value,
               list(name = "Ada", email = "ada@example.com", submitted = TRUE))
  # A one-option choice stays an array in the JSON the page reads.
  json <- as.character(jsonlite::toJSON(entries, auto_unbox = TRUE, null = "null"))
  expect_match(json, '"selected":\\["a"\\]')
})

test_that("write_restore_page() stores the entries under the page's own address and forwards", {
  dir <- withr::local_tempdir()
  path <- learnr2:::write_restore_page(dir, list(list(prefix = "learnr2-", id = "q", value = list(value = "</script>x"), raw = FALSE)))
  expect_equal(fs::path_file(path), "learnr2-restore.html")
  page <- paste(readLines(path), collapse = "\n")
  expect_match(page, 'id="learnr2-restore"', fixed = TRUE)
  expect_match(page, "learnr2-restore.html", fixed = TRUE)
  expect_match(page, "window.location.replace(pageUrl)", fixed = TRUE)
  expect_false(grepl("</script>x", page, fixed = TRUE))  # escaped, cannot close the block
})

# load_tutorial() with everything that touches disk, Quarto and the network
# stubbed: the file, the rendered page and the server are all fakes.
local_loadable <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  html <- fake_page(dir)
  seen <- new.env()
  rows <- data.frame(package = "fake.tutorials", name = "demo", title = "Demo", format = "quarto",
                     path = fs::path(dir, "demo.qmd"), ordering = NA_real_, stringsAsFactors = FALSE)
  local_mocked_bindings(
    available_tutorials = function(package = NULL, type = "all") if (identical(package, "fake.tutorials")) rows else rows[0, ],
    tutorial_identity = function(path) list(package = "fake.tutorials", version = "1.2.3", tutorial = "demo"),
    ensure_rendered = function(tutorial, root, refresh = FALSE) {
      seen$refresh <- refresh
      list(html = as.character(html), work_dir = as.character(dir), rendered = TRUE)
    },
    serve_tutorial = function(tutorial, root, page = NULL) {
      seen$page <- page
      structure("http://127.0.0.1:7446/fake.tutorials/demo/", served_here = TRUE)
    },
    .env = env
  )
  seen$dir <- dir
  seen
}

test_that("load_tutorial() restores a file's answers and opens the restore page", {
  seen <- local_loadable()
  answers <- write_answers(seen$dir)
  expect_warning(
    expect_message(res <- load_tutorial(answers, open = TRUE, output_dir = withr::local_tempdir()), "Restored 7 answer"),
    "`gone-5`"
  )
  expect_equal(seen$page, "learnr2-restore.html")
  # Served by this call, so the page was removed once the server stopped.
  expect_false(fs::file_exists(res))
  expect_equal(fs::path_file(res), "learnr2-restore.html")
})

test_that("load_tutorial(open = FALSE) leaves the restore page in place and returns its path", {
  seen <- local_loadable()
  answers <- write_answers(seen$dir, answers = list(list(id = "intro-3", answer = "Fine.")))
  res <- suppressMessages(load_tutorial(answers, open = FALSE, output_dir = withr::local_tempdir()))
  expect_true(fs::file_exists(res))
  expect_null(seen$page)
  expect_match(paste(readLines(res), collapse = ""), '"id":"intro-3"', fixed = TRUE)
})

test_that("load_tutorial() warns about a missing or different version", {
  seen <- local_loadable()
  expect_warning(suppressMessages(load_tutorial(write_answers(seen$dir, version = NULL, answers = list()),
                                                open = FALSE, output_dir = withr::local_tempdir())),
                 "does not record the version")
  expect_warning(suppressMessages(load_tutorial(write_answers(seen$dir, version = "0.9", answers = list()),
                                                open = FALSE, output_dir = withr::local_tempdir())),
                 "downloaded from fake.tutorials 0.9 but version 1.2.3 is installed")
})

test_that("load_tutorial() stops when the file names no tutorial, or one that isn't installed", {
  seen <- local_loadable()
  expect_error(load_tutorial(write_answers(seen$dir, package = NULL, tutorial = NULL)),
               "does not say which tutorial it came from")
  expect_error(load_tutorial(write_answers(seen$dir, package = "absent.pkg")),
               "Package `absent.pkg`.*is not installed")
  expect_error(load_tutorial(write_answers(seen$dir, tutorial = "other")),
               "has no tutorial named `other`")
  expect_error(load_tutorial(fs::path(seen$dir, "nope.json")), "path of a downloaded answers file")
  bad <- fs::path(seen$dir, "bad.json"); writeLines("{\"x\": 1}", bad)
  expect_error(load_tutorial(bad), "not a learnr2 answers file")
})
