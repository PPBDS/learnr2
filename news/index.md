# Changelog

## learnr2 (development version)

- [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
  and
  [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
  now see a package loaded from its source tree with
  [`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html),
  as `devtools::load_all()` and `devtools::test()` do, reading its
  tutorials from the source `inst/tutorials/`. Previously they resolved
  only against installed packages, so a content package’s own
  `devtools::test()` found no tutorials (or silently tested a stale
  installed copy). Installed packages behave as before, and ‘pkgload’ is
  not required.
- [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
  now runs classic ‘learnr’ tutorials too. When the named tutorial’s
  `format` is `"rmarkdown"` (an `.Rmd` with
  `runtime: shiny_prerendered`), it is handed to
  [`learnr::run_tutorial()`](https://pkgs.rstudio.com/learnr/reference/run_tutorial.html)
  instead of being rendered with Quarto, so a tool such as the “R
  Tutorials” VS Code extension can list and run both kinds of tutorial
  through learnr2 alone. ‘learnr’ is only Suggested: any package that
  bundles classic tutorials already depends on it, so it is installed
  whenever such a tutorial is. `open = FALSE` is an error for an
  `"rmarkdown"` tutorial, which has no render-only mode.
- [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
  gains a `package_dependencies` list column, the R packages each
  tutorial needs installed locally: `character(0)` for a `"quarto"`
  tutorial (its exercises run in the browser via WebR), what
  [`learnr::available_tutorials()`](https://pkgs.rstudio.com/learnr/reference/available_tutorials.html)
  reports for an `"rmarkdown"` one, or `NA` when ‘learnr’ is not
  installed to ask.
- New
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md)
  and
  [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md),
  learnr2’s counterparts of ‘tutorial.helpers’’ `knit_tutorials()` and
  `check_tutorial_defaults()`, so a content package can test its
  tutorials:
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md)
  copies each tutorial to a work directory, adds the ‘quarto-live’
  extension, renders it with Quarto, and errors naming any tutorial that
  fails;
  [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)
  runs static checks for the authoring mistakes a successful render does
  not catch (missing `#| label:`, `echo: false`, `persist: true`, a
  graded exercise without a `solution: true` cell, a
  [webr](https://github.com/cardiomoon/webr) package missing from
  `webr: packages:`, and the standard boilerplate).
  [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
  and the package’s own GitHub Pages publishing now render through
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md),
  and learnr2’s test suite renders every bundled tutorial for real
  (skipped on CRAN and where Quarto is not installed).
- [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
  gains a `path` column, the installed `.qmd`/`.Rmd` file, ready to pass
  to
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md)
  and
  [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md).
- New
  [`show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md),
  ported from ‘tutorial.helpers’ together with its tests: print all or
  part of a text file, rows matching a pattern, its code chunks, or its
  YAML header. Two changes from the original: the default
  (`chunk = "auto"`) now shows the *last code chunk* of a file that has
  chunks – the overwhelmingly common use – and the whole file otherwise
  (pass `chunk = "None"` or `start = 0` for the whole file of a `.qmd`;
  supplying `start`, `end`, or `pattern` also switches back to rows);
  and `chunk = "<label>"` shows the chunk with that label, which some
  existing tutorials already call as if it worked.

## learnr2 0.1.1

- [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  gains `show_text`. Set `show_text = FALSE` to keep the prompt out of
  the widget box when it is already written as ordinary text on the page
  above it; the prompt stays in the saved data and is still read by
  screen readers.
- Printing a
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md),
  [`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
  [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
  or
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
  at the console now opens a browser preview only in an interactive
  session; non-interactive prints (scripts, `R CMD check`) emit the HTML
  source instead of launching the system browser.

## learnr2 0.0.0

We hope to replace both **learnr** and **tutorial.helpers** with
**learnr2**. There is no reason to have two packages, or to not have
**learnr2** do everything we want a tutorial package to do.

Create interactive R tutorials that run entirely in the browser using
‘Quarto’ and ‘WebR’ via the ‘quarto-live’ extension.
