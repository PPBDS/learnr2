# Path to the bundled 'quarto-live' extension

learnr2 ships a copy of the 'quarto-live' Quarto extension so that
authors do not need to run `quarto add` themselves. This returns the
path, inside the installed package, to the `_extensions` directory that
contains it.

## Usage

``` r
live_extension_dir()
```

## Value

A length-one character path to the bundled `_extensions` directory.

## Examples

``` r
live_extension_dir()
#> [1] "/home/runner/work/_temp/Library/learnr2/extdata/_extensions"
```
