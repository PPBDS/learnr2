# learnr2

learnr2 reimplements the ideas behind **learnr** and **tutorial.helpers** on
**Quarto + quarto-live + WebR** instead of **R Markdown + Shiny**. Tutorials
render to a static `.html` page. Code cells run in the reader's browser via
WebR, and questions are graded there by `inst/extdata/quiz/quiz.js`. There
is no server.

This file is for working **on learnr2 itself**: its R code, `quiz.js`, tests,
CI and CRAN submissions. Each rule here carries a line or two on the failure
that taught it; keep that when editing, because it is what stops a rule from
being "simplified" away.

## Writing or translating a tutorial? Read the vignettes

Tutorial-authoring guidance lives in the package vignettes, which ship to
CRAN and the pkgdown site, so authors in content packages
(`ims.tutorials`, `primer.tutorials`, ...) get them too:

- `vignettes/ai.qmd`, "Tutorials in the Age of AI": what a tutorial is for
  and how it teaches. The learnr2 edition of the
  [tutorial.helpers essay](https://ppbds.github.io/tutorial.helpers/articles/ai.html)
  of the same name, copied verbatim at upstream commit `da79904`
  (2026-07-23) and then adapted. When the upstream essay changes, port the
  change.
- `vignettes/translating.qmd`, "Translating learnr Tutorials": the
  mechanics reference. Learnr-to-learnr2 mapping, YAML, labels, `echo`,
  exercise cells, hints, grading, question types, packages, the
  "page needs nothing installed" rule, checking.

Read both before authoring tutorial content in this repo. When a rule about
tutorial *content* changes, change it in the vignette, not here. Also see
`inst/tutorials/hello-learnr2/hello-learnr2.qmd`, the feature tour, and
`inst/templates/tutorial.qmd`, what `create_tutorial()` scaffolds.

Vignette prose follows the house style: package names **bold**, keyboard
input in backticks, function names with `()`, no semicolons.

## Settled design decisions

- **Instructions beat templates.** A template shows what a correct file
  looks like once; it can't say why, so authors repeat the documented
  mistakes the moment they deviate. The vignettes are the authoring guide.
  `create_tutorial()` stays as a one-call way to get correct boilerplate
  plus the extension, which suits agents well.
- **Submit once, then locked.** Every text or image question is
  `type = "reflection"`, and `tutorial_options(require_submission = TRUE)`,
  the default, disables a section's Continue until every `question()` and
  `student_info()` above it is submitted. Reason: we show our answer right
  after the reader's, and an editable box beside it invites copying it
  back. `reflection_editable` is for the minutes question only.
- **Tutorial-wide switches go through `tutorial_options()`**, never a new
  YAML key: `quiz.js` can't see the YAML, and the hidden
  `<div class="learnr2-options">` with base64 JSON (merged over
  `OPTION_DEFAULTS` by `readTutorialOptions()`) is the one channel that
  reaches it. `check_tutorial()` treats a `tutorial_options()` chunk as a
  widget chunk for the `echo` rule.
- **Question ids default to the chunk label** (`question_id()` /
  `current_chunk_label()` in `R/question.R`). The id is the `localStorage`
  key and the id in the downloaded file, so renaming a chunk resets that
  question. JS fixture ids are written chunk-label style to match.

## Editing learnr2 and seeing the result

`run_tutorial()` and every asset lookup go through `system.file()`, which
reads the **installed** copy of learnr2, not this checkout. A user once
edited a tutorial, `quiz.js` and `quiz.css` here, ran `run_tutorial()`, and
saw none of it.

- Reinstall, then restart R: `install.packages(".", repos = NULL, type =
  "source")` needs nothing extra. (`devtools::install()` and
  `pak::pak("local::.")` need those packages, which a plain setup may lack.)
- Or iterate with `devtools::load_all(".")`: pkgload patches
  `system.file()` for the loaded package, as long as the same session calls
  `run_tutorial()`.
- `quarto render path/to/<name>.qmd` after `add_live_extension()` sidesteps
  `system.file()` entirely, so it is the quickest check.
- **Cache staleness.** Even after a correct reinstall, a re-render into
  `run_tutorial()`'s cache (`tools::R_user_dir("learnr2", "cache")`) can
  keep an old `quiz.js`, because Quarto doesn't always overwrite
  `<name>_files/libs/learnr2-quiz-<version>/`. After editing `quiz.js` or
  `quiz.css`, delete the cache dir or bump the version, and grep the served
  `quiz.js` for your change.

Content packages hit the reverse trap: their `devtools::test()` loads them
with `load_all()`, but learnr2's own `system.file()` call didn't see that,
so every test skipped or tested a stale install. Fixed (2026-10):
`available_tutorials()` and `run_tutorial()` detect a pkgload namespace via
the internal `pkg_file()` in `R/tutorials.R` and read the source tree. That
fixes tutorial *discovery* only; learnr2's own assets still come from the
learnr2 that is loaded.

**Verify against a real render.** Synthetic JS fixtures built from a
*description* of Quarto's output have missed real structure more than once
(see "Progressive reveal" below). For anything that walks the rendered
page, render a real tutorial and check it in a browser.

## Progressive reveal and `quiz.js` page behaviour

`initProgressiveSections()` gates every `section.level2`/`section.level3`
(Quarto wraps each heading and its content in one, nested for
subsections) behind a Continue button. Verified against real renders.

- **Hints/Solutions are not stops.** A `section.level3` containing
  quarto-live's `.exercise-hint`/`.exercise-solution` marker (the
  `exercise-` prefixed classes, not bare `.hint`/`.solution`) is excluded
  from gating. The first version gated them, adding two invisible extra
  clicks that a user reported as the numbering "jumping" from 2 to 5.
