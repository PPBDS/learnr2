## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Notes for CRAN reviewers

* The only example wrapped in `\dontrun{}` is `run_tutorial("hello-learnr2")`.
  It needs the Quarto command line tool (listed in `SystemRequirements`),
  which is not available on CRAN's check machines, and with `open = TRUE` it
  starts a local web server that blocks the session until interrupted, so it
  genuinely cannot run inside a check. The `run_tutorial()` example that can
  run (listing the available tutorials) is not wrapped.
* `run_tutorial()` renders into `tools::R_user_dir("learnr2", "cache")` by
  default, as the CRAN policy permits for R >= 4.0. Examples and tests only
  ever write to the session's temporary directory.
* The package bundles the 'quarto-live' Quarto extension (MIT) under
  `inst/extdata/_extensions/`, including two minified JavaScript bundles
  built by that project from its TypeScript sources. Each component, its
  copyright holder and license, and where the unminified sources live are
  listed in `inst/COPYRIGHTS`, referenced from the `Copyright` field.
* There is no published reference describing the methods in this package,
  so none is cited in the `Description` field.
