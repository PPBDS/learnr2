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

## Details

The download's `answers` array is one flat list: every
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
plus every `{webr}` code exercise, each as a `{ id, answer }` pair keyed
by the widget's (or exercise's) stable id. A question never submitted
has `answer: null`; a choice question's `answer` is an array of the
picked options; an image-paste reflection's `answer` is the pasted
screenshot as a PNG data-URL string.

A `{webr}` exercise appears only under the condition quarto-live itself
requires to keep a record of the reader's code at all:
`#| persist: true` (already the convention every bundled tutorial
follows). An exercise without `persist: true` has no saved copy of the
reader's code anywhere – `learnr2` included – so it can't appear in the
download; this is a structural limit of quarto-live's own editor, not
something `download_answers_button()` chooses to skip.

The download also carries a `metadata` block (timezone, browser info,
and a random per-device id persisted across the reader's visits) and a
`time` field: the moment the reader clicked "Download", lightly
obfuscated so the raw timestamp isn't readable or hand-editable in the
file. Recover it with
[`submission_time()`](https://ppbds.github.io/learnr2/reference/submission_time.md).
Nothing else is hashed or signed – a determined reader can still edit
their answers; this only keeps the submission time honest at a glance.

## Examples

``` r
download_answers_button()
```
