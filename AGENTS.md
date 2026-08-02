# learnr2

learnr2 is a from-scratch reimplementation of the ideas behind **learnr**
(and the **tutorial.helpers** package built on top of it), but targeting
**Quarto + `quarto-live` + WebR** instead of **R Markdown + Shiny**. There is
no Shiny app and no R server: tutorials render to a static `.html` file, and
exercise code cells run client-side in the reader's browser via WebR
(R compiled to WebAssembly).

## Templates vs. instructions (a settled design question)

Worth settling once, since it shapes how this whole file is used: for
authoring a new learnr2 tutorial, is a starter template
(`inst/templates/tutorial.qmd`, scaffolded by `create_tutorial()`) enough on
its own, or does an author -- human or AI -- need written instructions like
this file?

**Verdict: written instructions win.** A template shows *what* a correct
file looks like, once; it can't explain *why*, so it can't stop anyone from
reproducing exactly the mistakes documented below the moment they stray from
it even slightly -- adding one plain `{r}` chunk, translating a real learnr
tutorial instead of starting fresh, or misremembering which `echo` option
goes where. Concretely, none of the following is learnable from the
template alone:

- The `echo: false` chunk-scoped requirement (below) -- the template already
  has it on every chunk that needs it, so nothing *in* the template teaches
  you that it's required, or why a document-wide override breaks `{webr}`
  chunks specifically.
- The "no local R/RStudio dependency" translation trap (below) -- it has no
  counterpart in the template at all, since it only surfaces when
  translating existing learnr content, which a from-scratch template can't
  anticipate.
- "Verify by actually rendering" isn't a fact a template can express; it's a
  workflow rule, and the regression below was only caught by following it.

Practically: **this file is the primary authoring guide; the template is a
labor-saving shortcut for boilerplate, never a substitute for reading this
first.** This was tested directly: `inst/tutorials/intro-vectors/` was
hand-authored from these instructions alone (not via `create_tutorial()`,
not by copying the template), then rendered and checked in a browser to
confirm the result was correct without the template's help. If you're
authoring a tutorial and haven't read the rest of this file yet, that's the
bug to fix before writing any `.qmd` content.

### Is `create_tutorial()` still worth keeping?

Realistically, few humans will type `create_tutorial("my-tutorial")` at an R
console -- most tutorial authoring from here on is either a person editing
an existing `.qmd` directly, or an AI agent writing one from a prompt. But
an agent is exactly the kind of caller `create_tutorial()` suits well: it's
one unambiguous action (scaffold the `.qmd` *and* copy the `quarto-live`
extension alongside it) instead of hand-typing frontmatter and remembering
a separate `add_live_extension()` call. Conclusion: keep it. An agent
following this file can either call it for a guaranteed-correct starting
point, or write the `.qmd` by hand the way `intro-vectors/` was written --
both are proven to work here. A human author is equally free to do either.

### `student_info()` is a different kind of question

The template-vs-instructions question above is about *authoring-time
tooling* -- how a tutorial's `.qmd` file comes into existence.
`student_info()` (like `question()`, `quiz()`, `download_answers_button()`)
isn't authoring tooling at all -- it's part of a tutorial's actual
*content*: a function call that belongs inside the `.qmd`, written by
whoever is authoring that tutorial regardless of whether they got there via
`create_tutorial()`, by hand, or by translating an existing tutorial. There
is no "template vs. instructions" choice to make about it; it's simply
covered by the boilerplate section below, every time.

## Reference files to read before translating anything

- `inst/templates/tutorial.qmd` -- the skeleton `create_tutorial()` scaffolds.
- `inst/tutorials/hello-learnr2/hello-learnr2.qmd` -- a complete worked example
  exercising every learnr2 feature.
- `inst/tutorials/intro-vectors/intro-vectors.qmd` -- a small tutorial
  hand-authored from this file alone, as the test described above.
- `R/question.R`, `R/submission.R` -- source of truth for `learnr2::question()`,
  `learnr2::quiz()`, `learnr2::student_info()`, `learnr2::download_answers_button()`.

## Authoring a new tutorial (not translating one)

`tutorial.helpers` gets its standard boilerplate -- name/email/ID at the top,
a "minutes spent" question plus a download button at the bottom -- from two
child documents (`info_section.Rmd`, `download_answers.Rmd`) included via
`child = system.file(...)`. learnr2 has no child-document mechanism; the
equivalent is just writing the same two plain-function-call blocks
directly into the `.qmd`, by hand, every time:

```{r}
#| echo: false
learnr2::student_info()
```

at the top (right after the frontmatter/intro prose), and at the bottom:

```{r}
#| echo: false
learnr2::question(
  "How many minutes, approximately, did it take you to complete this
  tutorial? For example, an hour and a half would be 90 minutes.",
  learnr2::answer(
    "There's no fixed correct answer here --- just enter your honest
    estimate, as a number of minutes.",
    correct = TRUE
  ),
  type = "reflection_editable",
  validate = "integer"
)
```

```{r}
#| echo: false
learnr2::download_answers_button(filename_prefix = "<tutorial-name>")
```

