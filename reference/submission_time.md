# Recover a submission's download time

[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
writes the moment the reader clicked "Download" into the JSON as a
`time` field, lightly obfuscated: base-36 of the epoch second run
through a fixed multiply-and-offset. It is *not* encrypted — the scheme
is public, in `inst/extdata/quiz/quiz.js` — just enough that the raw
timestamp isn't sitting in the file where a student could read it, or
swap in a different plausible time without re-running the encoder. This
function reverses it.

## Usage

``` r
submission_time(x)
```

## Arguments

- x:

  Path to a JSON file downloaded via
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md),
  or the raw `time` string from one.

## Value

The download time as a `POSIXct` (UTC), invisibly. Also prints a short
summary — with the reader's name, email, and device id when `x` is a
file.

## Details

Nothing else in the file is hashed or signed, so this does **not**
detect edited answers. If you need that, compare against work submitted
through a channel you control.

## Examples

``` r
# Decode a bare time code:
submission_time("52mz7x0xv")
#> Submitted: 2026-01-15 12:00:00 UTC

# Or read it, along with the reader's details, from a downloaded file:
answers <- tempfile(fileext = ".json")
writeLines(
  '{"time": "52mz7x0xv", "info": {"name": "Ada", "email": "ada@example.com"}}',
  answers
)
submission_time(answers)
#> Submitted: 2026-01-15 12:00:00 UTC
#>   Name: Ada
#>   Email: ada@example.com
#>   Device id: (unknown)
unlink(answers)
```
