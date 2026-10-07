# learnr2 (development version)

* `run_tutorial()` now caches renders. A Quarto tutorial is rendered into
  `output_dir/<package>/<name>/` together with a stamp recording the learnr2
  version and a fingerprint of the installed tutorial files; while both
  still match, the next launch serves the cached copy at once instead of
  spending seconds (or, on a small cloud machine, half a minute) in Quarto.
  `refresh = TRUE` forces a re-render, which always starts from a clean
  directory so stale files cannot linger. New `prerender_tutorials()` fills
  the cache for every installed Quarto tutorial ahead of time, for container
  images and other environment builds.
* `run_tutorial()` always serves on port 7446 (`options(learnr2.port = )`
  overrides) and never falls back to a random port, and it serves the whole
  cache root so every tutorial has its own stable address,
  `http://127.0.0.1:7446/<package>/<name>/`. Saved answers are keyed by page
  URL, so this is what makes them findable on the next launch; it also means
  one tutorial's "Start Over" no longer wipes every tutorial's progress, and
  boilerplate questions sharing an id no longer bleed between tutorials
  (both of which happened while every tutorial was served at the same root
  URL). If a learnr2 server is already running, a new `run_tutorial()` just
  opens the tutorial there; if the port is held by anything else, it errors
  instead of silently serving somewhere the browser has no saved answers.
  **Breaking for readers mid-tutorial:** answers saved under the old root
  address are not carried over to the new per-tutorial address.
* `available_tutorials()` and `run_tutorial()` now see a package loaded from
  its source tree with `pkgload::load_all()`, as `devtools::load_all()` and
  `devtools::test()` do, reading its tutorials from the source
  `inst/tutorials/`. Previously they resolved only against installed
  packages, so a content package's own `devtools::test()` found no tutorials
  (or silently tested a stale installed copy). Installed packages behave as
  before, and 'pkgload' is not required.
* `run_tutorial()` now runs classic 'learnr' tutorials too. When the named
  tutorial's `format` is `"rmarkdown"` (an `.Rmd` with
  `runtime: shiny_prerendered`), it is handed to `learnr::run_tutorial()`
  instead of being rendered with Quarto, so a tool such as the "R Tutorials"
  VS Code extension can list and run both kinds of tutorial through learnr2
  alone. 'learnr' is only Suggested: any package that bundles classic
  tutorials already depends on it, so it is installed whenever such a
  tutorial is. `open = FALSE` is an error for an `"rmarkdown"` tutorial,
  which has no render-only mode.
* `available_tutorials()` gains a `package_dependencies` list column, the R
  packages each tutorial needs installed locally: `character(0)` for a
  `"quarto"` tutorial (its exercises run in the browser via WebR), what
  `learnr::available_tutorials()` reports for an `"rmarkdown"` one, or `NA`
  when 'learnr' is not installed to ask.
* New `render_tutorials()` and `check_tutorial()`, learnr2's counterparts of
  'tutorial.helpers'' `knit_tutorials()` and `check_tutorial_defaults()`, so
  a content package can test its tutorials: `render_tutorials()` copies each
  tutorial to a work directory, adds the 'quarto-live' extension, renders it
  with Quarto, and errors naming any tutorial that fails; `check_tutorial()`
  runs static checks for the authoring mistakes a successful render does not
  catch (missing `#| label:`, `echo: false`, `persist: true`, a graded
  exercise without a `solution: true` cell, a `{webr}` package missing from
  `webr: packages:`, and the standard boilerplate). `run_tutorial()` and the
  package's own GitHub Pages publishing now render through
  `render_tutorials()`, and learnr2's test suite renders every bundled
  tutorial for real (skipped on CRAN and where Quarto is not installed).
* `available_tutorials()` gains a `path` column, the installed `.qmd`/`.Rmd`
  file, ready to pass to `render_tutorials()` and `check_tutorial()`.
* New `show_file()`, ported from 'tutorial.helpers' together with its tests:
  print all or part of a text file, rows matching a pattern, its code chunks,
  or its YAML header. Two changes from the original: the default
  (`chunk = "auto"`) now shows the *last code chunk* of a file that has
  chunks -- the overwhelmingly common use -- and the whole file otherwise
  (pass `chunk = "None"` or `start = 0` for the whole file of a `.qmd`;
  supplying `start`, `end`, or `pattern` also switches back to rows); and
  `chunk = "<label>"` shows the chunk with that label, which some existing
  tutorials already call as if it worked.

# learnr2 0.1.1

* `question()` gains `show_text`. Set `show_text = FALSE` to keep the prompt
  out of the widget box when it is already written as ordinary text on the
  page above it; the prompt stays in the saved data and is still read by
  screen readers.
* Printing a `question()`, `quiz()`, `student_info()`, or
  `download_answers_button()` at the console now opens a browser preview only
  in an interactive session; non-interactive prints (scripts, `R CMD check`)
  emit the HTML source instead of launching the system browser.

# learnr2 0.0.0

We hope to replace both **learnr** and **tutorial.helpers** with **learnr2**. There is no reason to have two packages, or to not have **learnr2** do everything we want a tutorial package to do.

Create interactive R tutorials that run entirely in the browser using 'Quarto' and 'WebR' via the 'quarto-live' extension.