- **No Continue directly under a heading** (2026-10). A `section.level3`
  that is its parent's heading's next sibling is excluded from gating, so
  it is revealed with that heading. tutorial.helpers opens every topic as
  `## Title` then a bare `###`, and gating that put a Continue under the
  heading with nothing above it (reported on the Orientation
  translation). Rule: a button ends readable content; clicking it reveals
  the next heading *and* its text. Fixture:
  `progressive-sections-topic-start`. `markPauseSections()` runs over
  *every* section, not just the gated list: when it ran only on gated
  sections, the ungated first pause kept its empty `<h3>`, a 64px blank
  band between a topic's title and its first paragraph.
- **Bare `###` dividers are stops** (2026-10). Quarto renders them as
  sections with an empty `<h3>` and ids `section`, `section-1`, ....
  `markPauseSections()` adds `.learnr2-pause`, CSS hides the empty heading,
  and the button reads plain "Continue". Quarto already hides their empty
  TOC entries. Fixture: `progressive-sections-pauses`.
- **TOC locking** (2026-10). Sidebar links would otherwise bypass Continue
  entirely. By default, entries for sections at or past `unlocked` get
  `.learnr2-toc-locked`, `aria-disabled`, `tabindex=-1`,
  `pointer-events: none`, and a `preventDefault()` for keyboard clicks.
  `tutorial_options(allow_skip = TRUE)` restores the old unlock-and-jump.
  Fixtures: `progressive-sections` and `progressive-sections-skip`.
- **Submission gate** (2026-10). `pendingWidgets()` counts unsubmitted
  `question()` and `student_info()` widgets *above* the current Continue
  button within its section; `refreshContinueGate()` re-runs after any
  submit, try-again or edit click. Fixture: `progressive-sections-gated`.
  Structural fixtures that click past unanswered widgets opt out with
  `require_submission: false`.
- **Start Over placement.** It used to go only into
  `#quarto-margin-sidebar`, so `toc: false` tutorials had none, and
  neither did any tutorial on a phone, where Quarto's CSS hides the sidebar
  below 768px. Now it goes in the sidebar only when it is actually showing
  (`getClientRects()`), otherwise right after `#title-block-header`, and a
  resize listener moves it. Fixtures: the `-no-toc` variants.
- **Edit/Submit cycle** (2026-10), for `student_info()` and
  `reflection_editable` only. Submit locks the fields and shows "Edit";
  Edit only reopens them, shows "Submit" and an editing note
  (`EDITING_NOTE`). Received means last submitted: `widgetPending()` (used
  by the Continue gate and the download) treats a reopened widget as
  unsubmitted, the download reads submitted values, never the live DOM,
  and is blocked until every `student_info()` is submitted. Info storage:
  flat keys are the submitted values, `draft` holds typing, `submitted`
  and `editing` are flags; old flat-keys-plus-`submitted: false` data is
  read as a draft. The old design left fields open after Submit and
  relabelled the button "Edit", which silently resaved, so readers had no
  signal their change had gone in (user report, 2026-10). Plain
  `reflection` never gets the cycle: reopening it would let a reader paste
  in the model answer.
- **Outbound links open in a new tab** (`openLinksInNewTabs()`): every
  `a[href]` except `#...`, `download`, `mailto:`/`tel:`/`javascript:`.
  Students worried when a tutorial "disappeared". Quarto's
  `link-external-newwindow` would miss same-site links.