(`type = "reflection_editable"` stands in for learnr's `question_numeric()`
here -- `learnr2::question()` has no dedicated numeric type. `validate =
"integer"` is the closest match: it blocks Submit client-side unless the
typed response is a whole number, without grading it against one specific
value, since any honest minute count is acceptable. This is a deliberate,
settled choice, not a gap to keep re-litigating per tutorial.)

`inst/templates/tutorial.qmd` -- the file `create_tutorial()` scaffolds --
already includes both blocks (with `{{name}}` filled in automatically for
the download button's `filename_prefix`), so a brand-new tutorial gets this
for free. Reach for the snippets above when hand-authoring instead (as in
`intro-vectors/`), or when adding this boilerplate to a `.qmd` translated
from a learnr/tutorial.helpers source per the next section.

Don't forget `#| echo: false` on all three chunks (see that section, below,
for why it matters).

## Showing inline-code syntax literally, without triggering it

Sometimes prose needs to *show* what inline code looks like -- the literal
text `` `r x` `` -- right next to its actual evaluated result, e.g. "writing
`` `r x` `` produces: the value is 123". The naive way to write the literal
half, wrapping it in one extra pair of backticks (`` `` `r x` `` ``, a
double-backtick code span), **does not work**: verified by rendering, Quarto
still evaluates it, so both halves of that sentence show the *computed
value* and there's no way left to show the syntax itself. This surprised a
real translation attempt (`vscode.tutorials2`'s `02-quarto`) enough that its
source `.Rmd` has its own comment calling this out: "If you try to include
the inline code in the middle of a sentence, all hell breaks loose... so we
hack."

The fix, matching that source file's own workaround: spell the backticks as
the HTML entity `&#96;` inside a `<code>` tag instead of typing literal
backtick characters --

```
<code>&#96;r x&#96;</code>
```

-- which Quarto has no reason to treat as executable, since there's no
backtick character in the source for its inline-code regex to match. Use
this whenever a tutorial's own subject is Quarto/knitr syntax itself (like
explaining what inline code or chunk options are) and needs to show, not
run, an example.

## Translating a learnr/tutorial.helpers `.Rmd` tutorial to learnr2 `.qmd`

Tutorials from `tutorial.helpers`-based packages live at
`tutorials/<name>/tutorial.Rmd` inside the installed package (find them with
`system.file("tutorials", package = "tutorial.helpers")`, or similar for
other `*.tutorials` packages). Translate one into
`inst/tutorials/<name>/tutorial.qmd` in learnr2.

### YAML frontmatter

Replace the learnr frontmatter:

```yaml
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

```yaml
---
title: "Some Title"
format: live-html
engine: knitr
toc: true
---
```

Drop `tutorial: id:`, `output:`/`runtime: shiny_prerendered` entirely -- none
of it applies without a Shiny server. Add a `webr: packages: [...]` block
only if the tutorial actually attaches non-base packages inside exercises.

Immediately after the frontmatter, include the `quarto-live` runtime partial(s):

```
{{< include _extensions/r-wasm/live/_knitr.qmd >}}
```

Add `{{< include _extensions/r-wasm/live/_gradethis.qmd >}}` too if any
exercise uses `check: true` / `gradethis::grade_this_code()`.

### Setup chunks

Drop the learnr `setup` chunk (`library(learnr)`, `library(tutorial.helpers)`,
`knitr::opts_chunk$set(...)`, `options(tutorial.exercise.timelimit = ...)`)
entirely. learnr2 functions are called with an explicit `learnr2::` prefix
instead of being attached with `library()`, matching `hello-learnr2.qmd`.

### Exercise chunks

learnr's `exercise = TRUE` R chunks:

````
```{r exercise-1, exercise = TRUE}
```
````

become `{webr}` chunks with an `exercise:` option and a stable label. Blanks
the student must fill in are written as a run of underscores:

````
```{webr}
#| exercise: exercise_1
______
```
````

Add `#| persist: true` so the reader's edits survive a page reload (saved to
`localStorage`).

### Hints and solutions

An `exercise-1-hint-1` chunk (`eval = FALSE`) becomes a fenced div tied to
the exercise label:

```
::: { .hint exercise="exercise_1" }
Some hint text, or an inline code sample.
:::
```

A model answer becomes a `.solution` div:

````
::: { .solution exercise="exercise_1" }
```r
the_solution_code()
```
:::
````

### Quiz questions

learnr's `question()` / `question_text()` / `question_numeric()` become
`learnr2::question()` calls inside a plain `{r}` chunk (this runs once at
render time, not per-reader -- see `hello-learnr2.qmd` section 6 for the full
set of examples: single/multiple choice, `type = "text"`, `type =
"reflection"`, `type = "reflection_editable"`). Group related ones with
`learnr2::quiz()`.

### Student info and submission

`tutorial.helpers`'s `info_section.Rmd` child document becomes
`learnr2::student_info()`. Its `download_answers.Rmd` child document becomes
`learnr2::download_answers_button(filename_prefix = "<name>")`. Both are
plain function calls in a `{r}` chunk -- no child document, no
`context = "server"` chunk.

