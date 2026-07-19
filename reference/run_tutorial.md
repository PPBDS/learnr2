# Render and open a bundled tutorial

Renders a tutorial bundled with an installed package to a temporary
directory and, in an interactive session, opens the result in a browser.
Because installed tutorials live in a read-only package library, the
tutorial is copied to a writable location and the 'quarto-live'
extension is added before rendering.

## Usage

``` r
run_tutorial(
  name = NULL,
  package = "learnr2",
  output_dir = tools::R_user_dir("learnr2", "cache"),
  open = interactive()
)
```

## Arguments

- name:

  Name of the tutorial to run. See
  [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md).
  If `NULL`, the available tutorials in `package` are listed.

- package:

  Name of the package the tutorial is bundled with. Defaults to
  `"learnr2"`; set this to run a tutorial from another installed package
  (e.g. a 'primer.tutorials'-style content package).

- output_dir:

  Directory in which to render the tutorial. Defaults to a persistent
  per-user cache directory (see
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)), *not*
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html) – R deletes its
  own session temp directory as soon as the R process exits, which races
  with (and often loses to) the browser actually loading the page when
  `open = TRUE` is used non-interactively (e.g. via `Rscript`),
  producing a "file not found" page. Pass your own `output_dir` for a
  one-off location instead.

- open:

  Whether to open the rendered HTML in a browser. Defaults to `TRUE`
  when interactive.

## Value

Path to the rendered HTML file, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
run_tutorial("hello-learnr2")
} # }
```
