# learnr2

learnr2 is a from-scratch reimplementation of the ideas behind
**learnr** (and the **tutorial.helpers** package built on top of it),
but targeting **Quarto + `quarto-live` + WebR** instead of **R
Markdown + Shiny**. There is no Shiny app and no R server: tutorials
render to a static `.html` file, and exercise code cells run client-side
in the reader’s browser via WebR (R compiled to WebAssembly).

## Templates vs. instructions (a settled design question)

Worth settling once, since it shapes how this whole file is used: for
authoring a new learnr2 tutorial, is a starter template
(`inst/templates/tutorial.qmd`, scaffolded by
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md))
enough on its own, or does an author – human or AI – need written
instructions like this file?

**Verdict: written instructions win.** A template shows *what* a correct
file looks like, once; it can’t explain *why*, so it can’t stop anyone
from reproducing exactly the mistakes documented below the moment they
stray from it even slightly – adding one plain `{r}` chunk, translating
a real learnr tutorial instead of starting fresh, or misremembering
which `echo` option goes where. Concretely, none of the following is
learnable from the template alone:

- The `echo: false` chunk-scoped requirement (below) – the template
  already has it on every chunk that needs it, so nothing *in* the
  template teaches you that it’s required, or why a document-wide
  override breaks [webr](https://github.com/cardiomoon/webr) chunks
  specifically.
- The “no local R/RStudio dependency” translation trap (below) – it has
  no counterpart in the template at all, since it only surfaces when
  translating existing learnr content, which a from-scratch template
  can’t anticipate.
- “Verify by actually rendering” isn’t a fact a template can express;
  it’s a workflow rule, and the regression below was only caught by
  following it.

Practically: **this file is the primary authoring guide; the template is
a labor-saving shortcut for boilerplate, never a substitute for reading
this first.** This was tested directly: `inst/tutorials/intro-vectors/`
was hand-authored from these instructions alone (not via
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md),
not by copying the template), then rendered and checked in a browser to
confirm the result was correct without the template’s help. If you’re
authoring a tutorial and haven’t read the rest of this file yet, that’s
the bug to fix before writing any `.qmd` content.

### Is `create_tutorial()` still worth keeping?

