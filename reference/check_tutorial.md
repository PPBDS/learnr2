# Check that a tutorial has the recommended components

Static checks on a tutorial's `.qmd` source for the mistakes that look
fine in the file and only show up later – in the rendered page, in a
reader's browser, or when a reader's saved progress silently resets.
Each one is a rule from this package's authoring guide; this function
encodes them so a content package can enforce them in its tests, the way
`tutorial.helpers::check_tutorial_defaults()` did for 'learnr'
tutorials. Pair it with
[`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md):
rendering proves the document builds, these checks catch what a
successful render does not.

## Usage

``` r
check_tutorial(paths, skip = NULL, error = TRUE)
```

## Arguments

- paths:

  Character vector of tutorials to check: paths to `.qmd` files, or to
  directories containing them, as for
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md).

- skip:

  Character vector of check names (see "Checks") to leave out, e.g.
  `"minutes"` for a tutorial that deliberately has no "how many minutes"
  question.

- error:

  If `TRUE` (the default), stop with an error listing every problem
  found. If `FALSE`, just return them.

## Value

A data frame of problems with columns `path`, `check`, and `message`,
invisibly. It has zero rows when every check passed.

## Checks

Each check has a name, used in `skip`:

- `format` – the YAML header has `format: live-html`.

- `engine` – the YAML header has `engine: knitr`.

- `include` – the document includes the 'quarto-live' runtime partial,
  `{{< include _extensions/r-wasm/live/_knitr.qmd >}}`. Without it no
  `{webr}` cell works.

- `gradethis` – if any `{webr}` cell has `check: true`, the document
  also includes `_extensions/r-wasm/live/_gradethis.qmd`.

- `student_info` – an `{r}` chunk calls
  [`learnr2::student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md).

- `minutes` – an `{r}` chunk has the "how many minutes" question, i.e. a
  [`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md)
  with `validate = "integer"`.

- `download` – an `{r}` chunk calls
  [`learnr2::download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md).

- `labels` – every `{r}` and `{webr}` chunk has its own `#| label:`
  line, and no two chunks share a label. A question's chunk label is the
  key its saved answer is stored under, so a missing or duplicated label
  loses or merges readers' progress.

- `echo` – every `{r}` chunk that renders a learnr2 widget
  ([`question()`](https://ppbds.github.io/learnr2/reference/question.md),
  [`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
  [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md))
  has `#| echo: false`, so the reader sees the widget, not the R code
  that produced it.

- `persist` – every `{webr}` exercise cell (one with `#| exercise:` that
  is not a `setup`, `check`, `solution`, or `hint` cell) has
  `#| persist: true`, without which the reader's code is never saved and
  never appears in a download.

- `solution` – every exercise that has a `check: true` cell also has a
  `solution: true` cell. A `.solution` div is not enough: the grader
  fails with "No solution code was found".

- `packages` – every non-base package a `{webr}` cell uses (via
  [`library()`](https://rdrr.io/r/base/library.html),
  [`require()`](https://rdrr.io/r/base/library.html), or `pkg::`) is
  listed under `webr: packages:` in the YAML header, the only place WebR
  learns what to install. `gradethis` is exempt, since the
  `_gradethis.qmd` include provides it.

## Examples

``` r
qmd <- create_tutorial("checked", dir = tempfile(), open = FALSE)
#> Created tutorial: /tmp/RtmpQdQJzB/file1a3b5a67360b/checked/checked.qmd
check_tutorial(qmd)

# Break the template, then see the problems instead of an error.
lines <- readLines(qmd)
writeLines(lines[!grepl("^#\\| echo: false", lines)], qmd)
problems <- check_tutorial(qmd, error = FALSE)
problems[, c("check", "message")]
#>   check                                                               message
#> 1  echo line 15 (student-information-1): widget chunk needs `#| echo: false`.
#> 2  echo     line 54 (a-quiz-question-1): widget chunk needs `#| echo: false`.
#> 3  echo        line 67 (your-answers-1): widget chunk needs `#| echo: false`.
#> 4  echo        line 77 (your-answers-2): widget chunk needs `#| echo: false`.

unlink(dirname(dirname(qmd)), recursive = TRUE)
```
