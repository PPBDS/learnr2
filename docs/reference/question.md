# Create a quiz question

A learnr-style quiz question, rendered as a small self-contained,
client-side interactive widget — no Shiny or R server required. Supports
single-choice ("radio"), multiple-choice ("checkbox"), and free-text
questions, graded entirely in the reader's browser.

## Usage

``` r
question(
  text,
  ...,
  type = c("auto", "single", "multiple", "text", "reflection", "reflection_editable"),
  correct = "Correct!",
  incorrect = "Incorrect.",
  allow_retry = FALSE,
  random_answer_order = FALSE,
  submit_button = "Submit Answer",
  try_again_button = "Try Again",
  id = NULL,
  allow_image = FALSE
)
```

## Arguments

- text:

  Question prompt.

- ...:

  One or more
  [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
  objects.

- type:

  Question type. `"auto"` (the default) picks `"single"` when exactly
  one answer is marked `correct`, and `"multiple"` otherwise. Other
  types:

  - `"text"` – a free-text question, graded by comparing (trimmed,
    whitespace-collapsed, case-insensitive) the reader's response
    against the
    [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
    text(s).

  - `"reflection"` – an ungraded free-response question. After
    submitting, the reader sees the model answer (the `correct`
    [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
    text(s)) and their own response is locked.

  - `"reflection_editable"` – like `"reflection"`, but the reader's
    response stays editable after the model answer is revealed, so they
    can keep revising it.

- correct:

  Message shown when the reader answers correctly. Unused for
  `"reflection"`/`"reflection_editable"` questions.

- incorrect:

  Message shown when the reader answers incorrectly. Unused for
  `"reflection"`/`"reflection_editable"` questions.

- allow_retry:

  Allow the reader to try again after an incorrect answer? Defaults to
  `FALSE`. Unused for `"reflection"`/`"reflection_editable"` questions.

- random_answer_order:

  Shuffle answer order each time the page loads? Defaults to `FALSE`.
  Only applies to `"single"`/`"multiple"` questions.

- submit_button, try_again_button:

  Button labels.

- id:

  Stable identifier used to key the reader's saved answer (see "Progress
  persistence" below). Defaults to a slug derived from `text`. Set this
  explicitly if you plan to edit the question wording later and want
  readers' saved answers to survive the edit.

- allow_image:

  For `"reflection"`/`"reflection_editable"` questions, let the reader
  paste a PNG image (e.g. a screenshot) from their clipboard, alongside
  their typed response – not a file upload, just Ctrl+V/Cmd+V into the
  question. Defaults to `FALSE`. Ignored for other question types.

## Value

A `learnr2_question` object. Printed as an interactive HTML widget, both
in a rendered Quarto document and (via a browser preview) at the R
console.

## Progress persistence

Once a reader submits an answer, it is saved in the browser's
`localStorage` (keyed by page URL and `id`) and restored on the next
visit. Because the default `id` is derived from `text`, editing a
question's wording changes its `id` and resets any saved answers for it;
pass `id` explicitly to avoid that.

## Examples

``` r
question(
  "What is 6 times 7?",
  answer("42", correct = TRUE),
  answer("36"),
  answer("48"),
  allow_retry = TRUE
)
```
