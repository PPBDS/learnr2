## Resubmission

This is a resubmission. In this version I have:

* Fixed the "detritus in the temp directory" NOTE from the previous
  submission (leftover `calibre-*` directories). The console print methods
  for `question()`, `quiz()`, `student_info()`, and
  `download_answers_button()` were opening a browser preview even in a
  non-interactive session, which on the check machine launched the system
  HTML handler. They now do so only when `interactive()` is `TRUE`, and print
  the HTML source otherwise. Examples and tests no longer touch the browser
  or leave anything outside the session temporary directory.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Additional notes

* `\dontrun{}` is used for a single example, `run_tutorial("hello-learnr2")`,
  which requires the Quarto command line tool (see `SystemRequirements`) and,
  with `open = TRUE`, starts a local web server that blocks until interrupted.
  The other `run_tutorial()` example runs normally.
* The package bundles the 'quarto-live' Quarto extension (MIT) under
  `inst/extdata/`, including minified JavaScript built by that project from
  its TypeScript sources. Its license file is kept in the bundled directory;
  `LICENSE.note` lists the license of each component (MIT, BSD-3-Clause,
  Apache-2.0, MPL-2.0); `inst/COPYRIGHTS` gives copyright holders, upstream
  URLs, and where the unminified sources are; and the copyright holders are
  listed with `cph` roles in `Authors@R`.
* `run_tutorial()` writes rendered output to
  `tools::R_user_dir("learnr2", "cache")`, as permitted by the CRAN policy.
* There is no published reference describing the methods in this package.