- **Rendering a test copy of learnr2 changes needs an install.** Quarto
  runs a tutorial's R chunks in its own R process, which loads the
  *installed* learnr2, not a `load_all()` copy, so a render from a
  `load_all()` session still embeds the old `quiz.js`. Install the
  working tree into a scratch library (`R CMD INSTALL -l <dir> .`) and
  render with `R_LIBS=<dir>`, into a fresh output directory.
- **Pasted screenshots are shrunk** (2026-10), in `compressImage()`: at
  most 1600x4000 px, white background, WebP (JPEG where the canvas can't
  encode WebP, detected from the data URL), stepping quality then size
  down to fit ~450 KB. They used to be stored as full-size PNG, up to 3 MB
  each against a ~5 MB localStorage shared by the whole *site* (all of
  `127.0.0.1:7446`, all of `ppbds.github.io`). Input cap is 20 MB.
- **Failed saves are loud.** `saveState()` returns `false` and
  `reportStorageFailure()` shows a sticky page warning (full vs blocked
  storage); a reflection or `student_info()` whose submit couldn't be
  stored stays open rather than locking. Previously failures were
  swallowed, so a full storage meant an answer looked submitted but was
  missing from the download. Tests stub `Storage.prototype.setItem` to
  throw `QuotaExceededError`.
- **Image-paste answers.** Once an image is pasted, the textarea hides and
  typed text is not saved (`value` is `""`). A user reported the visible
  empty textarea above a pasted image as a second box to fill in. Don't
  bring it back.
- **Storage keys strip the URL hash** (`pageUrl` at the top of `quiz.js`).
  TOC clicks change the hash, and reading `location.href` fresh made Start
  Over and the download miss saved answers.
- **`window.confirm()` is never used.** VS Code's Simple Browser silently
  resolves it to `false`, which made Start Over look dead. Use the in-page
  `<dialog>` (`showConfirmDialog()`).

## Serving: `run_tutorial()` and `probe_server()`

- **The served root must not 404.** In a codespace, the port notification
  opens `/`, which held only `<package>/<name>/` subdirectories: a bare 404,
  while the server was fine. `write_root_index()` now writes a root page
  that forwards to the tutorial just launched and lists the rest. General
  rule: anything serving a directory on a port must answer `/` with
  something that reaches the content.
- **Codespaces addresses.** `public_tutorial_url()` builds the forwarded
  `https://<codespace>-<port>.<domain>/` address from `CODESPACE_NAME` and
  `GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN`, but `open_in_browser()` always
  opens the *local* address: VS Code forwards the port as part of opening a
  localhost link, while opening the forwarded address first hit the proxy
  before forwarding and showed a 404. It honours a `BROWSER` env var ahead
  of R's `browser` option, which is `xdg-open` with nothing to open in a
  container.
- **Never infer network state from error wording.** `probe_server()` once
  grepped a `url()` error for "refused" to mean "port free"; on Windows the
  wording differs and `run_tutorial()` refused to start. `port_listening()`
  is now a plain `socketConnection()` connect.
- **httpuv closes listeners asynchronously.** After `stopServer()` a port
  briefly still accepts connections that nothing answers, long enough on
  Windows to be misread as "something else holds the port".
  `probe_server()` re-checks that verdict (`attempts`, `wait`), and tests
  use `free_port()` (in `test-tutorials.R`), never
  `httpuv::randomPort()` directly. Found from the actual CI job log
  (`gh api repos/PPBDS/learnr2/actions/jobs/<id>/logs`) after a first fix
  based on guessing; get the log before fixing.

## Test suite

Two layers, both in CI (`R-CMD-check.yaml`, `js-tests.yaml`).

**R, `tests/testthat/` (edition 3).** One `test-*.R` per `R/*.R` file:
`test-question.R`, `test-submission.R`, `test-tutorials.R`,
`test-tutorial_options.R`, `test-extension.R`, `test-create-tutorial.R`,
`test-show_file.R`, `test-render-tutorials.R`, `test-check-tutorial.R`.

- Every exported function and internal helper has a test; call internals
  as `learnr2:::helper()`.
- Heavy calls are mocked with `local_mocked_bindings()`: `quarto`, `httpuv`,
  `utils`/`rstudioapi`, plus learnr2's own seams `probe_server()`,
  `open_in_browser()` and `block_serving()` (see `local_stub_serving()` and
  `local_stub_quarto()`). No test boots WebR, opens a browser, or hits the
  network.
