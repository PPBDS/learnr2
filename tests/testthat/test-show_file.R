# Covers R/show_file.R: show_file(), strip_pagedtable_html(). Ported, with
# the fixtures/show_file_* files, from tutorial.helpers.

# Test file path using testthat::test_path()
# This automatically finds the file relative to the test directory
# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

test_file <- test_path("fixtures", "show_file_test.txt")
test_file_yaml <- test_path("fixtures", "show_file_yaml_test.qmd")
test_file_python <- test_path("fixtures", "show_file_python_test.qmd")

# Test cases
test_that("show_file function works correctly", {
  # Test case 1: Display all rows (chunk = "None"; the "auto" default would
  # show only the last code chunk of this file -- see the learnr2 tests below)
  expect_equal(paste(capture.output(show_file(test_file, chunk = "None")), collapse = "\n"),
               paste(c(
                 "This is line 1.",
                 "This is line 2.",
                 "This is line 3 with the word example.",
                 "```{r}",
                 "# This is a code chunk",
                 "",
                 "x <- 1:10",
                 "print(x)",
                 "```",
                 "This is line 4.",
                 "This is line 5 with another example.",
                 "```{r}",
                 "# Another code chunk",
                 "y <- 20:30",
                 "mean(y)",
                 "```",
                 "This is line 6.",
                 "This is line 7.",
                 "This is line 8.",
                 "This is line 9.",
                 "This is line 10.",
                 "",
                 "This is line 11 with no matching pattern."
               ), collapse = "\n"))
  
  # Test case 2: Display entire file with start = 0
  expect_equal(paste(capture.output(show_file(test_file, start = 0)), collapse = "\n"),
               paste(c(
                 "This is line 1.",
                 "This is line 2.",
                 "This is line 3 with the word example.",
                 "```{r}",
                 "# This is a code chunk",
                 "",
                 "x <- 1:10",
                 "print(x)",
                 "```",
                 "This is line 4.",
                 "This is line 5 with another example.",
                 "```{r}",
                 "# Another code chunk",
                 "y <- 20:30",
                 "mean(y)",
                 "```",
                 "This is line 6.",
                 "This is line 7.",
                 "This is line 8.",
                 "This is line 9.",
                 "This is line 10.",
                 "",
                 "This is line 11 with no matching pattern."
               ), collapse = "\n"))
  
  # Test case 3: Display rows 3 to 7
  expect_equal(paste(capture.output(show_file(test_file, start = 3, end = 7)), collapse = "\n"),
               paste(c(
                 "This is line 3 with the word example.",
                 "```{r}",
                 "# This is a code chunk",
                 "",
                 "x <- 1:10"
               ), collapse = "\n"))
  
  # Test case 4: Display rows matching the pattern "example"
  expect_equal(paste(capture.output(show_file(test_file, pattern = "example")), collapse = "\n"),
               paste(c(
                 "This is line 3 with the word example.",
                 "This is line 5 with another example."
               ), collapse = "\n"))
  
  # Test case 5: Print all code chunks
  expect_equal(paste(capture.output(show_file(test_file, chunk = "All")), collapse = "\n"),
               paste(c(
                 "# This is a code chunk",
                 "",
                 "x <- 1:10",
                 "print(x)",
                 "",
                 "# Another code chunk",
                 "y <- 20:30",
                 "mean(y)"
               ), collapse = "\n"))
  
  # Test case 6: Print the last code chunk
  expect_equal(paste(capture.output(show_file(test_file, chunk = "Last")), collapse = "\n"),
               paste(c(
                 "# Another code chunk",
                 "y <- 20:30",
                 "mean(y)"
               ), collapse = "\n"))
  
  # Test case 7: Invalid chunk value (numeric)
  expect_error(show_file(test_file, chunk = 1),
               "`chunk` must be a single string")

  # Test case 8: An unrecognized string is taken as a chunk label, so a
  # typo errors as "no such chunk" rather than being silently accepted
  expect_error(show_file(test_file, chunk = "invalid"),
               'No code chunk labelled "invalid" found')
  
  # Test case 9: Extract YAML header (assuming test_file_yaml has proper YAML)

  expect_equal(paste(capture.output(show_file(test_file_yaml, chunk = "YAML")), collapse = "\n"),
               paste(c(
                 'title: "Test Document"',
                 'author: "Test Author"',
                 'date: "2024-01-01"'
               ), collapse = "\n"))
  
  # Test case 10: No YAML header found
  expect_error(show_file(test_file, chunk = "YAML"), 
               "No YAML header found.")
  
  # Test case 11: File does not exist
  expect_error(show_file("nonexistent_file.txt"), "File does not exist.")
  
  # Test case 12: Start is greater than end
  expect_error(show_file(test_file, start = 5, end = 3), "start must be smaller or equal to end.")
  
  # Test case 13: End is out of range
  expect_error(show_file(test_file, end = 30), "start and end must be within the valid range of rows.")
  
  # Test case 14: Print the last 3 lines of the file
  expect_equal(paste(capture.output(show_file(test_file, start = -3)), collapse = "\n"),
               paste(c(
                 "This is line 10.",
                 "",
                 "This is line 11 with no matching pattern."
               ), collapse = "\n"))
  
  # Test case 15: No rows matching the pattern
  expect_equal(paste(capture.output(show_file(test_file, pattern = "nomatch")), collapse = "\n"), "")

  # Test case 16: Empty file prints "File is empty."
  empty_file <- tempfile()
  file.create(empty_file)
  on.exit(unlink(empty_file), add = TRUE)
  expect_equal(paste(capture.output(show_file(empty_file)), collapse = "\n"),
               "File is empty.")

  # Test case 17: A file containing only blank lines prints "File is empty."
  blank_file <- tempfile()
  writeLines(c("", "", ""), blank_file)
  on.exit(unlink(blank_file), add = TRUE)
  expect_equal(paste(capture.output(show_file(blank_file)), collapse = "\n"),
               "File is empty.")

  # Test case 18: chunk = "None" shows the whole file, same as start = 0
  expect_equal(paste(capture.output(show_file(test_file, chunk = "None")), collapse = "\n"),
               paste(capture.output(show_file(test_file, start = 0)), collapse = "\n"))

  # Test case 19: pattern combined with a row range
  expect_equal(paste(capture.output(show_file(test_file, start = 1, end = 5, pattern = "example")), collapse = "\n"),
               paste(c(
                 "This is line 3 with the word example."
               ), collapse = "\n"))

  # Test case 20: pattern combined with start = 0 (whole file) -- Bug #1
  expect_equal(paste(capture.output(show_file(test_file, start = 0, pattern = "example")), collapse = "\n"),
               paste(c(
                 "This is line 3 with the word example.",
                 "This is line 5 with another example."
               ), collapse = "\n"))

  # Test case 21: pattern combined with a negative start -- Bug #1
  expect_equal(paste(capture.output(show_file(test_file, start = -5, pattern = "matching")), collapse = "\n"),
               paste(c(
                 "This is line 11 with no matching pattern."
               ), collapse = "\n"))

  # Test case 22: negative start larger than the file returns all lines
  expect_equal(paste(capture.output(show_file(test_file, start = -100)), collapse = "\n"),
               paste(capture.output(show_file(test_file, start = 0)), collapse = "\n"))

  # Test case 23: chunk = "Last" on a qmd with named R chunks
  expect_equal(paste(capture.output(show_file(test_file_yaml, chunk = "Last")), collapse = "\n"),
               paste(c(
                 "x <- 1:10",
                 "mean(x)"
               ), collapse = "\n"))

  # Test case 24: chunk = "All" on a qmd with named R chunks
  expect_equal(paste(capture.output(show_file(test_file_yaml, chunk = "All")), collapse = "\n"),
               paste(c(
                 "library(tidyverse)",
                 "",
                 "x <- 1:10",
                 "mean(x)"
               ), collapse = "\n"))

  # Test case 25: chunk = "Last" works on Python chunks
  expect_equal(paste(capture.output(show_file(test_file_python, chunk = "Last")), collapse = "\n"),
               paste(c(
                 'df = pd.DataFrame({"x": [1, 2, 3]})',
                 "df.head()"
               ), collapse = "\n"))

  # Test case 26: chunk = "All" captures all Python chunks
  expect_equal(paste(capture.output(show_file(test_file_python, chunk = "All")), collapse = "\n"),
               paste(c(
                 "import pandas as pd",
                 "",
                 'df = pd.DataFrame({"x": [1, 2, 3]})',
                 "df.head()"
               ), collapse = "\n"))

  # Test case 27: single-line file with no YAML errors cleanly -- Bug #2
  one_line_file <- tempfile(fileext = ".txt")
  writeLines("only one line", one_line_file)
  on.exit(unlink(one_line_file), add = TRUE)
  expect_error(show_file(one_line_file, chunk = "YAML"), "No YAML header found.")

  # Test case 28: chunk = "Last" strips embedded pagedtable HTML that VS
  # Code's interactive chunk execution can cache back into a .qmd file
  test_file_pagedtable <- test_path("fixtures", "show_file_pagedtable_test.qmd")
  expect_equal(paste(capture.output(show_file(test_file_pagedtable, chunk = "Last")), collapse = "\n"),
               "penguins")

  # Test case 29: chunk = "All" strips pagedtable HTML from every chunk
  expect_equal(paste(capture.output(show_file(test_file_pagedtable, chunk = "All")), collapse = "\n"),
               paste(c(
                 "library(tidyverse)",
                 "",
                 "penguins"
               ), collapse = "\n"))

  # Test case 30: pagedtable HTML is stripped even outside chunk mode
  expect_false(grepl("pagedtable",
                      paste(capture.output(show_file(test_file_pagedtable, start = 0)), collapse = "\n")))

  # Test case 31: nested <div> tags inside the pagedtable JSON payload do
  # not confuse the stripping logic
  nested_div_file <- tempfile(fileext = ".qmd")
  writeLines(c(
    "```{r}",
    "df",
    '<div data-pagedtable="false">',
    '  <script data-pagedtable-source type="application/json">',
    '{"data":[["<div>nested</div>"]]}',
    "  </script>",
    "</div>",
    "```"
  ), nested_div_file)
  on.exit(unlink(nested_div_file), add = TRUE)
  expect_equal(paste(capture.output(show_file(nested_div_file, chunk = "Last")), collapse = "\n"),
               "df")

  # Test case 32: learnr2:::strip_pagedtable_html() is a no-op on ordinary lines
  expect_equal(learnr2:::strip_pagedtable_html(c("a <- 1", "b <- 2")), c("a <- 1", "b <- 2"))

  # Test case 33: learnr2:::strip_pagedtable_html() handles an empty vector
  expect_equal(learnr2:::strip_pagedtable_html(character(0)), character(0))
})

