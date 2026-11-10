# Check a submission's fingerprint and provenance

Every file from
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
ends with a `fingerprint`, a SHA-256 of its identifying content, and a
`loadedFrom` block when the page it came from had been restored from an
earlier download. This recomputes the fingerprint from the file's own
`time`, device id, `loadedFrom`, info fields and answers and says
whether it still matches, then reports where the file came from. A file
whose name or answers were edited by hand after downloading fails the
check. It is not proof of anything: the scheme runs in the browser with
no secret, so a reader who studies `quiz.js` can regenerate a
fingerprint. It catches the ordinary case, a copied file with the name
changed, and makes a resubmission traceable to the file it grew from.

## Usage

``` r
check_submission(path)
```

## Arguments

- path:

  Path to a JSON file downloaded via
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md).

## Value

Invisibly, a list: `time` (POSIXct, UTC, or `NULL`), `name`, `email`,
`device` (the per-device id), `progress` (how far the reader got:
sections revealed and questions answered, as a list, or `NULL`),
`fingerprint` (one of `"valid"`, `"invalid"`, `"missing"`,
`"unchecked"`), `loaded_from` (the file's provenance block as a list, or
`NULL`), `screenshots` and `recordings` (how many answers are pasted
images and voice recordings). Also prints a summary.

## Details

SHA-256 comes from
[`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html),
available from R 4.5.0; on an older R the fingerprint is reported as
`"unchecked"`.

## See also

[`submission_time()`](https://ppbds.github.io/learnr2/reference/submission_time.md),
[`load_tutorial()`](https://ppbds.github.io/learnr2/reference/load_tutorial.md),
[`extract_submission_media()`](https://ppbds.github.io/learnr2/reference/extract_submission_media.md).

## Examples

``` r
answers <- tempfile(fileext = ".json")
writeLines('{"time": "52mz7x0xv", "info": {"name": "Ada"}, "answers": []}', answers)
check_submission(answers)
#> Submitted: 2026-01-15 12:00:00 UTC
#> Name: Ada  Email: (none)
#> Device: (none)
#> Progress: not recorded
#> Media: 0 screenshot(s), 0 recording(s)
#> Fingerprint: missing (downloaded before fingerprints, or stripped)
#> Loaded from: nothing (a fresh run of the tutorial)
```
