# List tutorials bundled with learnr2 (or any installed package)

Scans one package – or, by default, every package installed – for a
bundled `inst/tutorials/` directory, the same convention 'learnr' uses,
and lists the learnr2 tutorials in it: each subdirectory that contains a
`.qmd` document. Classic 'learnr' tutorials (`.Rmd`) in the same
directory are not listed; learnr2 neither lists nor runs them (see
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)).
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
  every installed package, plus any package currently loaded with
  [`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html).

- type:

  Kept so existing callers keep working: `"all"` (the default) and
  `"quarto"` both list every learnr2 tutorial. learnr2 no longer handles
  classic learnr tutorials, so `"rmarkdown"` is an error; use
  [`learnr::available_tutorials()`](https://pkgs.rstudio.com/learnr/reference/available_tutorials.html)
  for those.

## Value

A data frame with one row per tutorial and columns `package`, `name`,
`title` (`NA` if the tutorial's `.qmd` has no YAML `title`), `format`
(always `"quarto"`), `path` (the installed `.qmd` file), `ordering` (the
number set by `learnr2: ordering:` in the YAML header; `NA` if absent –
see "Ordering" below), and `package_dependencies` (a list column of the
R packages each tutorial needs installed locally: always `character(0)`,
since a learnr2 tutorial runs its code in the reader's browser).
`format` and `package_dependencies` carry no information any more; they
are kept so that tools written when learnr2 also listed classic
tutorials, such as the "R Tutorials" VS Code extension, keep working.
`name` can be passed to
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md);
`path` to
[`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md)
and
[`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md).

## Details

A package loaded from its source tree with
[`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
(as `devtools::load_all()` and `devtools::test()` do) counts as well:
its tutorials are read from the source `inst/tutorials/`, so a content
package's own tests see its working tree, not a stale installed copy.
See the section below.

## Ordering

By default a package's tutorials are listed in the order of their
directory names, so authors usually number them (`01-intro`, `02-data`,
...). A tutorial can instead set its position in its YAML header,
without renaming its directory (a directory name is the tutorial's id,
so renaming one breaks links and render caches):

    learnr2:
      ordering: 3

`available_tutorials()` reports it in the `ordering` column. Tools that
list tutorials, such as the "R Tutorials" VS Code extension, sort a
package's tutorials by `ordering` (lowest first), with tutorials that
don't set it after those that do, in directory-name order. A value that
is not a single number is ignored (reported as `NA`);
[`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)
flags it.

## Packages loaded with pkgload

[`system.file()`](https://rdrr.io/r/base/system.file.html) resolves
against the *installed* copy of a package, so a content package under
development used to be invisible here (or, worse, silently read from an
old install) when its own tests ran under `devtools::test()`: 'pkgload'
redirects [`system.file()`](https://rdrr.io/r/base/system.file.html)
only for code inside the package being developed, not for learnr2's
calls. This function and
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
therefore check whether `package` is a namespace loaded by
[`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
and, if so, read its tutorials from the source tree's `inst/tutorials/`
directly. Nothing changes for installed packages, and 'pkgload' itself
is not required.

## Examples

``` r
# Qualified with learnr2:: because the learnr package exports a function of
# the same name; this guarantees learnr2's version is used even if learnr is
# also attached and masks it on the search path.
learnr2::available_tutorials(package = "learnr2")
#>   package          name         title format
#> 1 learnr2 hello-learnr2 Hello learnr2 quarto
#>                                                                                path
#> 1 /home/runner/work/_temp/Library/learnr2/tutorials/hello-learnr2/hello-learnr2.qmd
#>   ordering package_dependencies
#> 1       NA                     
learnr2::available_tutorials(package = "learnr2", type = "quarto")
#>   package          name         title format
#> 1 learnr2 hello-learnr2 Hello learnr2 quarto
#>                                                                                path
#> 1 /home/runner/work/_temp/Library/learnr2/tutorials/hello-learnr2/hello-learnr2.qmd
#>   ordering package_dependencies
#> 1       NA                     
```
