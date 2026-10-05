# Covers R/check_tutorial.R: check_tutorial(), parse_tutorial(),
# parse_chunks(), webr_packages_used(), and every entry of tutorial_checks.

# A tutorial that passes every check, assembled from the same pieces the
# create_tutorial() template and the bundled tutorials use.
good_lines <- c(
  "---",
  'title: "Good"',
  "format: live-html",
  "engine: knitr",
  "toc: true",
  "webr:",
  "  packages:",
  "    - dplyr",
  "---",
  "",
  "{{< include _extensions/r-wasm/live/_knitr.qmd >}}",
  "{{< include _extensions/r-wasm/live/_gradethis.qmd >}}",
  "",
  "```{r}",
  "#| label: student-information-1",
  "#| echo: false",
  "learnr2::student_info()",
  "```",
  "",
  "## Vectors",
  "",
  "```{webr}",
  "#| label: vectors-1",
  "library(dplyr)",
  "1:3",
  "```",
  "",
  "```{webr}",
  "#| label: vectors-2",
  "#| exercise: ex_sum",
  "#| persist: true",
  "sum(______)",
  "```",
  "",
  "```{webr}",
  "#| label: vectors-3",
  "#| exercise: ex_sum",
  "#| solution: true",
  "sum(1:3)",
  "```",
  "",
  "```{webr}",
  "#| label: vectors-4",
  "#| exercise: ex_sum",
  "#| check: true",
  "gradethis::grade_this_code()",
  "```",
  "",
  "```{r}",
  "#| label: vectors-5",
  "#| echo: false",
  'learnr2::question("Q?", learnr2::answer("a", correct = TRUE))',
  "```",
  "",
  "## Your answers",
  "",
  "```{r}",
  "#| label: your-answers-1",
  "#| echo: false",
  "learnr2::question(",
  '  "How many minutes?",',
  '  type = "reflection_editable",',
  '  validate = "integer"',
  ")",
  "```",
  "",
  "```{r}",
  "#| label: your-answers-2",
  "#| echo: false",
  'learnr2::download_answers_button(filename_prefix = "good")',
  "```"
)

write_qmd <- function(lines, name = "t") {
  d <- fs::path(withr::local_tempdir(.local_envir = parent.frame()), name)
  fs::dir_create(d)
  f <- fs::path(d, name, ext = "qmd")
  writeLines(lines, f)
  f
}

# Problems for `lines`, as a character vector of check names (possibly with
# repeats), without erroring.
failing_checks <- function(lines) {
  check_tutorial(write_qmd(lines), error = FALSE)$check
}

# `good_lines` with the lines matching `pattern` dropped, or replaced.
without <- function(pattern, lines = good_lines) lines[!grepl(pattern, lines)]
replacing <- function(pattern, replacement, lines = good_lines) sub(pattern, replacement, lines)

test_that("a well-formed tutorial passes every check and returns a zero-row frame invisibly", {
  f <- write_qmd(good_lines)
  res <- withVisible(check_tutorial(f))
  expect_false(res$visible)
  expect_s3_class(res$value, "data.frame")
  expect_named(res$value, c("path", "check", "message"))
  expect_identical(nrow(res$value), 0L)
  # The create_tutorial() template must pass too, or every new tutorial starts red.
  tpl <- create_tutorial("fresh", dir = withr::local_tempdir(), open = FALSE)
  expect_identical(nrow(check_tutorial(tpl)), 0L)
})

test_that("format / engine / include checks read the YAML header and the include line", {
  expect_identical(failing_checks(replacing("^format: live-html", "format: html")), "format")
  expect_identical(failing_checks(without("^format:")), "format")
  expect_identical(failing_checks(replacing("^engine: knitr", "engine: jupyter")), "engine")
  expect_identical(failing_checks(without("^engine:")), "engine")
  expect_identical(failing_checks(without("_knitr\\.qmd")), "include")
  # format given in the list form Quarto also accepts.
  lst <- replacing("^format: live-html", "format:\n  live-html:\n    toc: true")
  expect_identical(nrow(check_tutorial(write_qmd(lst), error = FALSE)), 0L)
})

