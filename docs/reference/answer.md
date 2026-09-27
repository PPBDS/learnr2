# Define an answer choice for a quiz question

Define an answer choice for a quiz question

## Usage

``` r
answer(text, correct = FALSE, message = NULL)
```

## Arguments

- text:

  The answer text shown to the reader. For `type = "text"` questions
  (see
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md)),
  this is instead one acceptable response that the reader's typed input
  is compared against. For `"reflection"` and `"reflection_editable"`
  questions, the `text` of every `correct` answer is shown to the reader
  as the model answer – it is not compared against anything.

- correct:

  Is this a correct answer? Defaults to `FALSE`. For
  `"reflection"`/`"reflection_editable"` questions, this instead marks
  `text` as one of the model answers to reveal.

- message:

  Optional feedback shown when the reader picks (or types) this specific
  answer. Unused for `"reflection"`/`"reflection_editable"` questions.

## Value

A `learnr2_answer` object for use inside
[`question()`](https://ppbds.github.io/learnr2/reference/question.md).

## Examples

``` r
answer("4", correct = TRUE)
#> <answer: "4" [correct]>
answer("3", message = "Close, but check your arithmetic.")
#> <answer: "3">
```
