# Display all or part of a text file

Prints a text file – or the part of it an author most often wants to see
– to the console. By default (`chunk = "auto"`), a file containing
fenced code chunks (a `.qmd` or `.Rmd`) shows just its *last* code
chunk, which is by far the most common use ("show me the code you just
wrote"), while a file with no code chunks (a `.gitignore`, `.yml`, `.R`,
...) is shown whole. Everything else is opt-in: a row range, a
regular-expression filter, all chunks, one chunk picked out by its
label, or the YAML header.

## Usage

``` r
show_file(path, start = 1, end = NULL, pattern = NULL, chunk = "auto")
```

## Arguments

- path:

  Path to the text file.

- start:

  Integer: the first row (inclusive) to show. Default is 1. If negative,
  show the last `abs(start)` lines of the file instead. If 0, show the
  entire file. Supplying `start` switches `chunk = "auto"` off.

- end:

  Integer: the last row (inclusive) to show. Default is the last row of
  the file. Supplying `end` switches `chunk = "auto"` off.

- pattern:

  A regular expression; only rows matching it are shown. Default is
  `NULL` (no filtering). Applied to the whole-file (`start == 0`),
  last-lines (`start < 0`), and row-range cases; ignored when `chunk`
  selects code chunks or the YAML header. Supplying `pattern` switches
  `chunk = "auto"` off.

- chunk:

  What to show. One of:

  - `"auto"` (the default): the last code chunk if the file has any and
    no row arguments were given; otherwise the whole file.

  - `"None"`: no chunk processing; show rows (the whole file by
    default).

  - `"All"`: the code of every chunk, separated by blank lines.

  - `"Last"`: the code of the last chunk only.

  - `"YAML"`: the YAML header, without its `---` delimiters.

  - Any other string: the code of the chunk with that label. It is an
    error if no chunk has that label.

## Value

Called for its side effect of printing to the console; returns `NULL`,
invisibly. Prints nothing if no rows match `pattern`, or if the selected
chunk is empty. A file that is empty, or contains only blank lines,
prints `File is empty.`

## Details

The arguments are resolved in a fixed order. `chunk = "YAML"` is handled
first; then `start == 0` (whole file); then `start < 0` (the last
`abs(start)` lines); then `chunk` when it selects code chunks (`"All"`,
`"Last"`, or a label); and finally the `start`/`end` row range. The
`pattern` filter applies within the whole-file, last-lines, and
row-range cases, and is ignored when `chunk` selects code chunks or the
YAML header.

`chunk = "auto"` resolves to `"Last"` only when the file contains at
least one fenced code chunk *and* none of `start`, `end`, or `pattern`
were supplied. Passing any of those three is taken as a request to see
rows, not chunks, so e.g. `show_file("analysis.qmd", end = 4)` always
means the first four lines, and
`show_file("analysis.qmd", pattern = "library")` always searches the
whole file.

A chunk's label is read from any of the usual places: the positional
label in the fence header (```` ```{r setup} ````), a `label =` option
in the header (```` ```{r, label = "setup"} ````), or a
`#| label: setup` line inside the chunk. Chunks of any language are
recognized (`r`, `python`, `bash`, ...), not just R.

Rendered output that VS Code's interactive chunk execution caches back
into a `.qmd` file (a pagedtable HTML widget) is stripped before
anything is printed, so a chunk shows only its source.

## Examples

``` r
# A small Quarto document to look at:
qmd <- tempfile(fileext = ".qmd")
writeLines(c(
  "---",
  "title: \"An example\"",
  "---",
  "Some prose, with an example in it.",
  "```{r setup}",
  "library(dplyr)",
  "x <- 1:10",
  "```",
  "More prose.",
  "```{r}",
  "#| label: summary",
  "mean(x)",
  "```"
), qmd)

# The default shows the last code chunk, the most common thing to want
show_file(qmd)
#> #| label: summary
#> mean(x)

# Every chunk, or one picked out by its label
show_file(qmd, chunk = "All")
#> library(dplyr)
#> x <- 1:10
#> 
#> #| label: summary
#> mean(x)
show_file(qmd, chunk = "setup")
#> library(dplyr)
#> x <- 1:10
show_file(qmd, chunk = "summary")
#> #| label: summary
#> mean(x)

# The YAML header, without its delimiters
show_file(qmd, chunk = "YAML")
#> title: "An example"

# Rows instead of chunks: the whole file, a range, a filter, the tail
show_file(qmd, chunk = "None")
#> ---
#> title: "An example"
#> ---
#> Some prose, with an example in it.
#> ```{r setup}
#> library(dplyr)
#> x <- 1:10
#> ```
#> More prose.
#> ```{r}
#> #| label: summary
#> mean(x)
#> ```
show_file(qmd, start = 4, end = 8)
#> Some prose, with an example in it.
#> ```{r setup}
#> library(dplyr)
#> x <- 1:10
#> ```
show_file(qmd, pattern = "example")
#> title: "An example"
#> Some prose, with an example in it.
show_file(qmd, start = -3)
#> #| label: summary
#> mean(x)
#> ```

# A file with no code chunks is shown whole by default
gitignore <- tempfile(fileext = ".gitignore")
writeLines(c(".Rproj.user", ".Rhistory", "*.html"), gitignore)
show_file(gitignore)
#> .Rproj.user
#> .Rhistory
#> *.html

unlink(c(qmd, gitignore))
```