# Regression test: a closing fence with trailing whitespace used to go
# unrecognized, so following prose leaked into the chunk output.

test_that("closing fences with trailing whitespace are recognized", {
  f <- tempfile(fileext = ".Rmd")
  on.exit(unlink(f))
  writeLines(c("```{r}", "x <- 1", "``` ", "Some prose."), f)
  out <- capture.output(show_file(f, chunk = "Last"))
  expect_equal(out, "x <- 1")
})

# ---- learnr2 additions: the "auto" default and chunk-by-label ----------------

test_that("the default (chunk = \"auto\") shows the last code chunk of a file that has chunks", {
  expect_equal(capture.output(show_file(test_file)),
               capture.output(show_file(test_file, chunk = "Last")))
  expect_equal(capture.output(show_file(test_file)),
               c("# Another code chunk", "y <- 20:30", "mean(y)"))
  expect_equal(capture.output(show_file(test_file_python)),
               c('df = pd.DataFrame({"x": [1, 2, 3]})', "df.head()"))
})

test_that("the default shows a chunk-free file whole", {
  f <- withr::local_tempfile(fileext = ".gitignore")
  writeLines(c(".Rproj.user", ".Rhistory", "*.html"), f)
  expect_equal(capture.output(show_file(f)), c(".Rproj.user", ".Rhistory", "*.html"))
  # Indented or inline backticks are prose, not fences, so still "no chunks".
  g <- withr::local_tempfile(fileext = ".md")
  writeLines(c("Use `x <- 1`.", "  ```{r}", "not a chunk"), g)
  expect_equal(capture.output(show_file(g)), c("Use `x <- 1`.", "  ```{r}", "not a chunk"))
})

