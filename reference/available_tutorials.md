# List tutorials bundled with learnr2 (or any installed package)

Scans one package – or, by default, every package installed – for a
bundled `inst/tutorials/` directory, the same convention 'learnr' uses.
This lets tools like the "R Tutorials" VS Code extension discover
tutorials from separately-installed content packages (in the style of
'primer.tutorials') without knowing their names in advance.

## Usage

``` r
available_tutorials(package = NULL, type = "all")
```

## Arguments

- package:

  Name of a single package to scan. Defaults to `NULL`, which scans
  every installed package.

- type:

  Which authoring format to include: `"quarto"` (tutorials whose
  top-level document is a `.qmd`), `"rmarkdown"` (a `.Rmd`), or `"all"`
  (the default) for both.

## Value

A data frame with one row per tutorial and columns `package`, `name`,
`title` (`NA` if the tutorial's `.qmd`/`.Rmd` has no YAML `title`), and
`format` (`"quarto"` or `"rmarkdown"`). `name` can be passed to
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md).

## Examples

``` r
# Qualified with learnr2:: because the learnr package exports a function of
# the same name; this guarantees learnr2's version is used even if learnr is
# also attached and masks it on the search path.
learnr2::available_tutorials(package = "learnr2")
#>   package            name                                  title format
#> 1 learnr2 getting-started Getting Started with learnr2 Tutorials quarto
#> 2 learnr2   hello-learnr2                         Hello, learnr2 quarto
#> 3 learnr2   intro-vectors                  Intro to Vectors in R quarto
learnr2::available_tutorials(package = "learnr2", type = "quarto")
#>   package            name                                  title format
#> 1 learnr2 getting-started Getting Started with learnr2 Tutorials quarto
#> 2 learnr2   hello-learnr2                         Hello, learnr2 quarto
#> 3 learnr2   intro-vectors                  Intro to Vectors in R quarto
```
