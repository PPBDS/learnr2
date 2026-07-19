# Collect student identifying information

Adds a small, ungraded form for the reader to fill in identifying
information before starting a tutorial: name and email required, an ID
optional, by default. Unlike
[`question()`](https://ppbds.github.io/learnr2/reference/question.md),
nothing here is graded and there is no model answer to reveal – it is
pure data collection, auto-saved to the browser's `localStorage` as the
reader types and restored on their next visit. Pair with
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
so a reader can turn their work in.

## Usage

``` r
student_info(
  fields = c(name = "Name:", email = "Email:", id =
    "ID (if requested by your instructor):"),
  required = c("name", "email"),
  id = "student-info"
)
```

## Arguments

- fields:

  A named character vector of field key/label pairs to collect. Defaults
  to name, email, and an optional ID, matching 'tutorial.helpers”s
  `info_section.Rmd`.

- required:

  Character vector of keys (from `fields`) the reader must fill in.
  Defaults to `c("name", "email")`, so ID is optional by default. A
  required field left blank is flagged inline and blocks
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
  until it's filled in.

- id:

  Stable identifier used to key the saved values in `localStorage`.
  Defaults to `"student-info"`; change it if a single tutorial embeds
  more than one `student_info()` form.

## Value

A `learnr2_info` object, printed as an interactive HTML form.

## Examples

``` r
student_info()
student_info(fields = c(name = "Full name:", section = "Section:"), required = "name")
```
