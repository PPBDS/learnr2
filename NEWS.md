# learnr2 (development version)

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

* Printing a `question()`, `quiz()`, `student_info()`, or
  `download_answers_button()` at the console now opens a browser preview only
  in an interactive session; non-interactive prints (scripts, `R CMD check`)
  emit the HTML source instead of launching the system browser.

# learnr2 0.0.0

We hope to replace both **learnr** and **tutorial.helpers** with **learnr2**. There is no reason to have two packages, or to not have **learnr2** do everything we want a tutorial package to do.

Create interactive R tutorials that run entirely in the browser using 'Quarto' and 'WebR' via the 'quarto-live' extension.
