#' Check every tutorial in a package
#'
#' The one call a content package's tests need. Finds every tutorial the
#' package ships (with [available_tutorials()], so a package loaded with
#' `pkgload::load_all()` is checked from its source tree), runs
#' [check_tutorial()]'s static checks on each, renders each with
#' [render_tutorials()], and checks the rendered page: that its download
#' file will say which package, version and tutorial it is a submission
#' for (see [download_answers_button()]). Problems from every stage come
#' back in one data frame, and by default the function stops if any is an
#' error.
#'
#' @param package Name of the package whose tutorials to check. `NULL`, the
#'   default, checks every installed package that has tutorials, plus any
#'   loaded with `pkgload::load_all()`; a content package's own test passes
#'   its name.
#' @param render Render each tutorial too? `TRUE` by default. Rendering
#'   needs the Quarto command line tool and takes a few seconds per
#'   tutorial; pass `!is.null(quarto::quarto_path())` to skip it where
#'   Quarto is missing.
#' @param skip Check names to leave out, as for [check_tutorial()]. Two more
#'   names apply here: `"render"` (the render itself) and `"submission"`
#'   (the rendered page's download header).
#' @param output_dir Where to render, as for [render_tutorials()].
#' @param quiet Passed to [render_tutorials()].
#' @param error If `TRUE` (the default), stop listing every error-level
#'   problem, after a warning for the warning-level ones. If `FALSE`, just
#'   return them.
#'
#' @return A data frame of problems with columns `path`, `check`,
#'   `severity` and `message`, invisibly; zero rows when everything passed.
#' @export
#' @section In a content package's tests:
#' ```r
#' test_that("every tutorial passes learnr2's checks", {
#'   skip_on_cran()
#'   expect_no_error(learnr2::check_tutorials(
#'     "my.tutorials", render = !is.null(quarto::quarto_path())
#'   ))
#' })
#' ```
#' @examples
#' # learnr2's own tutorials, static checks only (rendering needs Quarto).
#' problems <- check_tutorials("learnr2", render = FALSE, error = FALSE)
#' problems[, c("check", "message")]
check_tutorials <- function(package = NULL, render = TRUE, skip = NULL,
                            output_dir = tempfile("learnr2-check-"), quiet = TRUE,
                            error = TRUE) {
  extra_checks <- c("render", "submission")
  static_skip <- setdiff(skip, extra_checks)
  tutorials <- available_tutorials(package = package)
  if (nrow(tutorials) == 0) {
    stop("No learnr2 tutorials found",
         if (!is.null(package)) paste0(" in package `", package, "`"), ".", call. = FALSE)
  }

  problems <- check_tutorial(tutorials$path, skip = static_skip, error = FALSE)

  if (isTRUE(render) && !"render" %in% skip) {
    for (i in seq_len(nrow(tutorials))) {
      path <- tutorials$path[i]
      html <- tryCatch(
        render_tutorials(path, output_dir = output_dir, quiet = quiet)[[1]],
        error = function(e) e
      )
      if (inherits(html, "error")) {
        problems <- rbind(problems, data.frame(
          path = path, check = "render", severity = "error",
          message = conditionMessage(html), stringsAsFactors = FALSE
        ))
        next
      }
      if (!"submission" %in% skip) {
        msgs <- check_download_header(html, tutorials[i, ])
        if (length(msgs) > 0) {
          problems <- rbind(problems, data.frame(
            path = path, check = "submission", severity = "error",
            message = msgs, stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
  report_problems(problems, error)
}

# The rendered page's download button must say what a download from it is a
# submission for: this package, this tutorial, this version.
check_download_header <- function(html, tutorial) {
  page <- paste(readLines(html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(page, regexec("data-learnr2-download=\"([^\"]+)\"", page))[[1]]
  if (length(m) < 2) {
    return("rendered page has no download button, so a download from it names no package or tutorial.")
  }
  payload <- tryCatch(
    jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(m[2])), simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(payload)) {
    return("the download button's payload could not be decoded.")
  }
  expected <- list(
    package = tutorial$package,
    version = tutorial_identity(tutorial$path)$version,
    tutorial = tutorial$name
  )
  msgs <- character(0)
  for (key in names(expected)) {
    if (!identical(payload[[key]], expected[[key]])) {
      msgs <- c(msgs, paste0("download header `", key, "` is ",
                             if (is.null(payload[[key]])) "missing" else paste0("`", payload[[key]], "`"),
                             ", expected `", expected[[key]], "`."))
    }
  }
  msgs
}