test_that("gradethis check fires only when a check: true cell lacks the include", {
  expect_identical(failing_checks(without("_gradethis\\.qmd")), "gradethis")
  # No check cell -> no gradethis include needed. The former check cell
  # becomes a hint cell, which (like setup/solution) needs no persist: true.
  no_check <- without("_gradethis\\.qmd")
  no_check <- replacing("^#\\| check: true", "#| hint: true", no_check)
  expect_identical(nrow(check_tutorial(write_qmd(no_check), error = FALSE)), 0L)
})

test_that("student_info / minutes / download checks look for the boilerplate calls", {
  expect_identical(failing_checks(without("learnr2::student_info")), "student_info")
  expect_identical(failing_checks(without('validate = "integer"')), "minutes")
  expect_identical(failing_checks(without("learnr2::download_answers_button")), "download")
})

test_that("labels check catches missing and duplicated #| label: lines, in {r} and {webr} alike", {
  res <- check_tutorial(write_qmd(without("^#\\| label: vectors-1")), error = FALSE)
  expect_identical(res$check, "labels")
  expect_match(res$message, "line 2[0-9] \\(unlabelled \\{webr\\} chunk\\): no `#\\| label:` line")

  res <- check_tutorial(write_qmd(without("^#\\| label: vectors-5")), error = FALSE)
  expect_match(res$message, "unlabelled \\{r\\} chunk")

  dup <- replacing("^#\\| label: vectors-2", "#| label: vectors-1")
  res <- check_tutorial(write_qmd(dup), error = FALSE)
  expect_identical(res$check, "labels")
  expect_match(res$message, "label `vectors-1` is used by more than one chunk \\(lines [0-9]+, [0-9]+\\)")
})

test_that("echo check requires echo: false on widget chunks only", {
  res <- check_tutorial(write_qmd(without("^#\\| echo: false")), error = FALSE)
  expect_true(all(res$check == "echo"))
  # student_info, question, minutes question, download button: four widget chunks.
  expect_identical(nrow(res), 4L)
  expect_match(res$message[1], "student-information-1.*widget chunk needs `#\\| echo: false`")
  # A non-widget {r} chunk without echo is fine.
  extra <- c(good_lines, "", "```{r}", "#| label: your-answers-3", "x <- 1", "```")
  expect_identical(nrow(check_tutorial(write_qmd(extra), error = FALSE)), 0L)
})

test_that("persist check requires persist: true on exercise cells, not on setup/solution/check/hint cells", {
  expect_identical(failing_checks(without("^#\\| persist: true")), "persist")
  res <- check_tutorial(write_qmd(without("^#\\| persist: true")), error = FALSE)
  expect_match(res$message, "vectors-2.*exercise cell needs `#\\| persist: true`")

  setup <- c(good_lines, "", "```{webr}", "#| label: your-answers-3", "#| setup: true",
             "#| exercise: ex_sum", "y <- 1", "```")
  expect_identical(nrow(check_tutorial(write_qmd(setup), error = FALSE)), 0L)
  hint <- c(good_lines, "", "```{webr}", "#| label: your-answers-3", "#| hint: true",
            "#| exercise: ex_sum", "sum(?)", "```")
  expect_identical(nrow(check_tutorial(write_qmd(hint), error = FALSE)), 0L)
})

test_that("solution check requires a solution: true cell for every graded exercise", {
  res <- check_tutorial(write_qmd(without("^#\\| solution: true")), error = FALSE)
  # Dropping the option also turns that cell into a persist-less exercise cell.
  expect_setequal(res$check, c("persist", "solution"))
  expect_match(res$message[res$check == "solution"],
               "exercise `ex_sum` has a `check: true` cell but no `solution: true` cell")
  # A .solution div does not satisfy it.
  div <- c(without("^#\\| solution: true"), "", '::: { .solution exercise="ex_sum" }', "```r", "sum(1:3)", "```", ":::")
  expect_true("solution" %in% failing_checks(div))
})

