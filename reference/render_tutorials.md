# Render tutorials, as a test that they build

Renders each tutorial with Quarto, exactly the way
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
and the package's own GitHub Pages publishing do: the tutorial's
directory is copied under `output_dir`, the bundled 'quarto-live'
extension is added next to the copy with
[`add_live_extension()`](https://ppbds.github.io/learnr2/reference/add_live_extension.md),
and the copy is rendered with
[`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html).
A tutorial that fails to render stops with an error naming it. This is
the learnr2 counterpart of `tutorial.helpers::knit_tutorials()`:
"testing" a tutorial means confirming it renders without error, which
catches a large class of mistakes that look fine in the `.qmd` source
(see also
[`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)
for the static checks that complement it).

## Usage

``` r
render_tutorials(paths, output_dir = tempfile("learnr2-render-"), quiet = TRUE)
```

## Arguments

- paths:

  Character vector of tutorials to render: paths to `.qmd` files, or to
  the directories that contain them (the first `.qmd` in each directory
  is used).
  [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)'s
  `path` column and
  [`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)'s
  return value are both accepted directly.

- output_dir:

  Directory to render into. Each tutorial is copied to
  `output_dir/<tutorial-directory-name>/` first, so the installed source
  is never written to. Defaults to a fresh directory under the session's
  temporary directory, which is also the only place CRAN permits a test
  to write.

- quiet:

  Passed to
  [`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html).
  Defaults to `TRUE`; set `FALSE` to see Quarto's own progress output,
  e.g. in CI logs.

## Value

A character vector of paths to the rendered `.html` files, named by
tutorial (the directory name), invisibly.

## Details

Nothing here boots WebR or exercises the rendered page in a browser –
that happens in the reader's browser, not at render time – so a
successful render proves the document builds, not that every exercise
behaves. Each tutorial's render time is reported, since a slow one is
usually the first sign of something that will also be slow for readers.

## In a content package's tests

A package of tutorials can check every one of them from
`tests/testthat/test-tutorials.R`:

    tutorials <- available_tutorials(package = "my.tutorials")
    render_tutorials(tutorials$path)
    check_tutorial(tutorials$path)

Guard that test with
[`testthat::skip_on_cran()`](https://testthat.r-lib.org/reference/skip.html)
and `testthat::skip_if(is.null(quarto::quarto_path()))`, since it needs
the Quarto command line tool.

## Examples

``` r
# Scaffold a tutorial, then render it the way a test would. Needs the
# Quarto command line tool, so this is skipped where it isn't installed.
if (!is.null(quarto::quarto_path())) {
  dir <- tempfile()
  qmd <- create_tutorial("render-me", dir = dir, open = FALSE)
  html <- render_tutorials(qmd)
  file.exists(html)
  unlink(c(dir, dirname(html)), recursive = TRUE)
}
#> Created tutorial: /tmp/RtmpJNwFxM/file19d425feb199/render-me/render-me.qmd
#> Rendering render-me (/tmp/RtmpJNwFxM/file19d425feb199/render-me/render-me.qmd) ...
#> Rendered render-me in 3.6s: /tmp/RtmpJNwFxM/learnr2-render-19d4742eeabd/render-me/render-me.html
#> Rendered 1 tutorial(s).
```
