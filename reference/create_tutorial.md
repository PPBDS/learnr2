# Create a new learnr2 tutorial

Scaffolds a new interactive tutorial: a directory containing a starter
`.qmd` document wired up for `format: live-html`, with the bundled
'quarto-live' extension copied alongside it so it renders out of the
box. The starter document opens with
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
and ends with a "how many minutes did this take" question plus
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md),
so every new tutorial collects name/email (and an optional ID) and lets
the reader turn in their answers by default; delete either section if a
given tutorial doesn't need it.

## Usage

``` r
create_tutorial(name, dir = ".", title = name, open = interactive())
```

## Arguments

- name:

  Name of the tutorial. Used for the directory and the `.qmd` file name,
  so it should be a valid file name (e.g. `"my-tutorial"`).

- dir:

  Parent directory in which to create the tutorial directory. Defaults
  to the current working directory.

- title:

  Human-readable title placed in the document's YAML header. Defaults to
  `name`.

- open:

  Whether to open the new `.qmd` file in an interactive session.
  Defaults to `TRUE` when interactive.

## Value

The path to the created `.qmd` file, invisibly.

## Examples

``` r
# Scaffold into a temporary directory, without opening the new file.
dir <- tempfile()
qmd <- create_tutorial("my-first-tutorial", dir = dir, open = FALSE)
#> Created tutorial: /tmp/RtmpEnoxfy/file197459ab9028/my-first-tutorial/my-first-tutorial.qmd
list.files(dirname(qmd), all.files = TRUE, no.. = TRUE)
#> [1] "_extensions"           "my-first-tutorial.qmd"
unlink(dir, recursive = TRUE)
```
