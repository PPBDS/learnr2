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
  edit_button = "Edit Answer",
  id = NULL,
  allow_image = FALSE,
  validate = c("none", "integer")
)
```

## Arguments

- text:

  Question prompt.

- ...:

  One or more
  [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
  objects. Optional for `"reflection"`/`"reflection_editable"` questions
  (see `type`); required, with at least one marked `correct`, for every
  other type.

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
    text(s)) and their own response is locked. If no
    [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md) is
    marked `correct` – including passing none at all, e.g. for a
    genuinely open-ended prompt like "how many minutes did this take?"
    with no right answer to demonstrate – nothing is revealed; the
    reader's response is still saved and locked exactly the same.

  - `"reflection_editable"` – like `"reflection"`, but the reader's
    response stays editable after submitting (whether or not a model
    answer was revealed), so they can keep revising it.

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

- edit_button:

  Button label shown instead of `submit_button` once a
  `"reflection_editable"` question has been submitted at least once –
  from then on, clicking it revises the reader's already-visible answer
  rather than submitting for the first time. Ignored for every other
  `type`, since only `"reflection_editable"` stays open for revision
  after the model answer is revealed.

- id:

  Stable identifier used to key the reader's saved answer (see "Progress
  persistence" below). Defaults to a slug derived from `text`. Set this
  explicitly if you plan to edit the question wording later and want
  readers' saved answers to survive the edit.

- allow_image:

  For `"reflection"`/`"reflection_editable"` questions, let the reader
  paste an image (e.g. a screenshot) from their clipboard, alongside
  their typed response – not a file upload, just Ctrl+V/Cmd+V into the
  question. Defaults to `FALSE`. Ignored for other question types.
  Accepts PNG, JPEG, GIF, WebP, or BMP (whatever the reader's platform
  actually put on the clipboard – this varies, and isn't guaranteed to
  be PNG just because they took a screenshot) and re-encodes it as PNG
  before storing it, so what ends up saved is always PNG regardless of
  the source format. Capped at 2MB.

- validate:

  Client-side format check applied before the reader can submit a
  `"text"`, `"reflection"`, or `"reflection_editable"` answer. `"none"`
  (the default) accepts anything. `"integer"` requires the typed
  response to be a whole number (optionally signed, e.g. `-3`) – useful
  for a question like "how many minutes did this take?" where any honest
  number is fine, but free-form prose is not; see the `"reflection"`
  example below. Ignored (forced to `"none"`) for
  `"single"`/`"multiple"` questions.

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

`localStorage` is written straight to disk, not held only in memory, so
this survives closing and reopening the browser, and restarting the
computer – confirmed with automated tests
(`tests/js/persistence.spec.js`) that fully quit and relaunch a real
browser against the same profile, for both a `file://` tutorial (how
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
opens one) and one served over HTTP. Two things it does *not* survive,
by browser design rather than anything learnr2 controls:
private/incognito windows (their storage is wiped when the window
closes) and the exact page URL changing – a tutorial re-rendered to a
different path, or opened from a different server/port, starts fresh.

Every page also gets a "Start Over" button, appended automatically to
the bottom of Quarto's TOC sidebar (nothing to opt into – it's added by
the same JavaScript that renders
`question()`/[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
as long as the tutorial has a sidebar to put it in, i.e. `toc: true`).
Clicking it, after a confirmation prompt, clears every `question()`/
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
answer *and* every `{webr}` exercise's persisted code (`persist: true`)
for this page on this device, then reloads – a clean slate, without
needing to know that both live under different `localStorage` key
prefixes. It deliberately leaves alone the random per-device id
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
embeds in a submission's metadata, since that identifies this browser
across every tutorial and visit, not this one tutorial's progress.

## Examples

``` r
question(
  "What is 6 times 7?",
  answer("42", correct = TRUE),
  answer("36"),
  answer("48"),
  allow_retry = TRUE
)

# No answer() at all -- a genuinely open-ended prompt with nothing to
# reveal after the reader submits.
question(
  "How many minutes, approximately, did this take?",
  type = "reflection_editable",
  validate = "integer"
)
```
