## Resubmission

This is a resubmission. In this version I have:

* Removed the default `dir = "."` from the two functions that write files,
  `create_tutorial()` and `add_live_extension()`. `dir` is now a required
  argument, so neither writes anywhere the user did not name. Examples and
  tests write only under `tempdir()`; I verified by running the full test
  suite in a clean checkout and diffing the package directory and the home
  directory before and after (no new files).
* Replaced the one call to `utils::installed.packages()` (in
  `available_tutorials()` with no `package`) with a scan of the libraries on
  `.libPaths()` for a `tutorials/` directory, one `file.exists()` per
  package directory.
* `run_tutorial()` still caches rendered tutorials under
  `tools::R_user_dir("learnr2", "cache")`, as the CRAN policy permits for
  R >= 4.0 ("packages may store user-specific data, configuration and cache
  files in their respective user directories obtained from
  tools::R_user_dir()"). The package now declares `Depends: R (>= 4.0.0)`
  accordingly. The cache holds about 3.5 MB per tutorial, is replaced
  whenever the tutorial or learnr2 changes, and `refresh = TRUE` rebuilds
  it from empty.

In the previous resubmission I had:

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

* `\dontrun{}` is used once, in `run_tutorial()`, for
  `run_tutorial("hello-learnr2")` with the default `open = TRUE`: it starts a
  local web server that blocks until interrupted. The rendering examples for
  `run_tutorial()`, `prerender_tutorials()` and `render_tutorials()` run
  whenever the Quarto command line tool (see `SystemRequirements`) is
  installed, writing only under `tempdir()`.
* The package bundles the 'quarto-live' Quarto extension (MIT) under
  `inst/extdata/`, including minified JavaScript built by that project from
  its TypeScript sources. Its license file is kept in the bundled directory;
  `LICENSE.note` lists the license of each component (MIT, BSD-3-Clause,
  Apache-2.0, MPL-2.0); `inst/COPYRIGHTS` gives copyright holders, upstream
  URLs, and where the unminified sources are, and is referenced from the
  `Copyright` field of DESCRIPTION, as the CRAN policy allows.
* `run_tutorial()` writes rendered output to
  `tools::R_user_dir("learnr2", "cache")`, as permitted by the CRAN policy.
* There is no published reference describing the methods in this package.
