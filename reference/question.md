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
  correct = NULL,
  incorrect = NULL,
  allow_retry = FALSE,
  random_answer_order = FALSE,
  submit_button = NULL,
  try_again_button = NULL,
  edit_button = NULL,
  id = NULL,
  allow_image = FALSE,
  allow_audio = FALSE,
  max_seconds = 120,
  allow_text = TRUE,
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
    marked `correct` – including passing none at all, as for a "paste
    the command and its output" question with no model answer to show –
    nothing is revealed; the reader's response is still saved and locked
    exactly the same.

  - `"reflection_editable"` – like `"reflection"`, but a submitted
    response can be reopened. Submit locks it behind an "Edit" button;
    Edit reopens it, with a note that the change isn't saved until the
    next Submit. The saved answer is always the last submitted one.
    Meant for answers with nothing to copy: a question whose answer is a
    URL of the reader's own (see
    [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)'s
    `urls` check), or a minutes-spent count: an ordinary `"reflection"`
    stays locked for good, so a reader can't reopen it and paste in the
    model answer they were just shown.

- correct:

  Message shown when the reader answers correctly. `NULL`, the default,
  means the page language's "Correct!" (see "Language" below). Unused
  for `"reflection"`/`"reflection_editable"` questions.

- incorrect:

  Message shown when the reader answers incorrectly. `NULL`, the
  default, means the page language's "Incorrect.". Unused for
  `"reflection"`/`"reflection_editable"` questions.

- allow_retry:

  Allow the reader to try again after an incorrect answer? Defaults to
  `FALSE`. Unused for `"reflection"`/`"reflection_editable"` questions.

- random_answer_order:

  Shuffle answer order each time the page loads? Defaults to `FALSE`.
  Only applies to `"single"`/`"multiple"` questions.

- submit_button, try_again_button:

  Button labels. `NULL`, the default, means the page language's "Submit
  Answer" and "Try Again".

- edit_button:

  Button label shown while a submitted `"reflection_editable"` question,
  or a `"reflection"` question with `allow_image = TRUE` or
  `allow_audio = TRUE`, is locked; clicking it reopens the answer for
  editing (only the image or the recording, for the latter two). `NULL`,
  the default, means the page language's "Edit Answer". Ignored
  otherwise.

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
  paste an image (e.g. a screenshot) from their clipboard as their
  answer – not a file upload, just Ctrl+V/Cmd+V into the question.
  Defaults to `FALSE`. Ignored for other question types. Accepts PNG,
  JPEG, GIF, WebP, or BMP, up to 20MB, since the clipboard format varies
  by platform. Before it is stored, the image is scaled to at most 1600
  pixels wide and re-encoded as WebP (JPEG in browsers that can't write
  WebP, such as Safari), dropping quality or size further if needed to
  stay under about 450KB. That keeps screenshots from filling the
  browser's storage, which is about 5MB for a whole site. If a save
  fails anyway, the page says so and the answer stays unsubmitted. A
  submitted `"reflection"` question with `allow_image = TRUE` gets an
  `edit_button` ("Edit Answer"), which reopens only the image box so the
  reader can swap in a different screenshot; the question counts as
  unsubmitted until the new image is submitted. The text box stays
  locked.

- allow_audio:

  For `"reflection"`/`"reflection_editable"` questions, let the reader
  record their voice, in the browser, as their answer. Defaults to
  `FALSE`. **Recording works in Chrome and Edge**; tell students who
  will meet a voice question to open the tutorial in one of them.
  (Recording uses the browser's `MediaRecorder` with the Opus codec in
  WebM, which those two support everywhere learnr2 is used. Firefox
  usually works too. Safari does not.) In a browser that cannot record,
  the question shows a note saying which browsers can, and a notice at
  the top of the page says so before the reader starts; the Load Answers
  button lets them carry a download into the right browser. The widget
  has Record, Stop and Record again buttons, a timer, and a player for
  what was recorded; the microphone is asked for on the first Record and
  released at Stop. The recording is stored like a pasted screenshot, as
  a data URL in the browser's storage and in the download file (about
  3KB per second: two minutes is roughly 360KB of the browser's 5MB for
  the whole site). A submitted voice question gets an `edit_button`
  ("Edit Answer") that reopens only the recorder, as a screenshot
  question's reopens only the image box. Cannot be combined with
  `allow_image`. Ignored for other question types.

