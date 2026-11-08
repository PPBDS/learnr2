# Set tutorial-wide options

Configures behaviour that applies to the whole tutorial page rather than
to one widget. Call it once, in its own `{r}` chunk with
`#| echo: false`, anywhere in the `.qmd`; it renders nothing visible.
Every option has a default, so a tutorial that never calls this function
behaves as described under "Defaults" below.

## Usage

``` r
tutorial_options(
  allow_skip = FALSE,
  require_submission = TRUE,
  language = NULL
)
```

## Arguments

- allow_skip:

  Logical. May the reader use a table-of-contents link to unlock and
  jump to a section they have not reached yet? Default `FALSE`.

- require_submission:

  Logical. Must every question and student-info form in a section be
  submitted before its "Continue" button works? Default `TRUE`.

- language:

  `NULL`, or a named list or character vector of interface strings to
  override, e.g. `list(continue = "Next")`. See "Interface language"
  below.

## Value

A `learnr2_options` object, printed as an invisible HTML element that
the page's JavaScript reads at load.

## Skipping ahead via the table of contents

learnr2 reveals a tutorial one `##`/`###` section at a time, behind
"Continue" buttons (see the "Progress persistence" section of
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)).
Quarto's table-of-contents sidebar lists every section from the start,
and each entry is a plain link to that section's heading. By default
(`allow_skip = FALSE`) an entry for a section the reader has not reached
yet is dimmed and inert: clicking it does nothing, and it becomes a
working link the moment that section is unlocked. Entries for sections
already reached navigate normally. So a reader sees the shape of the
tutorial and how far along they are, but cannot use the sidebar to see
the whole tutorial at once.

With `allow_skip = TRUE`, clicking any entry instead unlocks every
section up to and including that one and jumps there – the behaviour of
a classic 'learnr' tutorial with `allow_skip: yes`. Use it for
reference-style material a reader is meant to move around in freely,
such as learnr2's own `hello-learnr2` feature tour.

Neither setting matters for a tutorial rendered with `toc: false`, which
has no sidebar and so only ever moves forward one Continue at a time.

## Submitting before continuing

By default (`require_submission = TRUE`) the "Continue" button at the
end of a section stays disabled, with a short note under it, until every
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
and
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
form above it in that section has been submitted. A reader can type
anything, but they must submit *something* before the tutorial moves on.
Combined with `type = "reflection"` questions, which lock once
submitted, this is what lets a tutorial show its own answer right after
the reader's without inviting them to copy it back into the box: by the
time they see our answer, theirs is already in and cannot be changed.
Set `require_submission = FALSE` for reference material a reader should
be free to skim, such as learnr2's own `hello-learnr2` feature tour.
`{webr}` code cells are not part of this check; they have no notion of
being "submitted".

## Interface language

Every string learnr2 puts on the page follows the document's language,
Quarto's `lang:` YAML key: `lang: fr` gives French "Continuer",
"Recommencer", "Soumettre la réponse" and so on, alongside Quarto's own
French table of contents. English is the default and the fallback for a
language learnr2 does not ship. `language` rewords single strings on top
of that, for a course that wants "Next" rather than "Continue", say. Its
names are the keys of the string table,
`system.file("extdata/quiz/lang/en.json", package = "learnr2")`; a
string may contain the placeholders the English one does, such as
`{title}` in `continue_to` or `{n}` in `continue_note_other`. An unknown
key is an error. The labels of
[`question()`](https://ppbds.github.io/learnr2/reference/question.md),
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
and
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
can also be set per call.

## Defaults

- `allow_skip = FALSE`

- `require_submission = TRUE`

- `language = NULL`

## Examples

``` r
tutorial_options()
#> <div class="learnr2-options" data-learnr2-options="eyJhbGxvd1NraXAiOmZhbHNlLCJyZXF1aXJlU3VibWlzc2lvbiI6dHJ1ZX0=" hidden></div>
tutorial_options(allow_skip = TRUE)
#> <div class="learnr2-options" data-learnr2-options="eyJhbGxvd1NraXAiOnRydWUsInJlcXVpcmVTdWJtaXNzaW9uIjp0cnVlfQ==" hidden></div>
tutorial_options(require_submission = FALSE)
#> <div class="learnr2-options" data-learnr2-options="eyJhbGxvd1NraXAiOmZhbHNlLCJyZXF1aXJlU3VibWlzc2lvbiI6ZmFsc2V9" hidden></div>
tutorial_options(language = list(continue = "Next", start_over = "Reset"))
#> <div class="learnr2-options" data-learnr2-options="eyJhbGxvd1NraXAiOmZhbHNlLCJyZXF1aXJlU3VibWlzc2lvbiI6dHJ1ZSwibGFuZ3VhZ2Ui&#10;OnsiY29udGludWUiOiJOZXh0Iiwic3RhcnRfb3ZlciI6IlJlc2V0In19" hidden></div>
```
