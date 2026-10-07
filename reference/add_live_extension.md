# Add the 'quarto-live' extension to a project

Copies the bundled 'quarto-live' extension into `dir/_extensions/` so
that Quarto documents in `dir` can use `format: live-html`. This is the
non-interactive equivalent of `quarto add r-wasm/quarto-live`.

## Usage

``` r
add_live_extension(dir, overwrite = TRUE)
```

## Arguments

- dir:

  Directory of the Quarto project or document. Required: there is no
  default, so nothing is written anywhere you did not name. Pass `"."`
  for the current working directory.

- overwrite:

  Overwrite an existing copy of the extension? Defaults to `TRUE`.

## Value

The path to the project's `_extensions` directory, invisibly.

## Examples

``` r
dir <- tempfile()
add_live_extension(dir)
list.files(dir, recursive = TRUE, all.files = TRUE)[1:3]
#> [1] "_extensions/r-wasm/live/LICENSE.md"    
#> [2] "_extensions/r-wasm/live/_extension.yml"
#> [3] "_extensions/r-wasm/live/_gradethis.qmd"
unlink(dir, recursive = TRUE)
```
