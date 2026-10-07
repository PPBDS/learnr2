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
  show_text = TRUE,
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

  Stable identifier for this question: it keys the reader's saved answer
  (see "Progress persistence" below) and is the `id` the question
  appears under in a
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
  submission. Defaults to the label of the `{r}` chunk the `question()`
  call sits in — which, following `tutorial.helpers`' `section-header-N`
  chunk-naming convention, is already a unique, readable identifier
  (`## Quiz questions` -\> `quiz-questions-1`, `quiz-questions-2`, ...).
  Falls back to a slug of `text` when there is no usable chunk label,
  e.g. when printing a `question()` at the console. Pass `id` explicitly
  to pin it regardless of where the call sits.

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

- show_text:

  Show `text` as the question's prompt inside the widget? Defaults to
  `TRUE`. Set it to `FALSE` when the prompt is written as ordinary text
  on the page, just above the question, and should not be repeated
  inside the box. `text` is still required: it is kept (and read by
  screen readers, via visually hidden text) and is what the reader is
  reminded of if they try to download their answers without submitting
  this question.

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

A `learnr2_question` object. Printed as an interactive HTML widget in a
rendered Quarto document; at the console it opens a browser preview in
an interactive session and prints the HTML source otherwise.

## Progress persistence

Once a reader submits an answer, it is saved in the browser's
`localStorage` (keyed by page URL and `id`) and restored on the next
visit. Because the default `id` is the enclosing `{r}` chunk's label,
renaming that chunk (or moving the question into a different one) resets
any saved answers for it — but editing only the question's wording does
not. Pass `id` explicitly to pin it.

`localStorage` is written straight to disk, not held only in memory, so
this survives closing and reopening the browser, and restarting the
computer – confirmed with automated tests
(`tests/js/persistence.spec.js`) that fully quit and relaunch a real
browser against the same profile, for both a `file://` tutorial and one
served over HTTP. Two things it does *not* survive, by browser design
rather than anything learnr2 controls: private/incognito windows (their
storage is wiped when the window closes) and the exact page URL changing
– a tutorial opened from a different server, port or path starts fresh.
That is why
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
always serves on one fixed port and gives every tutorial its own stable
path, `/<package>/<name>/`: the address, and so the saved answers, are
the same on every launch, and no two tutorials share them.

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
#> <div class="learnr2-question" data-learnr2-question="eyJpZCI6IndoYXQtaXMtNi10aW1lcy03IiwidGV4dCI6IldoYXQgaXMgNiB0aW1lcyA3PyIs&#10;InR5cGUiOiJzaW5nbGUiLCJhbnN3ZXJzIjpbeyJ0ZXh0IjoiNDIiLCJjb3JyZWN0Ijp0cnVl&#10;LCJtZXNzYWdlIjpudWxsfSx7InRleHQiOiIzNiIsImNvcnJlY3QiOmZhbHNlLCJtZXNzYWdl&#10;IjpudWxsfSx7InRleHQiOiI0OCIsImNvcnJlY3QiOmZhbHNlLCJtZXNzYWdlIjpudWxsfV0s&#10;ImNvcnJlY3RNZXNzYWdlIjoiQ29ycmVjdCEiLCJpbmNvcnJlY3RNZXNzYWdlIjoiSW5jb3Jy&#10;ZWN0LiIsImFsbG93UmV0cnkiOnRydWUsInJhbmRvbUFuc3dlck9yZGVyIjpmYWxzZSwic3Vi&#10;bWl0TGFiZWwiOiJTdWJtaXQgQW5zd2VyIiwidHJ5QWdhaW5MYWJlbCI6IlRyeSBBZ2FpbiIs&#10;ImVkaXRMYWJlbCI6IkVkaXQgQW5zd2VyIiwiYWxsb3dJbWFnZSI6ZmFsc2UsInNob3dUZXh0&#10;Ijp0cnVlLCJ2YWxpZGF0ZSI6Im5vbmUifQ==">
#>   <noscript>This quiz question requires JavaScript.</noscript>
#> </div>

# No answer() at all -- a genuinely open-ended prompt with nothing to
# reveal after the reader submits.
question(
  "How many minutes, approximately, did this take?",
  type = "reflection_editable",
  validate = "integer"
)
#> <div class="learnr2-question" data-learnr2-question="eyJpZCI6Imhvdy1tYW55LW1pbnV0ZXMtYXBwcm94aW1hdGVseS1kaWQtdGhpcy10YWtlIiwi&#10;dGV4dCI6IkhvdyBtYW55IG1pbnV0ZXMsIGFwcHJveGltYXRlbHksIGRpZCB0aGlzIHRha2U/&#10;IiwidHlwZSI6InJlZmxlY3Rpb25fZWRpdGFibGUiLCJhbnN3ZXJzIjpbXSwiY29ycmVjdE1l&#10;c3NhZ2UiOiJDb3JyZWN0ISIsImluY29ycmVjdE1lc3NhZ2UiOiJJbmNvcnJlY3QuIiwiYWxs&#10;b3dSZXRyeSI6ZmFsc2UsInJhbmRvbUFuc3dlck9yZGVyIjpmYWxzZSwic3VibWl0TGFiZWwi&#10;OiJTdWJtaXQgQW5zd2VyIiwidHJ5QWdhaW5MYWJlbCI6IlRyeSBBZ2FpbiIsImVkaXRMYWJl&#10;bCI6IkVkaXQgQW5zd2VyIiwiYWxsb3dJbWFnZSI6ZmFsc2UsInNob3dUZXh0Ijp0cnVlLCJ2&#10;YWxpZGF0ZSI6ImludGVnZXIifQ==">
#>   <noscript>This quiz question requires JavaScript.</noscript>
#> </div>
```
