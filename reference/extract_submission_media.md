# Write a submission's screenshots and recordings to files

A pasted screenshot
([`question()`](https://ppbds.github.io/learnr2/reference/question.md)'s
`allow_image`) or a voice recording (`allow_audio`) sits in the
downloaded file as a base64 data URL, which nothing opens directly. This
writes each one to `dir` as `<question id>.<ext>` (`.webp` or `.jpg` for
a screenshot, `.webm` for a recording), so a grader can look or listen.
[`load_tutorial()`](https://ppbds.github.io/learnr2/reference/load_tutorial.md)
is the alternative: it shows them in place, in the tutorial.

## Usage

``` r
extract_submission_media(path, dir = NULL, quiet = FALSE)
```

## Arguments

- path:

  Path to a JSON file downloaded via
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md).

- dir:

  Directory to write into, created if needed. Defaults to a directory
  named after the file, beside it.

- quiet:

  If `FALSE`, the default, say what was written.

## Value

Invisibly, a character vector of the files written, named by question
id. Empty when the file holds no media.

## See also

[`check_submission()`](https://ppbds.github.io/learnr2/reference/check_submission.md).

## Examples

``` r
answers <- tempfile(fileext = ".json")
writeLines(paste0(
  '{"answers": [{"id": "plot-1", "answer": "data:image/webp;base64,',
  jsonlite::base64_enc(charToRaw("not really an image")), '"}]}'
), answers)
files <- extract_submission_media(answers, dir = tempfile())
#> Wrote 1 file(s) to '/tmp/RtmpBFWhb6/file191aae280be': plot-1.webp
basename(files)
#> [1] "plot-1.webp"
```