Realistically, few humans will type `create_tutorial("my-tutorial")` at
an R console – most tutorial authoring from here on is either a person
editing an existing `.qmd` directly, or an AI agent writing one from a
prompt. But an agent is exactly the kind of caller
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
suits well: it’s one unambiguous action (scaffold the `.qmd` *and* copy
the `quarto-live` extension alongside it) instead of hand-typing
frontmatter and remembering a separate
[`add_live_extension()`](https://ppbds.github.io/learnr2/reference/add_live_extension.md)
call. Conclusion: keep it. An agent following this file can either call
it for a guaranteed-correct starting point, or write the `.qmd` by hand
the way `intro-vectors/` was written – both are proven to work here. A
human author is equally free to do either.

### `student_info()` is a different kind of question

The template-vs-instructions question above is about *authoring-time
tooling* – how a tutorial’s `.qmd` file comes into existence.
[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
(like
[`question()`](https://ppbds.github.io/learnr2/reference/question.md),
[`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md))
isn’t authoring tooling at all – it’s part of a tutorial’s actual
*content*: a function call that belongs inside the `.qmd`, written by
whoever is authoring that tutorial regardless of whether they got there
via
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md),
by hand, or by translating an existing tutorial. There is no “template
vs. instructions” choice to make about it; it’s simply covered by the
boilerplate section below, every time.

## Reference files to read before translating anything

- `inst/templates/tutorial.qmd` – the skeleton
  [`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
  scaffolds.
- `inst/tutorials/hello-learnr2/hello-learnr2.qmd` – a complete worked
  example exercising every learnr2 feature.
- `inst/tutorials/intro-vectors/intro-vectors.qmd` – a small tutorial
  hand-authored from this file alone, as the test described above.
- `R/question.R`, `R/submission.R` – source of truth for
  [`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md),
  [`learnr2::quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
  [`learnr2::student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
  [`learnr2::download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md).

## Authoring a new tutorial (not translating one)

`tutorial.helpers` gets its standard boilerplate – name/email/ID at the
top, a “minutes spent” question plus a download button at the bottom –
from two child documents (`info_section.Rmd`, `download_answers.Rmd`)
included via `child = system.file(...)`. learnr2 has no child-document
mechanism; the equivalent is just writing the same two
plain-function-call blocks directly into the `.qmd`, by hand, every
time:

`{r} #| label: student-information-1 #| echo: false learnr2::student_info()`

at the top (right after the frontmatter/intro prose), and at the bottom:

`{r} #| label: your-answers-1 #| echo: false learnr2::question( "How many minutes, approximately, did it take you to complete this tutorial? For example, an hour and a half would be 90 minutes.", type = "reflection_editable", validate = "integer" )`

`{r} #| label: your-answers-2 #| echo: false learnr2::download_answers_button(filename_prefix = "<tutorial-name>")`

(`type = "reflection_editable"` stands in for learnr’s
`question_numeric()` here –
[`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md)
has no dedicated numeric type. `validate = "integer"` is the closest
match: it blocks Submit client-side unless the typed response is a whole
number, without grading it against one specific value, since any honest
minute count is acceptable. This is a deliberate, settled choice, not a
gap to keep re-litigating per tutorial. No
[`answer()`](https://ppbds.github.io/learnr2/reference/answer.md) is
passed at all – there genuinely is no correct number of minutes, and
[`question()`](https://ppbds.github.io/learnr2/reference/question.md) no
longer requires one for `"reflection"`/`"reflection_editable"` types;
see \[question()\]’s docs. An earlier version of this snippet worked
around the old requirement with a throwaway
`answer(..., correct = TRUE)` whose “model answer” text just restated
that there was no correct answer – that workaround is gone now that it’s
unnecessary.)

`inst/templates/tutorial.qmd` – the file
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
scaffolds – already includes both blocks (with `{{name}}` filled in
automatically for the download button’s `filename_prefix`), so a
brand-new tutorial gets this for free. Reach for the snippets above when
hand-authoring instead (as in `intro-vectors/`), or when adding this
boilerplate to a `.qmd` translated from a learnr/tutorial.helpers source
per the next section.

Don’t forget `#| echo: false` on all three chunks (see that section,
below, for why it matters).

## Every chunk needs a unique `#| label:`

A `{r}` chunk calling
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
*is* read by learnr2: with no explicit `id =`, the question defaults its
`id` to the enclosing chunk’s label (see `question_id()` /
`current_chunk_label()` in `R/question.R`). That `id` is the
`localStorage` key for the reader’s saved answer *and* the `id` the
question appears under in a
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
submission – so the label is load-bearing there, the same way
`#| exercise:` is on a [webr](https://github.com/cardiomoon/webr) cell.
Renaming such a chunk resets saved progress for its question; the
section-header convention below keeps the labels stable and meaningful.
The other widget chunks
([`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md))
and plain [webr](https://github.com/cardiomoon/webr) demo cells still
have no label-driven runtime behavior. Give every chunk one anyway –
`{r}` chunks calling
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)/[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)/[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md),
*and* every [webr](https://github.com/cardiomoon/webr) chunk, including
exercise ones (alongside their load-bearing `#| exercise:`, which stays
exactly as it was) and plain non-exercise demo cells that carry no other
identifying option at all. On its own `#| label:` line (not the old
inline ```` ```{r some-label} ```` header style – see the
per-chunk-options rule two sections below), for the same reason
`tutorial.helpers` tutorials always have one: an anonymous chunk is
invisible to anything that wants to talk about “that one cell” –
tooling, a reviewer leaving comments, an error message citing a chunk –
and a labelled one isn’t. (A first pass at this rule scoped it to only
the three `{r}` functions above, reasoning
[webr](https://github.com/cardiomoon/webr) exercise chunks already had
`#| exercise:` covering the same need – true for *that* purpose, but it
left every plain demo cell with no identifier of any kind, and doesn’t
help a reviewer who’s just scanning a `.qmd` for “does every chunk have
a name,” which is what this rule is actually for.)

Follow `tutorial.helpers`’s own convention, the same one used throughout
its real tutorials (e.g. `bash-terminal-1`, `r-terminal-5`): the
enclosing `##` section’s heading text, lowercased, with spaces and any
other non-alphanumeric characters collapsed to single dashes (drop a
leading number-and-period like the `6.` in `## 6. Quiz questions` – the
number is already implicit in the chunk’s own suffix), followed by a
dash and a sequential number – restarting at `1` for each section, in
document order, counting *every* chunk in the section that gets a label
(mixing `{r}` and [webr](https://github.com/cardiomoon/webr) chunks in
one sequence if a section has both, rather than numbering each chunk
type separately). `## Quiz questions` -\> `quiz-questions-1`,
`quiz-questions-2`, …. Every bundled tutorial (`hello-learnr2`,
`getting-started`, `intro-vectors`) and the
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
template follow this now – match their style for a new one rather than
inventing another convention.

## Showing inline-code syntax literally, without triggering it

Sometimes prose needs to *show* what inline code looks like – the
literal text `` `r x` `` – right next to its actual evaluated result,
e.g. “writing `` `r x` `` produces: the value is 123”. The naive way to
write the literal half, wrapping it in one extra pair of backticks (
`r x` , a double-backtick code span), **does not work**: verified by
rendering, Quarto still evaluates it, so both halves of that sentence
show the *computed value* and there’s no way left to show the syntax
itself. This surprised a real translation attempt (`vscode.tutorials2`’s
`02-quarto`) enough that its source `.Rmd` has its own comment calling
this out: “If you try to include the inline code in the middle of a
sentence, all hell breaks loose… so we hack.”

The fix, matching that source file’s own workaround: spell the backticks
as the HTML entity `&#96;` inside a `<code>` tag instead of typing
literal backtick characters –

    <code>&#96;r x&#96;</code>

– which Quarto has no reason to treat as executable, since there’s no
backtick character in the source for its inline-code regex to match. Use
this whenever a tutorial’s own subject is Quarto/knitr syntax itself
(like explaining what inline code or chunk options are) and needs to
show, not run, an example.

## Translating a learnr/tutorial.helpers `.Rmd` tutorial to learnr2 `.qmd`

Tutorials from `tutorial.helpers`-based packages live at
`tutorials/<name>/tutorial.Rmd` inside the installed package (find them
with `system.file("tutorials", package = "tutorial.helpers")`, or
similar for other `*.tutorials` packages). Translate one into
`<pkg>/inst/tutorials/<name>/<name>.qmd` – `<pkg>` is learnr2 itself for
a bundled tutorial, or a separate `*.tutorials2`-style content package
that depends on `learnr2`. Keep any `images/` (or other asset)
subdirectory next to the `.qmd`, exactly as the source had it. The file
may be named `<name>.qmd` (matches `hello-learnr2`, `intro-vectors`) or
`tutorial.qmd` (matches `getting-started`) –
[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
/
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
just take the first `*.qmd` in the directory, so either works; prefer
`<name>.qmd` for a new translation.

### Dropping one `.qmd` into an otherwise-`.Rmd` (classic learnr) package

The `<pkg>` above assumes learnr2 itself or a `*.tutorials2` package
built on it. A third case works but has blind spots worth knowing:
adding a single learnr2 `.qmd` tutorial into a package that is otherwise
all classic-learnr `.Rmd` – done for real in `PPBDS/primer.tutorials`
(the `getting-started-tutorial` dir, 2026-09), imported from this repo’s
own `getting-started`.

**What still works.** `learnr2`’s own finders scan *every* subdirectory
of `inst/tutorials/` and pick `.qmd` before `.Rmd`
(`tutorials_in_package()` -\> `tutorial_doc()`), so
`learnr2::run_tutorial("<name>", package = "<host-pkg>")` finds the
`.qmd`, copies the dir,
[`add_live_extension()`](https://ppbds.github.io/learnr2/reference/add_live_extension.md)s
it, and
[`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html)s
it – `package=` only has to point at the host package, and `learnr2` +
the `quarto` CLI have to be installed. `R CMD check` on the host package
ignores the file (it is just data under `inst/`; the `{{< include >}}`
shortcode is inert text).

**What silently skips it.** The classic-learnr tooling only ever globs
for `.Rmd`:

- `learnr::available_tutorials("<host-pkg>")` does not list a
  `.qmd`-only dir, so
  `learnr::run_tutorial(..., package = "<host-pkg>")` cannot launch it.
- `tutorial.helpers::return_tutorial_paths()` is
  `list.files(<available_tutorials names>, pattern = "Rmd$")` – the
  `.qmd` never enters the list, so a host package whose render test / CI
  job is `return_tutorial_paths()` \|\> `knit_tutorials()` (e.g.
  `primer.tutorials`’s `student-env-render`) neither renders nor fails
  on it. It just goes uncovered.

**So when you do this, also:** add `learnr2` to the host `DESCRIPTION`
`Suggests` + `PPBDS/learnr2` to `Remotes`; `.Rbuildignore` and
`.gitignore` the on-demand `inst/tutorials/*/_extensions/` (and
`.quarto`); and add a dedicated CI job that runs
`learnr2::run_tutorial("<name>", package = "<host-pkg>", open = FALSE)`
and `stopifnot(file.exists(<returned html>))`, since the host’s existing
`.Rmd`-only render job will not touch it.

### Quick reference: what maps to what

| learnr / tutorial.helpers source | learnr2 `.qmd` equivalent |
|----|----|
| `output: learnr::tutorial`, `runtime: shiny_prerendered` | `format: live-html` + `engine: knitr` (see YAML below) |
| [`library(learnr)`](https://rstudio.github.io/learnr/) / [`library(tutorial.helpers)`](https://ppbds.github.io/tutorial.helpers/) setup chunk | delete it; call functions as `learnr2::fn()` |
| `knitr::opts_chunk$set(echo = FALSE)` in setup | a per-chunk `echo: false` option on every widget `{r}` chunk (never a doc-wide override) |
| `child = system.file("info_section.Rmd", ...)` | a `{r}` chunk calling [`learnr2::student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md) |
| `child = system.file("download_answers.Rmd", ...)` | a `{r}` chunk: minutes [`question()`](https://ppbds.github.io/learnr2/reference/question.md) + [`learnr2::download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md) |
| ```` ```{r ex1, exercise = TRUE} ```` | a [webr](https://github.com/cardiomoon/webr) cell with `label`, `exercise`, and `persist: true` chunk options |
| a shared ```` ```{r ex1-setup} ```` chunk | a [webr](https://github.com/cardiomoon/webr) cell with `setup: true` + the same `exercise:` label (or inline the setup into the exercise cell) |
| ```` ```{r ex1-hint, eval = FALSE} ```` / `ex1-hint-1`, `-2`, … | `::: { .hint exercise="ex1" }` div(s) |
| ```` ```{r ex1-solution} ```` (ungraded exercise) | `::: { .solution exercise="ex1" }` div with an ```` ```r ```` block |
| ```` ```{r ex1-solution} ```` (exercise that also has a check) | a [webr](https://github.com/cardiomoon/webr) cell with `solution: true` – the div form leaves the grader with no solution |
| ```` ```{r ex1-check} ````, `gradethis::grade_this_code()` | a [webr](https://github.com/cardiomoon/webr) cell with `check: true` for the same exercise + include `_gradethis.qmd` (and a `solution: true` cell, per the row above) |
| `question("...", answer("a", correct = TRUE), ...)` | `learnr2::question("...", learnr2::answer("a", correct = TRUE), ...)` |
| `question_text("...", answer("model answer", correct = TRUE), allow_retry = TRUE)` | `learnr2::question("...", learnr2::answer("model answer", correct = TRUE), type = "reflection")` (or `"reflection_editable"`) |
| `question_numeric("...", answer(90, correct = TRUE))` | `learnr2::question("...", type = "reflection_editable", validate = "integer")`, no [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md) |
| `question(..., allow_retry, random_answer_order, incorrect, correct)` | same argument names on [`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md) |
| bare `###` progressive-reveal divider (no real heading text) | delete; keep genuinely-titled `##`/`###` sections (learnr2 gates them itself – see “Progressive section reveal”) |
| `knitr::include_graphics("images/x.png")` in an `{r}` chunk | plain Markdown `![alt](images/x.png)` (drop the chunk) |
| prose telling the reader to use “the RStudio Console”, `rstudioapi::*`, `tutorial.helpers::show_file()`, etc. | rewrite around an on-page [webr](https://github.com/cardiomoon/webr) cell, or drop – see “No local R/RStudio dependency” |

The sections below expand on the non-obvious rows.

### YAML frontmatter

Replace the learnr frontmatter:

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

Drop `tutorial: id:`, `output:`/`runtime: shiny_prerendered` and the
`progressive:` / `allow_skip:` keys entirely – none of it applies
without a Shiny server, and learnr2 does progressive reveal itself (see
“Section dividers and progressive reveal”). Keep `subtitle:` if the
source had one, but update its wording along with `title:` so neither
still describes RStudio-only content (see “No local R/RStudio
dependency”). Add a `webr: packages: [...]` block listing every non-base
package any [webr](https://github.com/cardiomoon/webr) cell uses (see
its own section below).

Immediately after the frontmatter, include the `quarto-live` runtime
partial(s):

    {{< include _extensions/r-wasm/live/_knitr.qmd >}}

Add `{{< include _extensions/r-wasm/live/_gradethis.qmd >}}` too if any
exercise uses `check: true` / `gradethis::grade_this_code()`.

### Setup chunks

Drop the learnr `setup` chunk
([`library(learnr)`](https://rstudio.github.io/learnr/),
[`library(tutorial.helpers)`](https://ppbds.github.io/tutorial.helpers/),
`knitr::opts_chunk$set(...)`,
`options(tutorial.exercise.timelimit = ...)`) entirely. learnr2
functions are called with an explicit `learnr2::` prefix instead of
being attached with [`library()`](https://rdrr.io/r/base/library.html),
matching `hello-learnr2.qmd`.

### Exercise chunks

learnr’s `exercise = TRUE` R chunks:

    ```{r exercise-1, exercise = TRUE}
    ```

become [webr](https://github.com/cardiomoon/webr) chunks. Every one
needs three options: a `#| label:` (the `section-header-N` convention –
see “Every chunk needs a unique `#| label:`”), a `#| exercise:` id (any
stable slug; the bundled tutorials use `snake_case` like `ex_total`,
distinct from the dashed chunk label), and `#| persist: true` so the
reader’s typed code survives a page reload (saved to `localStorage`, and
picked up by
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
– without it there is *no* saved copy of their code anywhere):

    ```{webr}
    #| label: functions-and-packages-2
    #| exercise: ex_load_tidyverse
    #| persist: true
    ______
    glimpse(mtcars)
    ```

The cell body is the starter code the reader sees. Keep whatever the
source put there: an empty body, a leading `#` comment describing the
task, or `tutorial.helpers`’s `____` blanks (they carry over verbatim as
literal text for the reader to replace). Drop learnr chunk options with
no client-side meaning – `exercise.lines`, `exercise.timelimit`,
`exercise.cap`, `exercise.df_print`, `exercise.blanks`, `message`,
`warning`.

### Exercise setup chunks

learnr’s paired ```` ```{r ex1-setup} ```` chunk (shared objects an
exercise needs before the reader’s code runs – loading a dataset,
defining a helper) has two possible translations:

1.  **A [webr](https://github.com/cardiomoon/webr) `#| setup: true`
    cell** carrying the *same* `#| exercise:` label. quarto-live runs
    it, invisibly, in that exercise’s environment before the reader’s
    submission:

        ```{webr}
        #| label: analysis-3
        #| setup: true
        #| exercise: ex_summarise
        library(dplyr)
        flights <- nycflights13::flights
        ```

2.  **Inlining the setup lines at the top of the exercise cell itself**
    (what `intro-vectors/` does with `scores <- c(...)`). Simplest when
    it’s a line or two; it also makes the cell self-contained and
    visible.

Which to use is a judgement call, but be aware of *why* it matters:
**[webr](https://github.com/cardiomoon/webr) cells do not share state.**
Each exercise runs in its own environment (`exercise-env-<label>`),
separate from every other exercise and from any earlier non-exercise
[webr](https://github.com/cardiomoon/webr) demo cell, and a page reload
wipes all of it – only the reader’s typed code persists. So anything an
exercise depends on must be created by that exercise’s own `setup: true`
cell or its own body; you cannot rely on an earlier cell on the page
having “already run [`library()`](https://rdrr.io/r/base/library.html)”
the way a single shared R session would.

### Hints and solutions

An `exercise-1-hint` chunk (`eval = FALSE`) becomes a fenced div tied to
the exercise label:

    ::: { .hint exercise="ex_load_tidyverse" }
    Some hint text, or an inline code sample.
    :::

learnr’s *progressively numbered* hints (`ex1-hint-1`, `ex1-hint-2`, …)
become several consecutive `.hint` divs with the same `exercise=` –
quarto-live reveals them one at a time (“Next Hint”) – or collapse them
into one div if the sequencing doesn’t add much.

A model answer becomes a `.solution` div (the inner ```` ```r ```` block
is required – it’s what gets syntax-highlighted and offered as “Show
solution”):

    ::: { .solution exercise="ex_load_tidyverse" }
    ```r
    library(tidyverse)
    glimpse(mtcars)
    ```
    :::

**Exception – a graded exercise:** if the exercise also has a
`check: true` cell (next section), its solution must be a
`solution: true` **[webr](https://github.com/cardiomoon/webr) cell**,
*not* the `.solution` div:

    ```{webr}
    #| label: <section>-N
    #| exercise: ex_load_tidyverse
    #| solution: true
    library(tidyverse)
    glimpse(mtcars)
    ```

Only the cell form emits the hidden `<code class="solution-code">` that
quarto-live’s grader reads; the `.solution` div renders a “Show
solution” button but leaves `solution_code` empty, so
`gradethis::grade_this_code()` fails at submit time with *“No solution
code was found.”* (Verified against a real render – `live.lua`’s
`Proof()` filter passes the div through untouched, while its
`WebRCodeBlock` `solution: true` branch adds the `solution-code` node.)
The cell still shows the reader a “Show solution” button, same as the
div. `#| hint: true` cells are likewise an equivalent to the `.hint`
div; use whichever, but for a *graded* exercise the solution has to be
the cell.

### Grading (`check` chunks)

If a source exercise has a ```` ```{r ex1-check} ```` chunk with
`gradethis::grade_this_code()` (or similar), add
`{{< include _extensions/r-wasm/live/_gradethis.qmd >}}` after the
`_knitr.qmd` include, and translate the check to a
[webr](https://github.com/cardiomoon/webr) cell with `#| check: true`
and the exercise’s label. Its solution must be a `solution: true` cell,
not a `.solution` div (see the exception under “Hints and solutions”
above) – otherwise submit fails with *“No solution code was found.”* If
the source check is trivial or absent, just leave it out – a learnr2
exercise does not require grading to be useful, and most bundled ones
have none.

### Quiz questions

learnr
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
calls become
[`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md)
inside a plain `{r}` chunk (it runs once at render time, not
per-reader).
[`learnr2::answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
replaces
[`answer()`](https://ppbds.github.io/learnr2/reference/answer.md).
Argument names that carry over unchanged: `allow_retry`,
`random_answer_order` (choice questions only), `correct`, `incorrect`.
Group related questions with
[`learnr2::quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md).

Type mapping:

- **[`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  with `answer(correct = TRUE)` choices** -\>
  [`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md);
  leave `type` at its default (`"auto"` picks single vs. multiple by how
  many answers are correct), or set `type = "text"` for a typed
  exact-match answer.
- **`question_text()`** – `tutorial.helpers`’s workhorse for “In your
  own words, explain…” prompts, almost always written with a single
  `answer("a model paragraph", correct = TRUE)` and `allow_retry = TRUE`
  – maps to `type = "reflection"` (locks after submit) or
  `type = "reflection_editable"` (stays editable). The `correct`
  answer’s text becomes the model answer revealed after the reader
  submits; it is not graded against their wording. Drop
  `question_text()`-only options with no equivalent: `try_again_button`,
  `rows`, `options = list(...)`, `trim`, `placeholder`.
- **`question_numeric()`** -\> `type = "reflection_editable"`,
  `validate = "integer"`, and *no*
  [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md) (see
  the “minutes spent” discussion under “Authoring a new tutorial”).
- **Custom `answer_fn` / regex / multi-correct-with-partial checkers**
  have no learnr2 equivalent – reduce to plain
  [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md)
  matches, or to a `"reflection"` question if the point was open-ended.

See `hello-learnr2.qmd`’s quiz section for a worked example of every
type.

### Student info and submission

`tutorial.helpers`’s `info_section.Rmd` child document becomes
[`learnr2::student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md).
Its `download_answers.Rmd` child document becomes
`learnr2::download_answers_button(filename_prefix = "<name>")`. Both are
plain function calls in a `{r}` chunk – no child document, no
`context = "server"` chunk. See “Authoring a new tutorial” above for the
exact boilerplate blocks (including the “minutes spent” question that
sits with the download button).

### Images and other assets

Keep the source tutorial’s `images/` directory (or any other asset
folder) next to the translated `.qmd`. Reference images with plain
Markdown – `![alt text](images/thing.png)` – rather than a
`knitr::include_graphics("images/thing.png")` `{r}` chunk; the chunk
form would also need `#| echo: false` to hide its source, and the
Markdown form just works. Relative paths resolve against the `.qmd`’s
own directory, the same as in the source.

### Section dividers and progressive reveal

learnr drove its section-by-section reveal from `progressive: yes` /
`allow_skip: yes` in the YAML plus bare `###` dividers. learnr2 does
progressive reveal itself: `quiz.js` gates every `##` and `###` heading
behind a “Continue” button (see “Progressive section reveal” below). So:

- Delete the YAML `progressive`/`allow_skip` keys and any *content-free*
  `###` divider (a heading used purely as a pacing break, with no real
  title) – fold its prose up into the enclosing `##`.
- **Keep** every genuinely-titled `##`/`###` section. It becomes one
  Continue step automatically; you don’t add anything to opt in.
- `### Hints` / `### Solutions` subsections that only wrap a
  `.hint`/`.solution` div are *not* gated (quarto-live already has its
  own show/hide toggle for them) – leaving them in place is fine.

### `webr: packages:` must list every package any exercise uses

The `webr: packages: [...]` frontmatter block is the only place WebR
learns what to install into the browser session. List *every* non-base
package named in *any* [webr](https://github.com/cardiomoon/webr) cell
(exercise, setup, check, or demo) – if an exercise calls
[`library(dplyr)`](https://dplyr.tidyverse.org) or
`nycflights13::flights`, both `dplyr` and `nycflights13` belong in the
list. Conversely, a render-time `{r}` chunk should only ever be a
`learnr2::` widget call: do **not** port
[`library(...)`](https://rdrr.io/r/base/library.html) or data-loading
into `{r}` chunks, since those run in the render environment (CI), not
the reader’s browser, and would make the tutorial fail to build unless
that package is installed for rendering too.

### Hide source code on widget chunks (`echo: false`)

The learnr setup chunk you are told to drop, above, always included
`knitr::opts_chunk$set(echo = FALSE)`. That single line was doing real
work: it hid the R source of every chunk in the *entire rest of the
document* – including every
[`question()`](https://ppbds.github.io/learnr2/reference/question.md)/`question_text()`/`question_numeric()`
call and the child-document chunks – so the student only ever saw the
rendered widget, never the R call that produced it.

Dropping the setup chunk with nothing to replace that line means **every
plain `{r}` chunk you write now renders its own source code above its
output** (verified by actually rendering a translated tutorial with
Quarto and looking at the HTML – this is not hypothetical). That is
wrong for any `{r}` chunk whose job is to render a learnr2 widget for
the student
([`learnr2::student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
[`learnr2::question()`](https://ppbds.github.io/learnr2/reference/question.md),
[`learnr2::quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
[`learnr2::download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md),
or any other `{r}` chunk whose point is its *output*, not its code) –
leaking implementation code like this is something the original tutorial
explicitly went out of its way to prevent.

Fix: add `#| echo: false` to each such `{r}` chunk individually, e.g.:

    ```{r}
    #| echo: false
    learnr2::student_info()
    ```

Do **not** fix this with a document-wide `execute: echo: false` in the
YAML frontmatter – [webr](https://github.com/cardiomoon/webr) exercise
chunks are registered as a knitr *passthrough engine* (see `_knitr.qmd`)
that re-emits its own source as its “output” by design, so it’s not
verified safe against a global echo override and a chunk-scoped fix
avoids the question entirely.

### No local R/RStudio/other-package dependency in the content itself

This is the single most important semantic difference between learnr and
learnr2, and it is easy to translate the *syntax* correctly while still
getting this wrong: **a learnr2 tutorial requires no local R install, no
RStudio, and no other R package** (see the package `DESCRIPTION`: “runs
entirely in the browser using Quarto and WebR … without Shiny, R
Markdown, or a server”). Every exercise runs in a
[webr](https://github.com/cardiomoon/webr) cell, in the reader’s
browser, on the same page.

A verified real regression: a translation attempt correctly applied
every mechanical rule above (frontmatter,
[webr](https://github.com/cardiomoon/webr) exercises, `echo: false`, the
`.qmd` file structure) and *still* produced a broken tutorial, because
it left several exercises’ prose untouched from the source – telling the
reader to open “the R Console” (i.e. a separate, locally-installed
RStudio) and run commands like
`tutorial.helpers::set_rstudio_settings()`,
`rstudioapi::readRStudioPreference(...)`, or
`tutorial.helpers::show_file(...)`. Those are real functions from a
*different, unrelated R package* (`tutorial.helpers`) that has nothing
to do with learnr2 and is not installed for a learnr2 reader. A reader
who opened this tutorial from a link with no R installed at all – which
learnr2’s whole pitch says should work fine – would hit a wall at that
exercise. It also left the document’s `title:` as the source’s literal
`"Tutorials in RStudio"`, which is wrong once the content no longer
assumes RStudio.

When translating, actively look for and remove/rewrite anything that
assumes: - a separate, locally-running R session or “Console” the reader
alt-tabs to (distinct from a [webr](https://github.com/cardiomoon/webr)
cell on the page itself) - any R package other than base R (or
whatever’s declared in `webr: packages:`) being available to run -
RStudio itself being installed, or RStudio-specific UI/menus/settings -
any source content that walks through *restarting a tutorial from
scratch* as a multi-step manual procedure (quit, reopen, re-answer
everything by hand): every learnr2 page already has a single “Start
Over” button at the bottom of the sidebar (see “Progress persistence” in
`R/question.R`) that clears all of it – link to that instead of
reproducing the source’s manual steps

If the source tutorial’s *point* was genuinely about configuring a local
R install (as opposed to how-tutorials-work content that merely happened
to run inside RStudio), that content doesn’t have a learnr2 translation
at all – drop it rather than reproduce commands the reader can’t
actually run here. Don’t keep it “because it’s still generally useful R
knowledge” – judge it by whether the reader of *this* tutorial, using
*this* format, can act on it.

Also update the document’s `title:`/`subtitle:` to reflect what the
tutorial actually is now, rather than leaving a source title like
“Tutorials in RStudio” that no longer matches content that’s been
generalized away from RStudio.

### General rule: verify by actually rendering

Syntax that merely *looks* plausible can still be wrong in ways that are
only visible in the rendered HTML (like the `echo` issue above). After
translating (or hand-authoring), actually render the tutorial with
Quarto and open the result, rather than relying on visual inspection of
the `.qmd` source alone:

``` sh
Rscript -e "learnr2::add_live_extension('path/to/tutorial/dir')"
quarto render path/to/tutorial/dir/tutorial.qmd
```

Then check the rendered `.html` (e.g. serve the directory and open it in
a browser) for anything that shouldn’t be visible to a student – most
importantly, source code above a widget that should be output-only.
Don’t commit the render artifacts (`_extensions/`, `*.html`, `*_files/`,
`.quarto/`, `*.knit.md`) alongside the tutorial’s `.qmd` –
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
and
[`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
add the extension and render on demand, and none of the bundled
tutorials in this repo commit those generated files.

### `run_tutorial()`/`library(learnr2)` reads the *installed* package, not this checkout

A real mistake, caught only after a user reported edited content simply
not showing up: after editing
`inst/tutorials/getting-started/tutorial.qmd` (adding a question),
`inst/extdata/quiz/quiz.css`, and `quiz.js` directly in this git working
tree, none of the changes appeared when the user ran
`learnr2::run_tutorial("getting-started")` in their own R session –
`git status` confirmed the edits were genuinely there, uncommitted, in
the source tree the whole time.

The cause:
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
(`R/tutorials.R`) locates a tutorial with
`system.file("tutorials", name, package = package)`, and every
`{r}`/[webr](https://github.com/cardiomoon/webr) asset (`quiz.js`,
`quiz.css`, the `quarto-live` extension) is likewise resolved via
[`system.file()`](https://rdrr.io/r/base/system.file.html) inside the
package’s own R functions.
[`system.file()`](https://rdrr.io/r/base/system.file.html) always
resolves against whichever copy of the package is *installed* in the R
library currently in use – a separate, already-built copy, entirely
distinct from this git checkout – regardless of how recently this
checkout was edited. Plain
[`library(learnr2)`](https://github.com/PPBDS/learnr2) after editing
source files does **not** pick up the edits; nothing here re-reads this
working tree automatically.

Two ways to actually see a local edit reflected:

- Reinstall from this checkout, then start a fresh R session (or at
  minimum `unloadNamespace("learnr2")`) before calling
  [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
  again. `devtools::install(".")` and `pak::pak("local::.")` both need
  their respective package already installed – confirmed a plain setup
  can have neither
  (`Error in loadNamespace(x) : there is no package called 'devtools'`).
  Base R needs nothing extra and always works from inside the package
  directory:

  ``` r

  install.packages(".", repos = NULL, type = "source")
  ```

- Iterating on several edits: `devtools::load_all(".")` instead –
  `pkgload` patches
  [`system.file()`](https://rdrr.io/r/base/system.file.html) for a
  `load_all()`-loaded package to resolve straight to this source tree’s
  `inst/`, so
  [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
  picks up changes with no reinstall step, as long as the same R session
  that ran `load_all()` is the one calling it.

The `quarto render path/to/tutorial/dir/tutorial.qmd` verification
command in the rule just above this one sidesteps this problem entirely,
since it renders the `.qmd` file directly and never calls
[`system.file()`](https://rdrr.io/r/base/system.file.html) – prefer it
for a quick check. But if verifying (or asking a user to verify) via
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)/[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)/any
other exported function instead, the package must be reinstalled or
`load_all()`-loaded first, or the “verification” is silently checking
stale, pre-edit content.

One more staleness trap, caught for real: even *after* a correct
reinstall,
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
re-rendering into its cache dir
(`tools::R_user_dir("learnr2", "cache")/<name>/`) can still serve an old
`quiz.js`. Quarto writes the JS/CSS dependency into
`<name>_files/libs/learnr2-quiz-<version>/`, and if a previous render
left a directory there for the same version string, the new render does
not necessarily overwrite it. After editing
`inst/extdata/quiz/quiz.{js,css}`, `rm -rf` the tutorial’s cache dir
before re-rendering (or bump the package version so the
`libs/learnr2-quiz-<version>/` path changes). Confirm by grepping the
served `quiz.js` for something you just added.

## Test suite layout

Two layers, both run in CI (`.github/workflows/R-CMD-check.yaml`,
`js-tests.yaml`):

- **R (`testthat`, edition 3), `tests/testthat/`** – one `test-*.R` file
  per `R/*.R` source file: `test-question.R`, `test-submission.R`,
  `test-tutorials.R`, `test-extension.R`, `test-create-tutorial.R`.
  Every exported function *and* every internal helper has a test; call
  internals as `learnr2:::helper()`. Heavy/external calls are mocked
  with `testthat::local_mocked_bindings(..., .package = "<pkg>")` –
  `quarto`, `httpuv` for
  [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md),
  `utils`/`rstudioapi` for `open_file()` – so no test renders with
  Quarto, boots WebR, launches a browser, or hits the network. One
  defensive guard is deliberately left untested (noted in a comment
  where it lives):
  [`live_extension_dir()`](https://ppbds.github.io/learnr2/reference/live_extension_dir.md)’s
  missing-package branch – it needs a broken install to reach, and
  `base::` bindings can’t be mocked.
- **JS (`Playwright`), `tests/js/`** – `quiz.js` (the browser runtime)
  has no unit layer; it’s covered end-to-end through `quiz.spec.js`
  (against a local fixture server, `server.js` + `fixtures.js`) and
  `persistence.spec.js` (real browser close/relaunch).
  `deployed-smoke.spec.js` runs separately against the live GitHub Pages
  deploy (see its own section below). Fixture question `id`s in
  `fixtures.js` are written chunk-label style (`single-choice`,
  `reflection-locked`) to match what `question_id()` now emits.

Run them: `R -q -e 'devtools::test()'` (or
[`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html) +
`testthat::test_dir("tests/testthat")`), and
`cd tests/js && npx playwright test`.

## Progressive section reveal (“Continue” buttons)

`initProgressiveSections()` in `quiz.js` gates every `##`/`###` heading
behind a “Continue” button, hidden until the reader clicks through the
section before it – relying on Quarto wrapping each heading in its own
`<section id="..." class="level2"|"level3">`, nested for subsections.
Confirmed against a real rendered `hello-learnr2.html` (found at
`tools::R_user_dir("learnr2", "cache")` after running
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
– see the section above – and served locally to click through in a real
browser), not just the JS test fixtures in `tests/js/fixtures.js`: the
`section.levelN` nesting those fixtures assume is exactly what a real
render produces.

That same real-render check caught a genuine regression in the first
version of this feature: it gated every
`section.level2`/`section.level3` uniformly, with no exception for a
`### Hints`/`### Solutions` section (a `.hint`/`.solution` fenced div
tied to one exercise – see “Quiz questions” below for the fenced-div
syntax, or `hello-learnr2.qmd`’s own “3. Exercises”). Those exist purely
as a supplementary, reader-toggled aside for the exercise right before
them (quarto-live already hides the actual hint/solution content behind
its own “Show Hint”/reveal-solution toggle, independent of anything
here) – not a step of their own to progress through. Gating them anyway
meant reaching “4. Setup cells” from “3. Exercises” took two extra,
easy-to-miss clicks through bare “Hints”/ “Solutions” stops with no
number of their own, reported by a user as the visible numbering jumping
straight from section “2” to section “5” and skipping “3”/“4” entirely –
when what actually happened was two invisible intermediate stops in
between, not a skip. Fixed by excluding any `section.level3` that itself
contains quarto-live’s own `.exercise-hint`/`.exercise-solution` marker
(confirmed from the real render – note bare `.hint`/`.solution` is *not*
what actually ends up in the rendered class list, only the `exercise-`
prefixed ones) from the gated list entirely, so it simply inherits its
enclosing section’s visibility instead of demanding a Continue click of
its own.

The general lesson, not just about this one feature: a synthetic JS test
fixture built from a *description* of what Quarto’s output looks like
can still miss a real structural detail the description didn’t account
for (here, that hint/solution asides are themselves heading sections).
Prefer checking against an actual rendered tutorial when one is
available (as above) over trusting a hand-built fixture alone,
especially for anything that walks heading/section structure.

## Publishing tutorials via GitHub Pages

Every bundled tutorial is also published as static HTML, so students can
open one from a link with nothing installed at all – no R, no Quarto,
not even this package. `.github/workflows/tutorials.yaml` does this on
every push that touches `inst/tutorials/**`, `inst/extdata/**`, `R/**`,
or the render script itself:

1.  `Rscript tools/render_tutorials_for_pages.R` renders every tutorial
    `available_tutorials(package = "learnr2")` finds (via
    [`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html),
    same as
    [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md))
    into `_site/tutorials/<name>/<name>.html`, plus a generated
    `_site/tutorials/index.html` linking all of them.
2.  `JamesIves/github-pages-deploy-action` pushes `_site/tutorials/` to
    the `tutorials/` path of the `gh-pages` branch – the same branch and
    Pages site `pkgdown.yaml` already publishes the package’s own
    documentation to (`https://ppbds.github.io/learnr2/`), so a tutorial
    ends up at
    `https://ppbds.github.io/learnr2/tutorials/<name>/<name>.html`.

Nothing server-side is involved at either step: rendering happens once
in CI, not per-reader, and the page itself still runs entirely in the
reader’s browser via WebR exactly as described throughout this file –
GitHub Pages is just a static file host for the already-self-contained
HTML.

### Automated smoke test after every deploy

A render succeeding doesn’t prove the *live* page actually works for a
reader – GitHub Pages could still end up serving something stale,
broken, or missing the `quarto-live` extension. `tutorials.yaml`’s
second job, `smoke-test`, checks this automatically after every deploy
(`needs: tutorials`) instead of relying on someone remembering to click
through a tutorial by hand after a push:

1.  Polls the live `hello-learnr2` URL (a `curl` retry loop, since
    GitHub Pages/its CDN can lag a few minutes behind a push) until it
    actually serves fresh content, with a cache-busting query string as
    a best-effort guard against checking a stale cached copy.
2.  Runs `tests/js/deployed-smoke.spec.js` (via
    `tests/js/playwright.smoke.config.js`, a separate config from the
    rest of `tests/js/` since this targets a real URL with no local dev
    server to manage) against that live page in a real browser: fills in
    known
    [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
    values and answers a couple of
    [`question()`](https://ppbds.github.io/learnr2/reference/question.md)s
    with known answers, clicks the download button, and asserts those
    exact known values – and nothing else – come back out of the
    downloaded JSON. This is exactly the manual “fill in a couple of
    answers at random, download, confirm they’re in the file” check,
    just automated and run on every push instead of by hand
    occasionally.
3.  Deliberately only exercises
    [`question()`](https://ppbds.github.io/learnr2/reference/question.md)/[`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)/
    [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
    – plain JS, not [webr](https://github.com/cardiomoon/webr) – so it
    can’t flake on WebR’s WebAssembly runtime being slow to boot in CI,
    the same limitation noted earlier in this file for rendering checks
    in a restricted-network sandbox.

Run it locally against any deployed (or
[`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)-served)
URL with:

``` sh
cd tests/js
SMOKE_URL="https://ppbds.github.io/learnr2/tutorials/hello-learnr2/hello-learnr2.html" npm run test:smoke
```

Not yet verified against a real push to the actual repo (this sandbox
can’t trigger or observe a live GitHub Actions run) – worth watching the
first real run of the `smoke-test` job after this lands, both to confirm
the wait loop’s timing is long enough and that the live selectors still
match.
