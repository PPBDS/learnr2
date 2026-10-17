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

  If `TRUE` (the default), stop with an error listing every error-level
  problem found, after reporting any warning-level ones as a warning. If
  `FALSE`, just return them all.

## Value

A data frame of problems with columns `path`, `check`, `severity`
(`"error"` or `"warning"`) and `message`, invisibly. It has zero rows
when every check passed.

## Checks

Each check has a name, used in `skip`:

- `format` – the YAML header has `format: live-html`.

- `engine` – the YAML header has `engine: knitr`.

- `ordering` – if the YAML header sets `learnr2: ordering:`, it is a
  single number (see "Ordering" in
  [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)).

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
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md),
  [`tutorial_options()`](https://ppbds.github.io/learnr2/reference/tutorial_options.md))
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

- `prefix` – every learnr2 function in an `{r}` chunk is called with its
  `learnr2::` prefix. A tutorial never attaches the package, so a bare
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  fails at render time.

- `options` –
  [`tutorial_options()`](https://ppbds.github.io/learnr2/reference/tutorial_options.md)
  is called at most once.

- `divs` – every `.hint` and `.solution` fenced div names an `exercise=`
  that some `{webr}` cell defines, and no graded exercise (one with a
  `check: true` cell) has a `.solution` div, which the grader cannot
  read.

Three further checks report *warnings* rather than errors: with
`error = TRUE` they are shown as one warning and do not stop. They cover
house style that a tutorial can violate and still work:

- `fences` – every fenced code block names a language
  (```` ```bash ````, ```` ```r ````) or is marked
  ```` ```{.output} ````. A bare ```` ``` ```` block renders as plain
  text with no way to tell a command from its output. See the "Code,
  commands and output" section of
  [`vignette("translating")`](https://ppbds.github.io/learnr2/articles/translating.md).

- `mentions` – the prose does not mention 'learnr' or
  'tutorial.helpers'. Students should never hear of either. Text inside
  a code block is not checked, since a quoted file may well name them.

- `yaml` – the YAML header has none of the classic learnr keys
  (`output`, `runtime`, `tutorial`, `progressive`, `allow_skip`) and no
  document-wide `execute: echo: false`, which is not known to be safe
  for `{webr}` cells.

## Examples

``` r
qmd <- create_tutorial("checked", dir = tempfile(), open = FALSE)
#> Created tutorial: /tmp/RtmpYt9aOK/file195024ce90e7/checked/checked.qmd
check_tutorial(qmd)

# Break the template, then see the problems instead of an error.
lines <- readLines(qmd)
writeLines(lines[!grepl("^#\\| echo: false", lines)], qmd)
problems <- check_tutorial(qmd, error = FALSE)
problems[, c("check", "message")]
#>   check                                                               message
#> 1  echo line 16 (student-information-1): widget chunk needs `#| echo: false`.
#> 2  echo     line 55 (a-quiz-question-1): widget chunk needs `#| echo: false`.
#> 3  echo        line 68 (your-answers-1): widget chunk needs `#| echo: false`.
#> 4  echo        line 78 (your-answers-2): widget chunk needs `#| echo: false`.

unlink(dirname(dirname(qmd)), recursive = TRUE)
```
