# Run a bundled tutorial

Runs a tutorial bundled with an installed package, whichever of the two
formats
[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
reports it is. A `"quarto"` tutorial (learnr2's own format) is rendered
to `output_dir` and, when `open` is `TRUE`, served to a browser. Because
installed tutorials live in a read-only package library, the tutorial is
copied to a writable location and the 'quarto-live' extension is added
before rendering. An `"rmarkdown"` tutorial – a classic 'learnr'
tutorial – is handed to
[`learnr::run_tutorial()`](https://pkgs.rstudio.com/learnr/reference/run_tutorial.html),
so a tool built on learnr2 (such as the "R Tutorials" VS Code extension)
can run both kinds through this one function and depend only on learnr2.
See the section below.

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
  (e.g. a 'primer.tutorials'-style content package), or from one loaded
  with
  [`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
  (see
  [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)).

- output_dir:

  Directory in which to render a `"quarto"` tutorial (ignored for an
  `"rmarkdown"` one). Defaults to a persistent per-user cache directory
  (see [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)),
  *not* [`tempfile()`](https://rdrr.io/r/base/tempfile.html) – R deletes
  its own session temp directory as soon as the R process exits, which
  races with (and often loses to) the browser actually loading the page
  when `open = TRUE` is used non-interactively (e.g. via `Rscript`),
  producing a "file not found" page. Pass your own `output_dir` for a
  one-off location instead.

- open:

  Whether to serve the tutorial and open it in a browser. Defaults to
  `TRUE` when interactive. When `TRUE`, this call blocks (like
  [`httpuv::runStaticServer()`](https://rstudio.github.io/httpuv/reference/runStaticServer.html)
  or [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html))
  until you interrupt it (Ctrl+C, or the console's Stop button) – see
  the section below for why. When `FALSE`, a `"quarto"` tutorial is
  rendered and its path returned without serving or blocking; an
  `"rmarkdown"` tutorial has no render-only mode (it is a Shiny app), so
  `open = FALSE` is an error. Note that under `Rscript` the default is
  `FALSE`, so pass `open = TRUE` explicitly there.

## Value

Path to the rendered HTML file for a `"quarto"` tutorial, or to the
`.Rmd` source for an `"rmarkdown"` one, invisibly.

## Classic learnr tutorials

Many existing content packages (those built on 'tutorial.helpers', for
instance) bundle classic 'learnr' tutorials: `.Rmd` files with
`runtime: shiny_prerendered` that run as a Shiny app in the local R
session. learnr2 cannot run those itself – the Shiny machinery lives in
'learnr' – so for an `"rmarkdown"` tutorial this function calls
`learnr::run_tutorial(name, package = package)`, which blocks while the
app runs just as the `"quarto"` path blocks while serving.

'learnr' is only a suggested dependency of learnr2, not a required one,
because a package that bundles classic learnr tutorials already depends
on 'learnr' itself (directly, or via 'tutorial.helpers'). So whenever an
`"rmarkdown"` tutorial is installed, 'learnr' is too; this function only
errors with an install hint if that invariant is somehow broken.

## Why this blocks and serves over local HTTP instead of opening the file directly

Every `{webr}` exercise compiles down to Observable JS (OJS), which
Quarto's runtime loads via ES modules – and browsers refuse to load ES
modules from a `file://` URL. Opening the rendered HTML directly (e.g.
[`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html) on the
local path, or double-clicking the file) hits this and shows an "OJS
runtime" error, even though plain
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)/[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
widgets (not OJS-based) work fine over `file://`.

An earlier version of this function used
[`quarto::quarto_preview()`](https://quarto-dev.github.io/quarto-r/reference/quarto_preview.html)
to both render and serve the tutorial via a background daemon process,
on the theory that it would keep running after `run_tutorial()`
returned. In practice that daemon did not reliably stay alive
(confirmed: it could exit within seconds, even with the calling R
session still running and pumping its event loop), silently leaving you
back at a `file://` URL with no server behind it. This function now
renders with the same one-shot
[`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html)
call the package's own pkgdown publishing script uses, and serves the
result with
[`httpuv::runStaticServer()`](https://rstudio.github.io/httpuv/reference/runStaticServer.html)
– an in-process server with no separate daemon to lose track of. Its
trade-off is that it blocks the caller while serving, matching how the
original 'learnr' package's `run_tutorial()` (built on a blocking Shiny
app) behaved – stop the server to get your prompt back.

## Examples

``` r
# With no `name`, just lists the tutorials that can be run.
run_tutorial()
#> Available tutorials in learnr2:
#>   - getting-started
#>   - hello-learnr2
#>   - intro-vectors

# Not run: needs the Quarto command line tool, and, when `open = TRUE`,
# starts a local web server that blocks the session until interrupted.
if (FALSE) { # \dontrun{
run_tutorial("hello-learnr2")

# A classic learnr tutorial from a content package is handed to learnr.
run_tutorial("hello", package = "learnr", open = TRUE)
} # }
```