- **One test serves for real**: the "served root, against a real httpuv
  server" block fetches `/` from a live httpuv server, because stubs can
  only show that `index.html` was written. It fails if
  `write_root_index()` is removed.
- **One test renders for real**: the last test in
  `test-render-tutorials.R` runs `check_tutorial()` and
  `render_tutorials()` over every bundled tutorial with real Quarto
  (`skip_on_cran()`, skipped without Quarto). `hello-learnr2` is checked
  with `skip = c("echo", "minutes")`, since the tour shows its widget
  source and has no minutes question.
- **`withr` is in Suggests**, and every test file using it starts with
  `testthat::skip_if_not_installed("withr")` for CRAN's no-Suggests check.
  Moving it to Imports instead gave a NOTE ("not imported from"), because
  no package code uses it.
- **Mocking gotcha:** learnr exports `available_tutorials()` and
  `run_tutorial()` under the same names, so mocking them in learnr also
  replaced learnr2's. Every learnr call goes through a distinctly named
  seam (`learnr_installed()`, `learnr_available_tutorials()`,
  `learnr_run_tutorial()`), and tests mock those.
- Deliberately untested: `live_extension_dir()`'s missing-package branch
  (needs a broken install) and `learnr_run_tutorial()` (launches Shiny).

**JS, `tests/js/` (Playwright).** `quiz.js` is covered end to end:
`quiz.spec.js` against a local fixture server (`server.js`, `fixtures.js`)
and `persistence.spec.js` across a real browser restart. Any fixture is
also served as `<name>-no-toc`, without a sidebar. The six image-paste
tests fail in local headless Chromium (clipboard) but pass in CI.

Run: `R -q -e 'devtools::test()'`, and `cd tests/js && npx playwright test`.

## GitHub Pages and the smoke test

`.github/workflows/tutorials.yaml` renders every bundled tutorial with
`tools/render_tutorials_for_pages.R` and pushes `_site/tutorials/` to the
`tutorials/` path of `gh-pages`, the branch pkgdown also publishes to. A
tutorial lands at
`https://ppbds.github.io/learnr2/tutorials/<name>/<name>.html`. The deploy
action uses `clean: false`, so a tutorial removed from the package stays on
the site until deleted from `gh-pages` by hand.

The `smoke-test` job then waits for the live page and runs
`tests/js/deployed-smoke.spec.js` against it: fill in known
`student_info()` values and two answers, download, and assert exactly those
come back. It avoids `{webr}` cells so WebR's boot time can't make it
flaky. It relies on `hello-learnr2` setting
`tutorial_options(require_submission = FALSE)`, since it clicks through
every Continue before answering.

- The wait loop greps the live page for `data-learnr2-question`, a
  structural marker. It used to grep for the title "Hello, learnr2" and
  failed for five minutes the day the title lost its comma, while the page
  was fine (2026-10-07). Smoke checks key on structure, never on prose.
- `playwright.smoke.config.js` includes the `html` reporter, so the
  failure artifact the workflow uploads actually exists.

Run locally: `cd tests/js && SMOKE_URL="<url>" npm run test:smoke`.

## CRAN

- **Bundled code.** quarto-live and the libraries compiled into its
  minified bundles are listed in `inst/COPYRIGHTS` (copyright holders,
  licenses, upstream URLs), referenced from the DESCRIPTION `Copyright`
  field, with a license table in `LICENSE.note`. Their authors are *not*
  in `Authors@R`: CRAN policy allows the `Copyright` field instead, and
  listing them would make them package authors. A check of the bundle
  (2026-10) found three undisclosed components (webR's JavaScript client,
  ansi-to-html, entities): they had been missed because quarto-live lists
  them as build-time dependencies. When updating the extension, re-check
  what the bundles contain, not just `package.json`'s runtime dependencies.
  No GPL code may be bundled: webR's GPL-3 worker and binaries are fetched
  from its CDN at view time and must stay that way.
- **Example timing.** CRAN's check machines are several times slower than a
  laptop: rendering `hello-learnr2` took 1.7 s locally and about 5 s on
  CRAN, which flags examples over 5 s on some machines and 10 s on others.
  Examples that render a full tutorial are wrapped in `if (interactive() &&
  !is.null(quarto::quarto_path()))`. Only `render_tutorials()`'s example,
  which renders a minimal scaffold, runs on CRAN. Time examples on
  win-builder, not locally.
- **`\dontrun{}`** is used once, for the blocking server launch in
  `run_tutorial()`. Keep `cran-comments.md` in step with any change to
  examples or bundled code: it has twice described things that were no
  longer true.