test_that("supplying start, end, or pattern switches the auto default off", {
  expect_equal(capture.output(show_file(test_file, end = 3)),
               c("This is line 1.", "This is line 2.", "This is line 3 with the word example."))
  expect_equal(capture.output(show_file(test_file, start = 1)),
               capture.output(show_file(test_file, chunk = "None")))
  expect_equal(capture.output(show_file(test_file, pattern = "example")),
               c("This is line 3 with the word example.", "This is line 5 with another example."))
  expect_equal(capture.output(show_file(test_file, start = -2)),
               c("", "This is line 11 with no matching pattern."))
})

test_that("auto is explicit-argument aware, not default-value aware", {
  # Passing the default value *explicitly* still counts as asking for rows.
  expect_equal(capture.output(show_file(test_file, start = 1, end = NULL)),
               capture.output(show_file(test_file, chunk = "None")))
})

test_that("chunk = \"<label>\" finds a chunk by label in every label syntax", {
  f <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c(
    "---", "title: x", "---",
    "```{r setup}",
    "library(dplyr)",
    "```",
    "```{r fit, echo = FALSE, message=FALSE}",
    "fit <- lm(y ~ x)",
    "```",
    "```{r, label = \"plot\"}",
    "plot(fit)",
    "```",
    "```{r label='tidy', eval=FALSE}",
    "broom::tidy(fit)",
    "```",
    "```{python}",
    "#| label: py-summary",
    "#| echo: false",
    "df.describe()",
    "```",
    "```{r}",
    "unlabelled <- TRUE",
    "```"
  ), f)
  expect_equal(capture.output(show_file(f, chunk = "setup")), "library(dplyr)")
  expect_equal(capture.output(show_file(f, chunk = "fit")), "fit <- lm(y ~ x)")
  expect_equal(capture.output(show_file(f, chunk = "plot")), "plot(fit)")
  expect_equal(capture.output(show_file(f, chunk = "tidy")), "broom::tidy(fit)")
  # The #| label line is part of the chunk's source and is shown with it.
  expect_equal(capture.output(show_file(f, chunk = "py-summary")),
               c("#| label: py-summary", "#| echo: false", "df.describe()"))
  # Label lookup is case-sensitive and exact.
  expect_error(show_file(f, chunk = "Setup"), 'No code chunk labelled "Setup" found')
  expect_error(show_file(f, chunk = "fi"), 'No code chunk labelled "fi" found')
  # Keyword modes are unaffected by labels being present.
  expect_equal(capture.output(show_file(f, chunk = "Last")), "unlabelled <- TRUE")
  expect_equal(capture.output(show_file(f)), "unlabelled <- TRUE")
})

