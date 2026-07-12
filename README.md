# learnr2

<!-- badges: start -->
[![R-CMD-check](https://github.com/PPBDS/learnr2/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/PPBDS/learnr2/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

**learnr2** creates interactive R tutorials that run entirely in the reader's
web browser using [Quarto](https://quarto.org) and
[WebR](https://docs.r-wasm.org/webr/), via the
[quarto-live](https://github.com/r-wasm/quarto-live) extension. It offers
[learnr](https://rstudio.github.io/learnr/)-style authoring conveniences ---
scaffolding, exercises, hints, solutions, and quizzes --- **without Shiny, R
Markdown, or a server**. A rendered tutorial is a self-contained HTML page.

## Installation

```r
# install.packages("pak")
pak::pak("PPBDS/learnr2")
```

You will also need the [Quarto CLI](https://quarto.org/docs/get-started/).

## Usage

Try the bundled feature-tour tutorial:

```r
library(learnr2)

available_tutorials()          # list tutorials bundled with a package
run_tutorial("hello-learnr2")  # render + open in your browser
```

Scaffold your own tutorial:

```r
create_tutorial("my-tutorial")
```

This creates `my-tutorial/my-tutorial.qmd` with the quarto-live extension
copied alongside it, so it renders out of the box with Quarto or
`quarto::quarto_render()`.

## What's inside a tutorial

- **Live code cells** — editable, runnable R that executes in the browser.
- **Exercises** — cells with blanks, plus `.hint` and `.solution` blocks.
- **Automatic grading** — powered by
  [gradethis](https://pkgs.rstudio.com/gradethis/).
- **Quiz questions** — `question()` / `quiz()`, graded in the browser with
  plain JavaScript, including single/multiple choice, free-text, and
  reflection questions. Answers persist in the browser's `localStorage`.

See the reference index and the bundled `hello-learnr2` tutorial for details.