- max_seconds:

  With `allow_audio = TRUE`, the longest recording allowed, in seconds;
  recording stops by itself at this point. Defaults to `120`, at most
  `300`.
  [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)'s
  `audio` check warns when a tutorial's voice questions add up to more
  than ten minutes.

- allow_text:

  With `allow_image = TRUE` or `allow_audio = TRUE`, also offer a text
  box for a typed answer? Defaults to `TRUE`. Set it to `FALSE` for a
  screenshot-only or voice-only question: no text box is shown, and
  Submit is refused until an image is pasted or a recording made.
  Ignored when neither `allow_image` nor `allow_audio` is `TRUE`.

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
  number is fine, but free-form prose is not; see the
  `"reflection_editable"` example below. A pasted image (`allow_image`)
  or a recording (`allow_audio`) is not validated. Ignored (forced to
  `"none"`) for `"single"`/`"multiple"` questions.

## Value

A `learnr2_question` object. Printed as an interactive HTML widget in a
rendered Quarto document; at the console it opens a browser preview in
an interactive session and prints the HTML source otherwise.

## Language

Every label and message learnr2 itself puts on the page – these buttons,
"Continue", "Start Over", the feedback and notes – follows the
document's language, Quarto's `lang:` YAML key (`lang: fr`), which also
translates Quarto's own table of contents and code-copy tooltip. A label
passed explicitly to this function is used as given, in any language.
learnr2 ships English and French; a `lang:` with no translation falls
back to English, and
[`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)
says so. To reword single strings, or to see the list of them, see
[`tutorial_options()`](https://ppbds.github.io/learnr2/reference/tutorial_options.md);
to add a language, see the "Language" section of
[`vignette("translating")`](https://ppbds.github.io/learnr2/articles/translating.md).

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

Every page also gets a "Start Over" button (nothing to opt into – it's
added by the same JavaScript that renders
`question()`/[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)).
It sits at the bottom of Quarto's TOC sidebar when the page shows one,
and otherwise – a tutorial rendered with `toc: false`, or any tutorial
on a screen too narrow for Quarto to show the sidebar – at the top of
the tutorial, directly under the title, before the first section.
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
#> <div class="learnr2-question" data-learnr2-question="eyJpZCI6IndoYXQtaXMtNi10aW1lcy03IiwidGV4dCI6IldoYXQgaXMgNiB0aW1lcyA3PyIs&#10;InR5cGUiOiJzaW5nbGUiLCJhbnN3ZXJzIjpbeyJ0ZXh0IjoiNDIiLCJjb3JyZWN0Ijp0cnVl&#10;LCJtZXNzYWdlIjpudWxsfSx7InRleHQiOiIzNiIsImNvcnJlY3QiOmZhbHNlLCJtZXNzYWdl&#10;IjpudWxsfSx7InRleHQiOiI0OCIsImNvcnJlY3QiOmZhbHNlLCJtZXNzYWdlIjpudWxsfV0s&#10;ImNvcnJlY3RNZXNzYWdlIjpudWxsLCJpbmNvcnJlY3RNZXNzYWdlIjpudWxsLCJhbGxvd1Jl&#10;dHJ5Ijp0cnVlLCJyYW5kb21BbnN3ZXJPcmRlciI6ZmFsc2UsInN1Ym1pdExhYmVsIjpudWxs&#10;LCJ0cnlBZ2FpbkxhYmVsIjpudWxsLCJlZGl0TGFiZWwiOm51bGwsImFsbG93SW1hZ2UiOmZh&#10;bHNlLCJhbGxvd0F1ZGlvIjpmYWxzZSwibWF4U2Vjb25kcyI6bnVsbCwiYWxsb3dUZXh0Ijp0&#10;cnVlLCJzaG93VGV4dCI6dHJ1ZSwidmFsaWRhdGUiOiJub25lIn0=">
#>   <noscript>This quiz question requires JavaScript.</noscript>
#> </div>

# No answer() at all -- a genuinely open-ended prompt with nothing to
# reveal after the reader submits.
question(
  "How many minutes, approximately, did this take?",
  type = "reflection_editable",
  validate = "integer"
)
#> <div class="learnr2-question" data-learnr2-question="eyJpZCI6Imhvdy1tYW55LW1pbnV0ZXMtYXBwcm94aW1hdGVseS1kaWQtdGhpcy10YWtlIiwi&#10;dGV4dCI6IkhvdyBtYW55IG1pbnV0ZXMsIGFwcHJveGltYXRlbHksIGRpZCB0aGlzIHRha2U/&#10;IiwidHlwZSI6InJlZmxlY3Rpb25fZWRpdGFibGUiLCJhbnN3ZXJzIjpbXSwiY29ycmVjdE1l&#10;c3NhZ2UiOm51bGwsImluY29ycmVjdE1lc3NhZ2UiOm51bGwsImFsbG93UmV0cnkiOmZhbHNl&#10;LCJyYW5kb21BbnN3ZXJPcmRlciI6ZmFsc2UsInN1Ym1pdExhYmVsIjpudWxsLCJ0cnlBZ2Fp&#10;bkxhYmVsIjpudWxsLCJlZGl0TGFiZWwiOm51bGwsImFsbG93SW1hZ2UiOmZhbHNlLCJhbGxv&#10;d0F1ZGlvIjpmYWxzZSwibWF4U2Vjb25kcyI6bnVsbCwiYWxsb3dUZXh0Ijp0cnVlLCJzaG93&#10;VGV4dCI6dHJ1ZSwidmFsaWRhdGUiOiJpbnRlZ2VyIn0=">
#>   <noscript>This quiz question requires JavaScript.</noscript>
#> </div>

# A voice-only question: Chrome or Edge, up to one minute.
question(
  "In a sentence or two, say what a p-value is.",
  type = "reflection",
  allow_audio = TRUE,
  allow_text = FALSE,
  max_seconds = 60
)
#> <div class="learnr2-question" data-learnr2-question="eyJpZCI6ImluLWEtc2VudGVuY2Utb3ItdHdvLXNheS13aGF0LWEtcC12YWx1ZS1pcyIsInRl&#10;eHQiOiJJbiBhIHNlbnRlbmNlIG9yIHR3bywgc2F5IHdoYXQgYSBwLXZhbHVlIGlzLiIsInR5&#10;cGUiOiJyZWZsZWN0aW9uIiwiYW5zd2VycyI6W10sImNvcnJlY3RNZXNzYWdlIjpudWxsLCJp&#10;bmNvcnJlY3RNZXNzYWdlIjpudWxsLCJhbGxvd1JldHJ5IjpmYWxzZSwicmFuZG9tQW5zd2Vy&#10;T3JkZXIiOmZhbHNlLCJzdWJtaXRMYWJlbCI6bnVsbCwidHJ5QWdhaW5MYWJlbCI6bnVsbCwi&#10;ZWRpdExhYmVsIjpudWxsLCJhbGxvd0ltYWdlIjpmYWxzZSwiYWxsb3dBdWRpbyI6dHJ1ZSwi&#10;bWF4U2Vjb25kcyI6NjAsImFsbG93VGV4dCI6ZmFsc2UsInNob3dUZXh0Ijp0cnVlLCJ2YWxp&#10;ZGF0ZSI6Im5vbmUifQ==">
#>   <noscript>This quiz question requires JavaScript.</noscript>
#> </div>
```
