# Set tutorial-wide options

Configures behaviour that applies to the whole tutorial page rather than
to one widget. Call it once, in its own `{r}` chunk with
`#| echo: false`, anywhere in the `.qmd`; it renders nothing visible.
Every option has a default, so a tutorial that never calls this function
behaves as described under "Defaults" below.

## Usage

``` r
tutorial_options(allow_skip = FALSE)
```

## Arguments

- allow_skip:

  Logical. May the reader use a table-of-contents link to unlock and
  jump to a section they have not reached yet? Default `FALSE`.

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

## Defaults

- `allow_skip = FALSE`

## Examples

``` r
tutorial_options()
#> <div class="learnr2-options" data-learnr2-options="eyJhbGxvd1NraXAiOmZhbHNlfQ==" hidden></div>
tutorial_options(allow_skip = TRUE)
#> <div class="learnr2-options" data-learnr2-options="eyJhbGxvd1NraXAiOnRydWV9" hidden></div>
```
