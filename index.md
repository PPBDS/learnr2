# learnr2

**learnr2** creates interactive R tutorials that run entirely in the
reader’s web browser using [Quarto](https://quarto.org) and
[WebR](https://docs.r-wasm.org/webr/), via the
[quarto-live](https://github.com/r-wasm/quarto-live) extension. It
offers [learnr](https://rstudio.github.io/learnr/)-style authoring
conveniences — scaffolding, exercises, hints, solutions, and quizzes —
**without Shiny, R Markdown, or a server**. A rendered tutorial is a
self-contained HTML page.

## Installation

Install the released version of learnr2 from
[CRAN](https://CRAN.R-project.org):

``` r

install.packages("learnr2")
```

Or install the development version from
[GitHub](https://github.com/PPBDS/learnr2):

``` r

# install.packages("pak")
pak::pak("PPBDS/learnr2")
```

You will also need the [Quarto
CLI](https://quarto.org/docs/get-started/).

## Usage

Try the bundled feature-tour tutorial:

``` r

library(learnr2)

available_tutorials()          # list tutorials bundled with a package
run_tutorial("hello-learnr2")  # render + open in your browser
```

Scaffold your own tutorial:

``` r

create_tutorial("my-tutorial", dir = ".")
```

This creates `my-tutorial/my-tutorial.qmd` (under the directory you
name; there is no default) with the quarto-live extension copied
alongside it, so it renders out of the box with Quarto or
[`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html).

## What’s inside a tutorial

- **Live code cells** — editable, runnable R that executes in the
  browser.
- **Exercises** — cells with blanks, plus `.hint` and `.solution`
  blocks.
- **Automatic grading** — powered by
  [gradethis](https://rstudio.github.io/gradethis/).
- **Quiz questions** —
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  / [`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
  graded in the browser with plain JavaScript, including single/multiple
  choice, free-text, and reflection questions (optionally answered with
  a pasted screenshot). Answers persist in the browser’s `localStorage`.
- **Student info and submission** —
  [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
  collects a name and email;
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
  bundles every saved answer into a JSON file the reader can turn in. No
  server involved.
- **Progressive reveal** — sections unlock one at a time behind
  “Continue” buttons, the table of contents can’t be used to read ahead
  unless `tutorial_options(allow_skip = TRUE)` says so, and every page
  has a “Start Over” button that clears saved progress.

See the bundled `hello-learnr2` tutorial and the reference index for
details. Two vignettes cover writing tutorials: “Tutorials in the Age of
AI” on how a tutorial should teach, and “Translating learnr Tutorials”
on how one is put together, including converting an existing learnr
tutorial.
