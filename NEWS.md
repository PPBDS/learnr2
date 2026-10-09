# learnr2 (development version)

* `create_tutorial(open = TRUE)` now opens the new file with each
  editor's own mechanism: `file.edit()` in RStudio and Positron, and VS
  Code's `code` command in a VS Code terminal or Codespace. Anywhere else
  it prints the path, instead of handing the `.qmd` to whatever app the
  operating system associates with it. rstudioapi is no longer used, and
  pkgdown moves from Suggests to `Config/Needs/website`, since only the
  website build uses it. learnr2's Suggests are now just pkgload,
  testthat and withr, all for the tests.

* learnr2 no longer depends on learnr, even as a suggested package, and no
  longer runs classic learnr tutorials. `available_tutorials()` lists only
  `.qmd` tutorials, skipping directories that hold only a classic `.Rmd`.
  `run_tutorial()` on a classic tutorial stops with a message to run it
  with `learnr::run_tutorial()`; it used to hand such tutorials to learnr
  itself. For compatibility, `available_tutorials()` keeps its `type`
  argument (`"all"` and `"quarto"` give the same list; `"rmarkdown"` is now
  an error) and its `format` and `package_dependencies` columns, which are
  now always `"quarto"` and `character(0)`.
  **Breaking for tools** that ran classic tutorials through learnr2, such
  as the R Tutorials VS Code extension: they must now call learnr for
  those directly.

* Pasted screenshots are now scaled to at most 1600 pixels wide and stored
  as WebP (JPEG in Safari) of at most about 450KB, instead of full-size
  PNG. A few large screenshots could previously fill the browser's
  storage, which every tutorial on a site shares. The paste limit rises
  from 2MB to 20MB, since the stored image is shrunk anyway.
* When the browser refuses to save an answer (storage full or blocked),
  the page now shows a warning and the answer stays unsubmitted.
  Previously the failure was silent, and the answer was missing from the
  download.

# learnr2 0.1.3

* `student_info()` and `"reflection_editable"` questions now have a clear
  Edit/Submit cycle. Submit locks the fields behind an "Edit" button; Edit
  reopens them, with the button back to "Submit" and a note that changes
  aren't saved until then. Previously the fields stayed open after Submit
  and "Edit" silently resaved, so readers couldn't tell whether a change
  had gone in. The download now reports only submitted answers, and is
  blocked until every `student_info()` form is submitted.
  **Behaviour change:** a reader who filled in student info without
  pressing Submit must now press it before downloading.
* A Continue button no longer appears directly under a section heading.
  A subsection that starts right after its parent's heading, as every
  tutorial.helpers topic does with `## Title` then `###`, is now revealed
  with the heading.
* Links that leave a tutorial page now open in a new tab, so following one
  never makes the tutorial disappear.

# learnr2 0.1.2

* `tutorial_options()` gains `require_submission`, default `TRUE`: the
  "Continue" button at the end of a section is disabled, with a note under
  it, until every `question()` and `student_info()` form above it in that
  section has been submitted. With `type = "reflection"` questions, which
  lock on submit, a tutorial can show its own answer right after the
  reader's without inviting them to copy it back. Reference material can
  opt out with `require_submission = FALSE`, as `hello-learnr2` does.
  **Behaviour change for existing tutorials:** readers must now submit
  every question in a section before continuing.
* New `tutorial_options()`, for settings that apply to a whole tutorial
  page. Its first option, `allow_skip`, controls the table of contents:
  by default (`FALSE`) a sidebar entry for a section the reader has not
  reached yet is dimmed and does nothing when clicked, becoming a working
  link only once that section is unlocked, so the sidebar cannot be used
  to read the whole tutorial at once. `tutorial_options(allow_skip = TRUE)`
  restores the previous behaviour, where clicking any entry unlocked every
  section up to it and jumped there. Call it once, in an `echo: false`
  chunk; `check_tutorial()` treats such a chunk as a widget chunk.
  **Behaviour change for existing tutorials:** none of them opted in, so
  all of them now lock the sidebar.
* The "Start Over" button no longer depends on the table-of-contents
  sidebar. A tutorial rendered with `toc: false` used to have no Start
  Over at all, and every tutorial lost it on a phone-width screen, where
  Quarto hides the sidebar. The button now sits at the bottom of the
  sidebar when one is showing and otherwise at the top of the tutorial,
  directly under the title, moving between the two as the window resizes.
* The `getting-started` and `intro-vectors` tutorials are no longer
  bundled; `hello-learnr2` is the one bundled tutorial, and it gained a
  "Layout options" section describing `toc`, `allow_skip` and Start Over.
  `getting-started` lives on in 'primer.tutorials'.

* CRAN review: `create_tutorial()` and `add_live_extension()` no longer
  default `dir` to the working directory; `dir` is required, so neither
  function writes anywhere the caller did not name (pass `dir = "."` for the
  old behaviour). `available_tutorials()` with no `package` now finds
  packages by listing the libraries on `.libPaths()` for a `tutorials/`
  directory instead of calling `utils::installed.packages()`, which reads
  several files per installed package. The package now declares
  `Depends: R (>= 4.0.0)`, which `tools::R_user_dir()` (the render cache
  `run_tutorial()` writes to) requires.
* `run_tutorial()` now works from GitHub Codespaces (and any other remote
  container that forwards ports). Two things were wrong. The cache root the
  server serves had no page of its own, so httpuv answered `/` with a bare
  404 -- and `/` is exactly what the "Open in Browser" button on VS Code's
  and Codespaces' new-port notification opens, since it only knows the port,
  not the tutorial's path. The root is now a small page that forwards to the
  tutorial launched most recently and lists every other rendered tutorial.
  And the address printed and opened was always `http://127.0.0.1:7446/...`,
  which inside a codespace is reachable only from the container; in a
  codespace (detected from `CODESPACE_NAME` and
  `GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN`) the forwarded
  `https://<codespace>-7446.app.github.dev/<package>/<name>/` address is
  used instead. `run_tutorial()` also honours a `BROWSER` environment
  variable (VS Code sets one in its terminals that opens pages on the
  user's own machine) ahead of R's `browser` option. The render stamp now
  records the tutorial's title, for the root listing.
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
