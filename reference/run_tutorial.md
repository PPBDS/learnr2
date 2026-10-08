# Run a bundled tutorial

Runs a tutorial bundled with an installed package, whichever of the two
formats
[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
reports it is. A `"quarto"` tutorial (learnr2's own format) is rendered
into a per-user cache – or reused from it, if it was rendered before and
nothing has changed – and, when `open` is `TRUE`, served to a browser.
An `"rmarkdown"` tutorial – a classic 'learnr' tutorial – is handed to
[`learnr::run_tutorial()`](https://pkgs.rstudio.com/learnr/reference/run_tutorial.html),
so a tool built on learnr2 (such as the "R Tutorials" VS Code extension)
can run both kinds through this one function and depend only on learnr2.

## Usage

``` r
run_tutorial(
  name = NULL,
  package = "learnr2",
  output_dir = tools::R_user_dir("learnr2", "cache"),
  open = interactive(),
  refresh = FALSE
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

  Root of the render cache for `"quarto"` tutorials (ignored for an
  `"rmarkdown"` one). Each tutorial is rendered into
  `output_dir/<package>/<name>/`. Defaults to a persistent per-user
  directory (see
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)), *not*
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html): a persistent
  location is what makes the render cache (below) work at all, and R
  deletes its session temp directory as soon as the R process exits,
  which races with the browser actually loading the page when
  `open = TRUE` is used from `Rscript`.

- open:

  Whether to serve the tutorial and open it in a browser. Defaults to
  `TRUE` when interactive. When `TRUE`, this call blocks (like
  [`httpuv::runStaticServer()`](https://rstudio.github.io/httpuv/reference/runStaticServer.html)
  or [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html))
  until you interrupt it (Ctrl+C, or the console's Stop button) – see
  the sections below for why. When `FALSE`, a `"quarto"` tutorial is
  rendered (or found in the cache) and its path returned without serving
  or blocking; an `"rmarkdown"` tutorial has no render-only mode (it is
  a Shiny app), so `open = FALSE` is an error for one. Note that under
  `Rscript` the default is `FALSE`, so pass `open = TRUE` explicitly
  there.

- refresh:

  Re-render a `"quarto"` tutorial even if the cached render is current.
  Defaults to `FALSE`.

## Value

Path to the rendered HTML file for a `"quarto"` tutorial, or to the
`.Rmd` source for an `"rmarkdown"` one, invisibly.

## Render cache

Rendering a Quarto tutorial takes several seconds on a laptop and well
over ten on a small cloud machine, and nothing about an installed
tutorial changes between one launch and the next. So the render is
cached: alongside the HTML in `output_dir/<package>/<name>/`, a stamp
file records the learnr2 version and a fingerprint of every file in the
installed tutorial directory. On the next launch, if both still match,
the cached HTML is served at once. Reinstalling the tutorial's package
or upgrading learnr2 invalidates the cache; so does `refresh = TRUE`.
Before any re-render the old copy is deleted, so files a previous
version of the tutorial had and the current one does not cannot linger.

[`prerender_tutorials()`](https://ppbds.github.io/learnr2/reference/prerender_tutorials.md)
fills the cache for every installed Quarto tutorial ahead of time – for
instance while building a container image – so that even a student's
first launch is instant.

## Serving, the fixed port, and saved answers

A reader's answers and typed exercise code are saved in the browser's
`localStorage`, keyed by the page URL (see "Progress persistence" in
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)).
For them to be found again tomorrow, the URL has to be the same
tomorrow. So learnr2 always serves on one fixed port, 7446
(`getOption("learnr2.port")` overrides it), and never falls back to a
random one; and it serves the whole cache root rather than a single
tutorial, so every tutorial has its own stable address,
`http://127.0.0.1:7446/<package>/<name>/`, and no two tutorials share
saved state or get wiped together by one tutorial's "Start Over".

Because the server serves the whole cache, one server is enough for any
number of tutorials. If a learnr2 server is already running on the port
(say, in another terminal), this function renders into the cache if
needed and simply opens the tutorial's address in the browser, without
starting a second server or blocking. If the port is held by something
other than a learnr2 server, it stops with an error rather than silently
serving somewhere the browser has no saved answers for.

The cache root itself (`http://127.0.0.1:7446/`) is a small page that
forwards to the tutorial launched most recently and lists every other
rendered tutorial in the cache. That root is what a tool that only knows
the port opens – notably the "open in browser" notification VS Code and
GitHub Codespaces show when they detect a new local port – so landing on
it has to reach the tutorial rather than a 404.

## Running in GitHub Codespaces (or another remote container)

The server runs inside the container, so `http://127.0.0.1:7446/...` is
only reachable from inside it; in the browser on your own machine that
address refuses to connect. Codespaces forwards the port to a public
address, `https://<codespace>-7446.app.github.dev/`, and this function
detects a codespace (the `CODESPACE_NAME` and
`GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN` environment variables) and
prints the tutorial's forwarded address. The browser is still opened on
the local address, through the helper VS Code puts in `BROWSER`, which
forwards the port as part of opening it, just as clicking a localhost
link in the terminal does; opening the forwarded address directly can
race the port forwarding and show an empty 404 until reloaded. The
forwarded root page forwards to the tutorial too, so the "Open in
Browser" button on the port notification lands in the right place. Saved
answers are keyed by page URL, so they live under the forwarded address
and are found again as long as the codespace keeps its name.

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
result with httpuv's static server – an in-process server with no
separate daemon to lose track of. Its trade-off is that it blocks the
caller while serving, matching how the original 'learnr' package's
`run_tutorial()` (built on a blocking Shiny app) behaved – stop the
server to get your prompt back.

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

## See also

[`prerender_tutorials()`](https://ppbds.github.io/learnr2/reference/prerender_tutorials.md)
to fill the render cache in advance.

## Examples

``` r
# With no `name`, just lists the tutorials that can be run.
run_tutorial()
#> Available tutorials in learnr2:
#>   - hello-learnr2

# Render without serving (open = FALSE), into a temporary directory
# rather than the user cache. Needs the Quarto command line tool, so this
# is skipped where it isn't installed.
if (!is.null(quarto::quarto_path())) {
  out <- tempfile()
  html <- run_tutorial("hello-learnr2", output_dir = out, open = FALSE)
  file.exists(html)

  # A second call reuses the cached render; refresh = TRUE forces a new one.
  run_tutorial("hello-learnr2", output_dir = out, open = FALSE, refresh = TRUE)
  unlink(out, recursive = TRUE)
}
#> Rendering hello-learnr2 (/home/runner/work/_temp/Library/learnr2/tutorials/hello-learnr2/hello-learnr2.qmd) ...
#> Rendered hello-learnr2 in 4.4s: /tmp/Rtmpe5jUku/file19b5740ab341/learnr2/hello-learnr2/hello-learnr2.html
#> Rendered 1 tutorial(s).
#> Rendering hello-learnr2 (/home/runner/work/_temp/Library/learnr2/tutorials/hello-learnr2/hello-learnr2.qmd) ...
#> Rendered hello-learnr2 in 4.4s: /tmp/Rtmpe5jUku/file19b5740ab341/learnr2/hello-learnr2/hello-learnr2.html
#> Rendered 1 tutorial(s).

# Not run: with open = TRUE, starts a local web server that blocks the
# session until interrupted.
if (FALSE) { # \dontrun{
run_tutorial("hello-learnr2")

# A classic learnr tutorial from a content package is handed to learnr.
run_tutorial("hello", package = "learnr", open = TRUE)
} # }
```
