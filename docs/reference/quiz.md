# Group questions into a quiz

Group questions into a quiz

## Usage

``` r
quiz(..., caption = "Quiz")
```

## Arguments

- ...:

  One or more
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  objects.

- caption:

  Heading shown above the questions.

## Value

A `learnr2_quiz` object, printed as a set of interactive widgets.

## Examples

``` r
quiz(
  caption = "Arithmetic",
  question(
    "What is 2 + 2?",
    answer("4", correct = TRUE),
    answer("22")
  )
)
```