### Section dividers

learnr's bare `### ` dividers (used for its section-by-section progressive
reveal) can just be deleted -- collapse the prose into the enclosing `##`
section.

### Hide source code on widget chunks (`echo: false`)

The learnr setup chunk you are told to drop, above, always included
`knitr::opts_chunk$set(echo = FALSE)`. That single line was doing real work:
it hid the R source of every chunk in the *entire rest of the document* --
including every `question()`/`question_text()`/`question_numeric()` call and
the child-document chunks -- so the student only ever saw the rendered
widget, never the R call that produced it.

Dropping the setup chunk with nothing to replace that line means **every
plain `{r}` chunk you write now renders its own source code above its
output** (verified by actually rendering a translated tutorial with Quarto
and looking at the HTML -- this is not hypothetical). That is wrong for any
`{r}` chunk whose job is to render a learnr2 widget for the student
(`learnr2::student_info()`, `learnr2::question()`, `learnr2::quiz()`,
`learnr2::download_answers_button()`, or any other `{r}` chunk whose point
is its *output*, not its code) -- leaking implementation code like this is
something the original tutorial explicitly went out of its way to prevent.

Fix: add `#| echo: false` to each such `{r}` chunk individually, e.g.:

````
```{r}
#| echo: false
learnr2::student_info()
```
````

Do **not** fix this with a document-wide `execute: echo: false` in the YAML
frontmatter -- `{webr}` exercise chunks are registered as a knitr
*passthrough engine* (see `_knitr.qmd`) that re-emits its own source as its
"output" by design, so it's not verified safe against a global echo
override and a chunk-scoped fix avoids the question entirely.

### No local R/RStudio/other-package dependency in the content itself

This is the single most important semantic difference between learnr and
learnr2, and it is easy to translate the *syntax* correctly while still
getting this wrong: **a learnr2 tutorial requires no local R install, no
RStudio, and no other R package** (see the package `DESCRIPTION`: "runs
entirely in the browser using Quarto and WebR ... without Shiny, R
Markdown, or a server"). Every exercise runs in a `{webr}` cell, in the
reader's browser, on the same page.

A verified real regression: a translation attempt correctly applied every
mechanical rule above (frontmatter, `{webr}` exercises, `echo: false`, the
`.qmd` file structure) and *still* produced a broken tutorial, because it
left several exercises' prose untouched from the source -- telling the
reader to open "the R Console" (i.e. a separate, locally-installed RStudio)
and run commands like `tutorial.helpers::set_rstudio_settings()`,
`rstudioapi::readRStudioPreference(...)`, or
`tutorial.helpers::show_file(...)`. Those are real functions from a
*different, unrelated R package* (`tutorial.helpers`) that has nothing to
do with learnr2 and is not installed for a learnr2 reader. A reader who
opened this tutorial from a link with no R installed at all -- which
learnr2's whole pitch says should work fine -- would hit a wall at that
exercise. It also left the document's `title:` as the source's literal
`"Tutorials in RStudio"`, which is wrong once the content no longer assumes
RStudio.

When translating, actively look for and remove/rewrite anything that
assumes:
- a separate, locally-running R session or "Console" the reader alt-tabs
  to (distinct from a `{webr}` cell on the page itself)
- any R package other than base R (or whatever's declared in `webr:
  packages:`) being available to run
- RStudio itself being installed, or RStudio-specific UI/menus/settings
- a whole-tutorial "Start Over"/reset control (no such thing exists; see
  "Progress persistence" in `R/question.R`)

If the source tutorial's *point* was genuinely about configuring a local R
install (as opposed to how-tutorials-work content that merely happened to
run inside RStudio), that content doesn't have a learnr2 translation at
all -- drop it rather than reproduce commands the reader can't actually run
here. Don't keep it "because it's still generally useful R knowledge" --
judge it by whether the reader of *this* tutorial, using *this* format, can
act on it.

Also update the document's `title:`/`subtitle:` to reflect what the
tutorial actually is now, rather than leaving a source title like "Tutorials
in RStudio" that no longer matches content that's been generalized away
from RStudio.

### General rule: verify by actually rendering

Syntax that merely *looks* plausible can still be wrong in ways that are
only visible in the rendered HTML (like the `echo` issue above). After
translating (or hand-authoring), actually render the tutorial with Quarto
and open the result, rather than relying on visual inspection of the `.qmd`
source alone:

```sh
Rscript -e "learnr2::add_live_extension('path/to/tutorial/dir')"
quarto render path/to/tutorial/dir/tutorial.qmd
```

Then check the rendered `.html` (e.g. serve the directory and open it in a
browser) for anything that shouldn't be visible to a student -- most
importantly, source code above a widget that should be output-only. Don't
commit the render artifacts (`_extensions/`, `*.html`, `*_files/`,
`.quarto/`, `*.knit.md`) alongside the tutorial's `.qmd` -- `run_tutorial()`
and `create_tutorial()` add the extension and render on demand, and none of
the bundled tutorials in this repo commit those generated files.
