# Reopen a tutorial with a student's downloaded answers filled in

Takes the JSON file a reader downloaded with the "Download My Answers"
button, works out which tutorial it came from, renders (or reuses the
cached render of) that tutorial exactly as
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
would, and opens it with every answer in the file already submitted, as
if the reader had just typed them in. The reader can then carry on,
correct what needs correcting, and download a new file. The usual case
is a resubmission: a student whose file has one wrong URL fixes that
answer instead of redoing the tutorial.

## Usage

``` r
load_tutorial(
  path,
  output_dir = tools::R_user_dir("learnr2", "cache"),
  open = interactive(),
  refresh = FALSE
)
```

## Arguments

- path:

  Path to a JSON file downloaded with
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md).
  It must name its `package` and `tutorial` (files downloaded before
  learnr2 recorded them cannot be loaded); a missing `version`, or one
  that differs from the installed package, is reported as a warning,
  since the tutorial's questions may have changed.

- output_dir, open, refresh:

  As for
  [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md).
  With `open = FALSE` the tutorial is rendered and the restore page
  written, but nothing is served or opened; the restore page's path is
  returned.

## Value

The path of the restore page, invisibly.

## What is restored

Every entry in the file's `answers` whose id matches a
[`question()`](https://ppbds.github.io/learnr2/reference/question.md) or
a `{webr}` exercise on the rendered page, plus the
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
form. A choice question gets its picked options back, a text question
its text, a reflection its text or pasted screenshot, an exercise its
code. Sections are unlocked through the last one holding a restored
answer, so the page opens where the reader left off. An entry whose id
matches nothing (the tutorial has changed since the download, say) is
dropped with a warning naming it. Answers never submitted (`null` in the
file) are left blank.

Answers live in the browser's `localStorage`, keyed by the tutorial's
address (see "Progress persistence" in
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)),
so this writes a small page, `learnr2-restore.html`, next to the
rendered tutorial in the cache; opening it stores the answers under the
tutorial's own address and forwards to the tutorial. Loading a file
replaces whatever that browser had saved for the same tutorial. When
this function's own server is stopped the page is deleted; if an
already-running learnr2 server was used instead, it stays until the next
load or re-render.

## The same thing without R

Every tutorial page also has a **Load Answers** button beside **Start
Over**, and accepts a dropped `.json` file anywhere on the page. It does
in the browser what this function does from R, matching ids the same
way, so a reader of a published copy of a tutorial (on GitHub Pages,
say) can pick up a download without an R session. This function is for
the student in a Codespace, where the tutorial must be rendered and
served first, and for the "R Tutorials" VS Code extension's **Load
Answers File...** command, which calls it.

## See also

[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md),
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md),
[`submission_time()`](https://ppbds.github.io/learnr2/reference/submission_time.md).

## Examples

``` r
if (FALSE) { # \dontrun{
load_tutorial("~/Downloads/orientation-2026-11-08T14-02-11-305Z.json")
} # }
```
