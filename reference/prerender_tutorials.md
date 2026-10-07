# Render every installed Quarto tutorial into the cache

Fills
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)'s
render cache ahead of time, so that the first launch of each tutorial is
as fast as every later one. Intended for environment builds – a
container image, a Codespaces prebuild, a lab machine setup – where the
render cost can be paid once for everyone, before any student is
waiting. Tutorials whose cached render is already current are skipped.
Classic `"rmarkdown"` tutorials are not rendered: they are Shiny apps
and have nothing to cache.

## Usage

``` r
prerender_tutorials(
  package = NULL,
  output_dir = tools::R_user_dir("learnr2", "cache"),
  refresh = FALSE
)
```

## Arguments

- package:

  Name of a single package whose tutorials to render. Defaults to
  `NULL`, which renders the Quarto tutorials of every installed package.

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

- refresh:

  Re-render a `"quarto"` tutorial even if the cached render is current.
  Defaults to `FALSE`.

## Value

A data frame, invisibly, with one row per Quarto tutorial and columns
`package`, `name`, `html` (the rendered file) and `rendered` (`TRUE` if
it was rendered on this call, `FALSE` if the cached copy was already
current).

## Where the cache must live

The default `output_dir` is a per-user directory (see
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)), so
pre-rendering only helps if it runs *as the user who will later run the
tutorials*, with the same `HOME` – in a Dockerfile, as the image's
runtime user, not root – or with an `output_dir` both can see. The cache
is keyed on the installed tutorial files and the learnr2 version, so it
stays valid for as long as those are the ones baked in alongside it.

## See also

[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md),
whose "Render cache" section explains what makes a cached render
current.

## Examples

``` r
if (FALSE) { # \dontrun{
# Everything installed, into the default per-user cache.
prerender_tutorials()

# One package, forcing a rebuild.
prerender_tutorials(package = "learnr2", refresh = TRUE)
} # }
```