test_that("chunk-by-label on a file with no chunks, or an empty chunk, behaves sensibly", {
  f <- withr::local_tempfile(fileext = ".txt")
  writeLines("just prose", f)
  expect_error(show_file(f, chunk = "setup"), 'No code chunk labelled "setup" found')
  # An empty labelled chunk is dropped, same as tutorial.helpers did for All/Last.
  g <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("```{r empty}", "```", "```{r real}", "1 + 1", "```"), g)
  expect_error(show_file(g, chunk = "empty"), 'No code chunk labelled "empty" found')
  expect_equal(capture.output(show_file(g, chunk = "real")), "1 + 1")
})

test_that("chunk must be a single non-empty string", {
  expect_error(show_file(test_file, chunk = c("All", "Last")), "`chunk` must be a single string")
  expect_error(show_file(test_file, chunk = NA_character_), "`chunk` must be a single string")
  expect_error(show_file(test_file, chunk = ""), "`chunk` must be a single string")
  expect_error(show_file(test_file, chunk = NULL), "`chunk` must be a single string")
})

test_that("fence_label() parses the header forms show_file() documents", {
  fl <- learnr2:::fence_label
  expect_equal(fl("```{r}"), "")
  expect_equal(fl("```{r setup}"), "setup")
  expect_equal(fl("```{r setup, echo=FALSE}"), "setup")
  expect_equal(fl("```{r, echo=FALSE}"), "")
  expect_equal(fl("```{r echo=FALSE}"), "")
  expect_equal(fl("```{r, label = \"x-1\"}"), "x-1")
  expect_equal(fl("```{r label='x_2'}"), "x_2")
  expect_equal(fl("```{r echo=FALSE, label=x3}"), "x3")
  expect_equal(fl("```{python plot}"), "plot")
  expect_equal(fl("```{bash}"), "")
})