test_that("packages check compares {webr} usage against webr: packages:, ignoring base and gradethis", {
  expect_identical(failing_checks(without("^    - dplyr")), "packages")
  res <- check_tutorial(write_qmd(without("^    - dplyr")), error = FALSE)
  expect_match(res$message, "not listed under `webr: packages:`: dplyr")

  more <- replacing("^1:3$", "tidyr::pivot_longer(x); require(ggplot2); utils::head(x); stats::sd(x) # nycflights13::flights")
  res <- check_tutorial(write_qmd(more), error = FALSE)
  expect_identical(res$check, "packages")
  expect_match(res$message, "ggplot2")
  expect_match(res$message, "tidyr")
  expect_false(grepl("utils|stats|nycflights13|gradethis", res$message))

  # Usage inside {r} chunks is deliberately *not* counted: those run at
  # render time, not in WebR.
  r_only <- c(good_lines, "", "```{r}", "#| label: your-answers-3", "#| echo: false",
              "library(not.for.webr)", "```")
  expect_identical(nrow(check_tutorial(write_qmd(r_only), error = FALSE)), 0L)

  # Inline-list YAML form.
  inl <- without("^    - dplyr")
  inl <- without("^  packages:$", inl)
  inl <- replacing("^webr:$", "webr:\n  packages: [dplyr, ggplot2]", inl)
  expect_identical(nrow(check_tutorial(write_qmd(inl), error = FALSE)), 0L)
})

test_that("skip leaves named checks out, and rejects unknown names", {
  f <- write_qmd(without('validate = "integer"'))
  expect_error(check_tutorial(f), "\\[minutes\\]")
  expect_identical(nrow(check_tutorial(f, skip = "minutes")), 0L)
  expect_error(check_tutorial(f, skip = "mintues"), "`skip` must name checks from")
  expect_error(check_tutorial(f, skip = 1), "`skip` must name checks from")
})

test_that("error = TRUE lists every problem across every file, with the file name and check", {
  a <- write_qmd(without("learnr2::student_info"), "a")
  b <- write_qmd(without("^#\\| persist: true"), "b")
  expect_error(
    check_tutorial(c(a, b)),
    "2 problem\\(s\\) found:\n  a\\.qmd \\[student_info\\] .*\n  b\\.qmd \\[persist\\] "
  )
  res <- check_tutorial(c(a, b), error = FALSE)
  expect_identical(res$check, c("student_info", "persist"))
  expect_identical(fs::path_file(res$path), c("a.qmd", "b.qmd"))
})

test_that("check_tutorial() accepts a tutorial directory and validates paths", {
  f <- write_qmd(good_lines)
  expect_identical(nrow(check_tutorial(fs::path_dir(f))), 0L)
  expect_error(check_tutorial("no/such/file.qmd"), "not found")
})

test_that("a document with no YAML header fails format and engine rather than crashing", {
  bare <- good_lines[-(1:9)]
  res <- check_tutorial(write_qmd(bare), error = FALSE)
  expect_true(all(c("format", "engine") %in% res$check))
})

# ---- parse_chunks() ---------------------------------------------------------

test_that("parse_chunks() reads engine, leading #| options (quotes stripped), body, and line number", {
  lines <- c(
    "prose",
    "```{webr}",
    "#| label: 'a-1'",
    "#| exercise: ex",
    "#| persist: true",
    "x <- 1",
    "#| not: an option -- after the body started",
    "```",
    "```{r setup, include=FALSE}",
    "library(x)",
    "```",
    "```{python}",
    "```",
    "```{r}",
    "unterminated"
  )
  ch <- learnr2:::parse_chunks(lines)
  expect_length(ch, 4)
  expect_identical(ch[[1]]$engine, "webr")
  expect_identical(ch[[1]]$label, "a-1")
  expect_identical(ch[[1]]$options, list(label = "a-1", exercise = "ex", persist = "true"))
  expect_identical(ch[[1]]$body, c("x <- 1", "#| not: an option -- after the body started"))
  expect_identical(ch[[1]]$line, 2L)
  # Inline-header labels are not `#| label:` lines, so they don't count.
  expect_identical(ch[[2]]$engine, "r")
  expect_true(is.na(ch[[2]]$label))
  expect_identical(ch[[2]]$header, "setup, include=FALSE")
  expect_identical(ch[[3]]$body, character(0))
  expect_identical(ch[[4]]$body, "unterminated")
  expect_identical(learnr2:::parse_chunks(character(0)), list())
})
