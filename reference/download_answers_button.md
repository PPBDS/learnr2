# Add a "download my answers" button

Adds a button that, when clicked, gathers every
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
and
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
answer currently on the page – each already saved to the browser's
`localStorage` as the reader worked through the tutorial – into a single
readable JSON file and downloads it. This happens entirely in the
reader's browser; there is no server to submit to, so this is meant for
a reader to save and turn in themselves (e.g. attach to an email or
upload to an LMS).

## Usage

``` r
download_answers_button(
  filename_prefix = "learnr2-answers",
  label = "Download My Answers"
)
```

## Arguments

- filename_prefix:

  Prefix for the downloaded file's name. Defaults to
  `"learnr2-answers"`.

- label:

  Button label. Defaults to `"Download My Answers"`.

## Value

A `learnr2_download_button` object, printed as an interactive HTML
button.

## Examples

``` r
download_answers_button()
```
