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

The download's `exercises` array also includes every `{webr}` code
exercise's current code, under the same condition quarto-live itself
requires to keep a record of it at all: `#| persist: true` (already the
convention every bundled tutorial follows). An exercise without
`persist: true` has no saved copy of the reader's code anywhere –
`learnr2` included – so it can't appear in the download; this is a
structural limit of quarto-live's own editor, not something
`download_answers_button()` chooses to skip.

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

## Details

The download includes a `metadata` block (timestamp, timezone, browser
info, and a random per-device id persisted across the reader's visits)
and a SHA-256 `integrity` hash over the content. Check a downloaded file
with
[`verify_submission()`](https://ppbds.github.io/learnr2/reference/verify_submission.md).
This is tamper-*evidence*, not proof of identity: since everything runs
in the reader's own browser with no server-held secret, a technical
reader could reproduce the hash themselves. What it reliably catches is
editing the file afterward (e.g. changing a wrong answer to a right one
before turning it in).

## Examples

``` r
download_answers_button()
```
