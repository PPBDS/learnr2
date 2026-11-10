# Check every tutorial in a package

The one call a content package's tests need. Finds every tutorial the
package ships (with
[`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md),
so a package loaded with
[`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
is checked from its source tree), runs
[`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)'s
static checks on each, renders each with
[`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md),
and checks the rendered page: that its download file will say which
package, version and tutorial it is a submission for (see
[`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)).
Problems from every stage come back in one data frame, and by default
the function stops if any is an error.

## Usage

``` r
check_tutorials(
  package = NULL,
  render = TRUE,
  skip = NULL,
  output_dir = tempfile("learnr2-check-"),
  quiet = TRUE,
  error = TRUE
)
```

## Arguments

- package:

  Name of the package whose tutorials to check. `NULL`, the default,
  checks every installed package that has tutorials, plus any loaded
  with
  [`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html);
  a content package's own test passes its name.

- render:

  Render each tutorial too? `TRUE` by default. Rendering needs the
  Quarto command line tool and takes a few seconds per tutorial; pass
  `!is.null(quarto::quarto_path())` to skip it where Quarto is missing.

- skip:

  Check names to leave out, as for
  [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md).
  Two more names apply here: `"render"` (the render itself) and
  `"submission"` (the rendered page's download header).

- output_dir:

  Where to render, as for
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md).

- quiet:

  Passed to
  [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md).

- error:

  If `TRUE` (the default), stop listing every error-level problem, after
  a warning for the warning-level ones. If `FALSE`, just return them.

## Value

A data frame of problems with columns `path`, `check`, `severity` and
`message`, invisibly; zero rows when everything passed.

## In a content package's tests

    test_that("every tutorial passes learnr2's checks", {
      skip_on_cran()
      expect_no_error(learnr2::check_tutorials(
        "my.tutorials", render = !is.null(quarto::quarto_path())
      ))
    })

## Examples

``` r
# learnr2's own tutorials, static checks only (rendering needs Quarto).
problems <- check_tutorials("learnr2", render = FALSE, error = FALSE)
problems[, c("check", "message")]
#>       check
#> 1   minutes
#> 2      echo
#> 3      echo
#> 4      echo
#> 5      echo
#> 6      echo
#> 7      echo
#> 8      echo
#> 9      echo
#> 10     echo
#> 11     echo
#> 12     echo
#> 13     echo
#> 14     echo
#> 15   fences
#> 16 mentions
#>                                                                                                                                            message
#> 1                                                             No "how many minutes" question: a `learnr2::question()` with `validate = "integer"`.
#> 2                                                                                line 168 (quiz-questions-1): widget chunk needs `#| echo: false`.
#> 3                                                                                line 182 (quiz-questions-2): widget chunk needs `#| echo: false`.
#> 4                                                                                line 196 (quiz-questions-3): widget chunk needs `#| echo: false`.
#> 5                                                                                line 212 (quiz-questions-4): widget chunk needs `#| echo: false`.
#> 6                                                                                line 235 (quiz-questions-5): widget chunk needs `#| echo: false`.
#> 7                                                                                line 260 (quiz-questions-7): widget chunk needs `#| echo: false`.
#> 8                                                                                line 278 (quiz-questions-6): widget chunk needs `#| echo: false`.
#> 9                                                                           line 319 (copy-paste-an-image-2): widget chunk needs `#| echo: false`.
#> 10                                                                          line 344 (copy-paste-an-image-3): widget chunk needs `#| echo: false`.
#> 11                                                                            line 381 (record-your-voice-1): widget chunk needs `#| echo: false`.
#> 12                                                                  line 413 (student-info-and-submission-1): widget chunk needs `#| echo: false`.
#> 13                                                                  line 438 (student-info-and-submission-2): widget chunk needs `#| echo: false`.
#> 14                                                                               line 478 (layout-options-1): widget chunk needs `#| echo: false`.
#> 15                 1 code block(s) with no language (line 648): tag what the reader types as ```bash or ```r, and expected output as ```{.output}.
#> 16 prose mentions learnr or tutorial.helpers (lines 160, 498, 507, 537, 652): students should never hear of either; see `vignette("translating")`.
```
