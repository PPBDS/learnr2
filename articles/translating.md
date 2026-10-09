# Translating learnr Tutorials

This vignette is the mechanics reference for **learnr2** tutorials. It
covers how a classic [**learnr**](https://rstudio.github.io/learnr/) or
[**tutorial.helpers**](https://ppbds.github.io/tutorial.helpers/)
tutorial turns into a **learnr2** one, and the rules every **learnr2**
tutorial follows whether it was translated or written fresh. It assumes
you have read [Tutorials in the Age of
AI](https://ppbds.github.io/learnr2/articles/ai.md), which covers what a
tutorial is *for* and how it should teach. This one covers how the file
is put together so that it renders and runs.

The single most important difference is that a **learnr2** tutorial
needs nothing installed to view. There is no Shiny app and no R server.
A tutorial renders once to a static HTML page, and its code cells run in
the reader’s browser via WebR. Most of the rules below follow from that.

## Where things go

Classic tutorials live at `inst/tutorials/<name>/tutorial.Rmd` in their
package. Translate one into `inst/tutorials/<name>/<name>.qmd`, either
in **learnr2** itself for a bundled tutorial or in a separate content
package that depends on **learnr2**.
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
also writes `<name>.qmd`. A file named `tutorial.qmd` works too, because
[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
and
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
take the first `.qmd` in the directory, but prefer `<name>.qmd`.

Keep the source’s `images/` and `data/` directories next to the `.qmd`,
exactly as they were. Relative paths resolve against the `.qmd`’s own
directory.

## Quick reference

| learnr or tutorial.helpers source | learnr2 equivalent |
|----|----|
| `output: learnr::tutorial`, `runtime: shiny_prerendered` | `format: live-html` and `engine: knitr` |
| [`library(learnr)`](https://rstudio.github.io/learnr/) or [`library(tutorial.helpers)`](https://ppbds.github.io/tutorial.helpers/) in a setup chunk | delete it, and call functions as `learnr2::fn()` |
| `knitr::opts_chunk$set(echo = FALSE)` in setup | `#| echo: false` on every widget chunk, never a document-wide setting |
| the `info_section.Rmd` child document | a chunk calling [`learnr2::student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md) |
| the `download_answers.Rmd` child document | a minutes [`question()`](https://ppbds.github.io/learnr2/reference/question.md) chunk and a [`learnr2::download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md) chunk |
| an `exercise = TRUE` chunk | a [webr](https://github.com/cardiomoon/webr) cell with `label`, `exercise` and `persist: true` |
| an `ex1-setup` chunk | a [webr](https://github.com/cardiomoon/webr) cell with `setup: true` and the same `exercise`, or the setup inlined |
| `ex1-hint`, `ex1-hint-1`, … chunks | `.hint` fenced divs |
| an `ex1-solution` chunk, ungraded | a `.solution` fenced div |
| an `ex1-solution` chunk, graded | a [webr](https://github.com/cardiomoon/webr) cell with `solution: true` |
| an `ex1-check` chunk with **gradethis** | a [webr](https://github.com/cardiomoon/webr) cell with `check: true`, plus the `_gradethis.qmd` include |
| `question("...", answer("a", correct = TRUE))` | `learnr2::question("...", learnr2::answer("a", correct = TRUE))` |
| `question_text(...)`, with or without a model answer | `learnr2::question(..., type = "reflection")` |
| `question_numeric(...)` (the minutes question) | `learnr2::question(..., type = "reflection_editable", validate = "integer")` |
| a bare `###` directly under a `##` heading | delete it, since the heading already starts the section |
| any other bare `###` divider | keep it, since it becomes a Continue stop with no heading |
| `allow_skip: yes` in the YAML | `learnr2::tutorial_options(allow_skip = TRUE)` |
| `knitr::include_graphics("images/x.png")` | `![](images/x.png)` |
| a four-backtick block around a plain transcript | an ordinary three-backtick block |
| `<pre><code>` with `&#96;` entities, to show a chunk | a four-backtick `{verbatim}` block |
| escaped backticks, `` \`\`\` ``, in a sentence | inline code with a longer delimiter, as in ```` `` ``` `` ```` |
| prose sending the reader to RStudio or a local console to configure it | rewrite around the page, or drop it (see below) |

The sections that follow expand on the rows that aren’t obvious.

## The YAML header

Replace the **learnr** header:

``` yaml
---
title: Some Title
output:
  learnr::tutorial:
    progressive: yes
    allow_skip: yes
runtime: shiny_prerendered
---
```

with:

``` yaml
---
title: "Some Title"
subtitle: "A short description, if the source had one"
format: live-html
engine: knitr
toc: true
---
```

Drop `tutorial: id:`, `output:`, `runtime:`, `progressive:` and
`allow_skip:` entirely. **learnr2** reveals sections progressively on
its own. If the source had `allow_skip: yes` and you want to keep that
behaviour, see *Sections and the Continue button* below. Update `title:`
and `subtitle:` so neither still describes content you have changed,
such as “Tutorials in RStudio” for a tutorial that no longer needs
RStudio.

Immediately after the header, include the quarto-live runtime:

``` default
{{< include _extensions/r-wasm/live/_knitr.qmd >}}
```

Add `{{< include _extensions/r-wasm/live/_gradethis.qmd >}}` as well if
any exercise is graded.

## Setup chunks and boilerplate

Delete the **learnr** setup chunk, with its
[`library()`](https://rdrr.io/r/base/library.html) calls and
`knitr::opts_chunk$set()`. **learnr2** functions are called with the
`learnr2::` prefix instead.

The two **tutorial.helpers** child documents become plain chunks. At the
top, right after any introductory prose:

```` default
```{r}
#| label: student-information-1
#| echo: false
learnr2::student_info()
```
````

At the bottom:

```` default
```{r}
#| label: your-answers-1
#| echo: false
learnr2::question(
  "How many minutes, approximately, did it take you to complete this
  tutorial? For example, an hour and a half would be 90 minutes.",
  type = "reflection_editable",
  validate = "integer"
)
```

```{r}
#| label: your-answers-2
#| echo: false
learnr2::download_answers_button(filename_prefix = "<name>")
```
````

**learnr2** has no numeric question type. `validate = "integer"` blocks
Submit until the response is a whole number, without grading it against
any one value, since any honest count is acceptable. There is no
[`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
because there is no correct number of minutes. This is the one question
that stays `reflection_editable`, because there is no right answer to
copy. After Submit it locks behind an Edit button, and Edit reopens it
until the next Submit, the same cycle as
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md).

## Chunk labels

Every chunk needs a unique `#| label:` on its own line inside the chunk,
never the old inline `{r some-label}` form. That applies to `{r}` chunks
and to every [webr](https://github.com/cardiomoon/webr) cell, including
plain demonstration cells.

For a question, the label is load-bearing. With no explicit `id =`, a
question’s id is its chunk’s label, and that id is the key its saved
answer is stored under and the name it appears under in the downloaded
file. Renaming a question’s chunk resets that question for every
student.

Follow the **tutorial.helpers** convention. Take the enclosing `##`
heading, lowercase it, collapse spaces and punctuation to single dashes,
drop any leading number such as the `6.` in `## 6. Quiz questions`, and
append a dash and a sequence number that restarts at 1 in each section.
`## Quiz questions` gives `quiz-questions-1`, `quiz-questions-2`, and so
on. Count every labelled chunk in the section in document order, `{r}`
and [webr](https://github.com/cardiomoon/webr) alike. One variant: the
“our answer” chunk that follows an exercise’s question takes the
question’s label plus `-answer`, as in `introduction-3` and
`introduction-3-answer`, so exercise numbers and label numbers stay in
step.

## Hide the source of widget chunks

The **learnr** setup chunk you deleted almost always set `echo = FALSE`
for the whole document. Without it, every `{r}` chunk shows its own
source above its output, so the reader sees the R call that builds each
question instead of just the question.

Add `#| echo: false` to each chunk that renders a widget:
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
[`question()`](https://ppbds.github.io/learnr2/reference/question.md),
[`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
and
[`tutorial_options()`](https://ppbds.github.io/learnr2/reference/tutorial_options.md).
Don’t use a document-wide `execute: echo: false` in the YAML instead.
[webr](https://github.com/cardiomoon/webr) cells are a pass-through
engine that re-emits its own source as output by design, and a global
override isn’t verified safe for them.

## Exercise cells

A **learnr** exercise chunk:

```` default
```{r exercise-1, exercise = TRUE}
```
````

becomes a [webr](https://github.com/cardiomoon/webr) cell with three
options:

```` default
```{webr}
#| label: functions-and-packages-2
#| exercise: ex_load_tidyverse
#| persist: true
______
glimpse(mtcars)
```
````

- `label` follows the convention above.
- `exercise` is any stable id. The bundled tutorial uses snake case,
  like `ex_total`, to keep it visibly distinct from the dashed label.
- `persist: true` saves the reader’s typed code in their browser so it
  survives a reload and appears in the downloaded answers. Without it,
  their code is saved nowhere.

Keep whatever starter code the source had, whether empty, a leading
comment, or **tutorial.helpers**’ `____` blanks. Drop chunk options that
mean nothing in the browser: `exercise.lines`, `exercise.timelimit`,
`exercise.cap`, `exercise.df_print`, `exercise.blanks`, `message` and
`warning`.

### Exercise setup

A **learnr** `ex1-setup` chunk has two translations. Either use a
[webr](https://github.com/cardiomoon/webr) cell with `setup: true` and
the same `exercise` id, which runs invisibly before the reader’s code:

```` default
```{webr}
#| label: analysis-3
#| setup: true
#| exercise: ex_summarise
library(dplyr)
flights <- nycflights13::flights
```
````

or put the setup lines at the top of the exercise cell itself, which is
simplest for a line or two and keeps the cell self-contained.

Whichever you choose, remember that
[webr](https://github.com/cardiomoon/webr) cells do not share state.
Each exercise runs in its own environment, separate from every other
exercise and from any earlier demonstration cell, and a reload wipes all
of it. Anything an exercise needs must come from its own setup cell or
its own body.

### Hints and solutions

A hint chunk becomes a fenced div tied to the exercise id:

``` default
::: { .hint exercise="ex_load_tidyverse" }
Some hint text, or an inline code sample.
:::
```

Numbered hints (`ex1-hint-1`, `ex1-hint-2`, …) become several
consecutive `.hint` divs with the same `exercise`, which quarto-live
reveals one at a time. A model answer becomes a `.solution` div, and its
inner ```` ```r ```` block is required:

```` default
::: { .solution exercise="ex_load_tidyverse" }
```r
library(tidyverse)
glimpse(mtcars)
```
:::
````

**A graded exercise is the exception.** If the exercise also has a
`check: true` cell, its solution must be a
[webr](https://github.com/cardiomoon/webr) cell with `solution: true`,
not a `.solution` div:

```` default
```{webr}
#| label: analysis-4
#| exercise: ex_load_tidyverse
#| solution: true
library(tidyverse)
glimpse(mtcars)
```
````

Only the cell form produces the hidden copy of the code that the grader
compares against. With the div, submission fails with “No solution code
was found.” The cell still shows the reader a “Show solution” button.

### Grading

Translate a `check` chunk that uses **gradethis**, such as
`gradethis::grade_this_code()`, into a
[webr](https://github.com/cardiomoon/webr) cell with `check: true` and
the exercise’s id. Add the `_gradethis.qmd` include after `_knitr.qmd`,
and give the exercise a `solution: true` cell as just described. If the
source check is trivial or absent, leave it out. An exercise doesn’t
need grading to be useful.

## Questions

**learnr** questions become
[`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md)
calls in a `{r}` chunk, with
[`learnr2::answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
for each answer and
[`learnr2::quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md)
to group them. The chunk runs once, when the tutorial is rendered, not
once per reader. These arguments carry over unchanged: `allow_retry`,
`random_answer_order` for choice questions, `correct` and `incorrect`.

- **A choice question**, built from `answer(..., correct = TRUE)`
  options, keeps the default `type = "auto"`. It becomes single or
  multiple choice by how many answers are correct. Use `type = "text"`
  for a typed exact-match answer.
- **`question_text()`**, the **tutorial.helpers** workhorse for both
  “explain in your own words” and CP/CR evidence questions, becomes
  `type = "reflection"`. Its correct answer’s text, if it has one, is
  revealed as a model answer after the reader submits. It is never
  graded against their wording. Drop the options with no equivalent:
  `try_again_button`, `rows`, `options`, `trim` and `placeholder`.
- **`question_numeric()`** becomes `type = "reflection_editable"` with
  `validate = "integer"` and no
  [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md), as
  in the minutes question.
- **Custom `answer_fn` checkers**, regular expressions and partial
  credit have no equivalent. Reduce them to plain
  [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
  matches, or to a `"reflection"` question if the point was open-ended.

Use `"reflection"`, not `"reflection_editable"`, for the old
`allow_retry = TRUE, try_again_button = "Edit Answer"` idiom.
**learnr2** locks every submitted answer by default, and [Tutorials in
the Age of AI](https://ppbds.github.io/learnr2/articles/ai.md) explains
why: we show our answer right after the reader’s, and an editable box
next to it invites copying.

A [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
always carries its prompt in `text`. That string is shown in the
question box, saved with the answer, and printed beside it in the
downloaded file. Where **tutorial.helpers** put the prompt in prose
above a `question_text(NULL, ...)` chunk, move the question into `text`
and keep any longer set-up prose above the chunk.

Choice and `"text"` questions, and
[`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md), suit
mechanics tutorials and feature tours. A normal data-science tutorial
teaches concepts through exercises and knowledge drops rather than
quizzes, so expect most translated questions to be `"reflection"`.

### Screenshot questions

`learnr2::question(type = "reflection", allow_image = TRUE)` lets the
reader paste a screenshot as their answer. Use it in four cases, and
convert the source’s question whenever one applies:

1.  **The student would copy text out of a web page.**
    **tutorial.helpers** tutorials often say “copy everything from X
    through Y on this page” and take a pasted mess of text, as the
    website tutorials in **vscode.tutorials** do for the student’s own
    rendered pages. Ask instead for a screenshot of the relevant part of
    the page. The screenshot shows what the student actually saw, layout
    included, and is easier to check.
2.  **The student produces an image,** usually a plot. Classic tutorials
    verify a plot exercise with
    [`show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md),
    which proves the student has *code*, not that it drew the right
    picture. Ask for a screenshot of the plot instead, as in the
    plotting template in [Tutorials in the Age of
    AI](https://ppbds.github.io/learnr2/articles/ai.md). This is very
    common in **misc.tutorials**. Keep
    [`show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md)
    for exercises whose result is text, such as a printed tibble or
    summary statistics.
3.  **Nothing else can verify the step,** such as being signed in to an
    account or having a particular window open.
4.  **The student carries out several small steps in a row.** Turning
    each one into its own question is sometimes more than the steps
    deserve. If every step is necessary, give the steps as plain
    instructions and end with a single screenshot of something that only
    looks right if all of them were done correctly. For example, after
    “create the repo, add a `.gitignore`, commit and push”, ask for a
    screenshot of the repo’s page on GitHub showing the `.gitignore`
    file. Pick the screen so a skipped or botched step shows: if the
    screenshot would look the same without one of the steps, that step
    needs its own check. When translating, use this for a run of steps
    the source left unchecked. Don’t merge questions the source already
    asks separately, since that pacing was the author’s choice.

When you convert a question, rewrite the prose around it to match. An
instruction that says “copy” or “CP/CR” should now say what to
screenshot. Any sentence explaining that pasted text may look messy
goes, since it no longer applies. Keep the source’s own answer, if it
had one, as the answer shown after Continue: a screenshot of the
expected page, or our answer chunk drawing the expected plot.

The first screenshot question a student meets should say how to take a
screenshot and how to paste it: `Cmd + Shift + 4` on a Mac,
`Win + Shift + S` on Windows, then click in the answer box and press
`Ctrl + V` (`Cmd + V` on a Mac). Later ones can just ask for the
screenshot.

Ask for one specific screenshot, never a hedged choice. “Paste a
screenshot of your GitHub dashboard” works. “Paste a screenshot showing
you’re signed in, for example your profile page or the account menu”
leaves the reader guessing which one counts. If it isn’t obvious why
that screen proves the step, say so.

If the prompt reads better as ordinary text on the page, write it there
and pass `show_text = FALSE`. Still repeat the wording in `text`, which
is kept in the saved data and read to screen-reader users.

## Images

Replace
[`knitr::include_graphics()`](https://rdrr.io/pkg/knitr/man/include_graphics.html)
chunks with plain Markdown, `![](images/thing.png)`, optionally with
`{width=90%}`. There is no chunk to label or hide.

## Sections and the Continue button

**learnr2** reveals a tutorial one section at a time. Every `##` and
`###` heading becomes a stop behind a Continue button, and you add
nothing to opt in. A Continue button always sits at the end of something
to read, never directly under a heading: clicking it reveals the next
heading together with the text that follows it, which may or may not
include the next exercise. Some details for translations:

- **Delete a bare `###` that directly follows a `##` heading.**
  **tutorial.helpers** opens every topic with `## Heading` and then
  `###` on the next line, sometimes with a blank line between them.
  **learnr2** shows the heading and the first block together either way,
  so that `###` adds nothing. Delete it and leave one blank line under
  the heading.
- **Keep every other bare `###` divider.** A line holding only `###`
  becomes a Continue stop with no visible heading and a button that just
  says “Continue”. **tutorial.helpers** puts two inside every exercise,
  one before the author’s answer and one before the knowledge drop, and
  both pauses survive the translation.
- **Delete a titled heading that exists only as a pacing break,** with
  no content of its own, and fold its prose into the enclosing section.
- **`### Hints` and `### Solutions` subsections** that only wrap a
  `.hint` or `.solution` div are not separate stops. They appear with
  the exercise they belong to.
- **The table of contents can’t be used to read ahead.** Entries for
  sections the reader hasn’t reached are dimmed and do nothing when
  clicked. `learnr2::tutorial_options(allow_skip = TRUE)` restores
  **learnr**’s `allow_skip: yes`, where clicking an entry unlocks
  everything up to it.
- **Continue waits for answers.** A section’s Continue button is
  disabled until every question and
  [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
  form above it has been submitted.
  `learnr2::tutorial_options(require_submission = FALSE)` turns that
  off, which suits reference material.
- **`toc: false` is supported.** Without a sidebar, the Start Over
  button moves to the top of the tutorial, under the title.
- **Links that leave the page open in a new tab,** so following one
  never makes the tutorial disappear. Write ordinary Markdown links.
  Nothing is needed to opt in.

Call
[`tutorial_options()`](https://ppbds.github.io/learnr2/reference/tutorial_options.md)
at most once, in its own chunk with `#| echo: false`.

## Packages, and code that runs at render time

The `webr:` block in the YAML header is the only place WebR learns what
to install in the reader’s browser. List every package that any
[webr](https://github.com/cardiomoon/webr) cell uses, whether exercise,
setup, check or demonstration. An exercise that calls
[`library(dplyr)`](https://dplyr.tidyverse.org) or
`nycflights13::flights` needs both packages listed:

``` yaml
webr:
  packages:
    - dplyr
    - nycflights13
```

A `{r}` chunk is different. It runs once, when the tutorial is rendered
on your machine or in CI, never in the reader’s browser. That gives it
two legitimate jobs: rendering a **learnr2** widget, and showing *our
answer*, an `#| echo: true` chunk that runs real code so the reader can
compare it with their own. Every package such a chunk uses must be
installed wherever the tutorial is rendered, which for a content package
means listing it under Suggests. Such chunks must not reach for the
network. Never use a `{r}` chunk to set up objects for a
[webr](https://github.com/cardiomoon/webr) cell, since the browser never
sees what a `{r}` chunk did.

## The page needs nothing installed

A **learnr2** tutorial page needs no local R, no RStudio, and no R
package beyond those listed for WebR. A translation can get every
mechanical rule right and still break this, by leaving prose that sends
the reader to “the R Console” to run something like
`tutorial.helpers::set_rstudio_settings()` or
[`rstudioapi::readRStudioPreference()`](https://rstudio.github.io/rstudioapi/reference/readRStudioPreference.html).
A reader who opened the tutorial from a link, with nothing installed,
hits a wall there.

When translating, look for and rewrite or remove anything that assumes:

- A separate, locally running R session the reader switches to, as
  opposed to a [webr](https://github.com/cardiomoon/webr) cell on the
  page.
- Any R package beyond base R and the `webr:` list being available on
  the page.
- RStudio itself, or its menus and settings.
- A manual procedure for restarting the tutorial from scratch. Every
  **learnr2** page has a Start Over button that clears everything, so
  point to it instead.

If the source tutorial’s whole point was configuring a local R
installation, it has no **learnr2** translation. Drop it rather than
reproduce commands the reader can’t run.

This is a rule about the *page*, not about the student. A normal AI-era
tutorial has the student work in their own repository and Quarto
document, run
[`show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md)
in their own R Terminal, and paste the result into a `"reflection"`
question. That is the evidence model in [Tutorials in the Age of
AI](https://ppbds.github.io/learnr2/articles/ai.md), and the page itself
still needs nothing installed. Note that
[`learnr2::show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md)
is for that kind of local session. It isn’t available inside a
[webr](https://github.com/cardiomoon/webr) cell, so changing
`tutorial.helpers::show_file()` to
[`learnr2::show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md)
doesn’t fix prose that tells a reader to run it on the page.

## Don’t mention the old packages

A translated tutorial never mentions **learnr** or **tutorial.helpers**.
As far as students know, **learnr2** is the only tutorial package there
is. Rewrite each mention around **learnr2**, or drop it:

- `tutorial.helpers::show_file()` becomes
  [`learnr2::show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md),
  and
  [`library(tutorial.helpers)`](https://ppbds.github.io/tutorial.helpers/)
  becomes [`library(learnr2)`](https://github.com/PPBDS/learnr2). Update
  any transcript that shows the result, such as
  [`search()`](https://rdrr.io/r/base/search.html) output listing
  `"package:tutorial.helpers"`.
- A passage pointing students at a **tutorial.helpers** web page,
  tutorial or function becomes the **learnr2** equivalent, or goes.
- Remarks about where a tutorial came from, such as “moved here from
  **tutorial.helpers**”, are history, not teaching. Delete them, in the
  tutorial and in the package’s README.

The exception is text quoted verbatim from a file that really does name
them, such as a Dockerfile a tutorial walks through. Keep a quotation
true to its source.

## Showing syntax without running it

Classic tutorials work hard to show code, because R Markdown and
**learnr** made it hard. Expect to find four-backtick fences around
every terminal transcript, `<pre><code>` blocks spelling each backtick
as `&#96;` so that a displayed chunk isn’t run, and backticks escaped
one by one in prose. Quarto makes all of that unnecessary. Strip it out
as you translate:

- **Plain blocks get three backticks.** A transcript, file listing or
  command with no backtick fence inside it needs nothing more than an
  ordinary three-backtick block. Keep four backticks only where the
  block’s contents include a three-backtick line, since a fence must be
  longer than any fence it contains.
- **A displayed chunk goes in a `{verbatim}` block.** To show an R
  chunk, or a whole Quarto file with its chunks, as this vignette does,
  wrap it in a four-backtick block marked `{verbatim}`. Everything
  inside appears exactly as typed and nothing runs. It replaces every
  `<pre><code>` block, and the `&#96;` entities inside it become plain
  backticks again. Don’t use a plain four-backtick block for this:
  **knitr** still runs a ```` ```{r} ```` line that starts a line inside
  one.
- **Backticks in a sentence go in inline code.** To mention
  ```` ``` ```` in prose, use a longer run of backticks than any inside
  it as the delimiter, with a space inside each end:
  ```` `` ```{r} `` ```` renders as ```` ```{r} ````. No escaping is
  needed.

Check the rendered page afterwards. Each simplified block should look
just as it did before.

The one case that still needs a workaround is inline R code. Writing
`` `r x` `` in a sentence runs it, and wrapping it in an extra pair of
backticks doesn’t help, because Quarto still evaluates it. Spell the
backticks as HTML entities inside a `<code>` tag instead:

    <code>&#96;r x&#96;</code>

That renders as the literal syntax, because there is no backtick in the
source for Quarto to match.

## Check it by rendering it

Syntax that looks right can still be wrong in ways only the rendered
page shows, such as R source printed above a question. After
translating, run the static checks and a real render:

``` r

learnr2::check_tutorial("inst/tutorials/<name>")    # labels, echo, persist, boilerplate, packages
learnr2::render_tutorials("inst/tutorials/<name>")  # a real Quarto render
```

[`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)
catches a missing label, `echo: false` or `persist: true`, a graded
exercise with a `.solution` div, a
[webr](https://github.com/cardiomoon/webr) package missing from the
`webr:` list, and missing boilerplate. Then open the rendered HTML in a
browser and click through it.

[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
reads the *installed* copy of a package, not your working files. While
editing a content package, load it with `devtools::load_all()` first,
and
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
and
[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
will read its tutorials from the source tree. Don’t commit render
artifacts such as `_extensions/`, `*.html`, `*_files/` and `.quarto/`
alongside the `.qmd`, because
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
adds the extension and renders on demand.

A content package should test every tutorial from
`tests/testthat/test-tutorials.R`:

``` r

tutorials <- learnr2::available_tutorials(package = "<your package>", type = "quarto")
learnr2::check_tutorial(tutorials$path)
learnr2::render_tutorials(tutorials$path)
```

Guard that test with
[`testthat::skip_on_cran()`](https://testthat.r-lib.org/reference/skip.html)
and `testthat::skip_if(is.null(quarto::quarto_path()))`, since it needs
the Quarto command line tool.

## One learnr2 tutorial in a classic learnr package

A single **learnr2** `.qmd` can live in a package whose other tutorials
are classic **learnr** `.Rmd` files. **learnr2** lists and runs only the
`.qmd` ones, so
`learnr2::run_tutorial("<name>", package = "<host package>")` finds it,
renders it and serves it, and ignores the classic tutorials around it.
**learnr2** does not depend on **learnr**: classic tutorials are run
with **learnr** itself, as before. `R CMD check` on the host package
treats the `.qmd` as data and ignores it.

Classic tooling, in turn, only ever looks for `.Rmd`:

- [`learnr::available_tutorials()`](https://pkgs.rstudio.com/learnr/reference/available_tutorials.html)
  doesn’t list a directory holding only a `.qmd`, so
  [`learnr::run_tutorial()`](https://pkgs.rstudio.com/learnr/reference/run_tutorial.html)
  can’t launch it.
- `tutorial.helpers::return_tutorial_paths()` keeps only `.Rmd` files,
  so a host package whose tests render tutorials through it neither
  renders nor fails on the `.qmd`. It simply goes untested.

So, when you do this, also add **learnr2** to the host’s Suggests (and
to `Remotes` if it isn’t on CRAN), add `inst/tutorials/*/_extensions/`
and `.quarto` to `.Rbuildignore` and `.gitignore`, and give the `.qmd`
its own test, as shown in the previous section.
