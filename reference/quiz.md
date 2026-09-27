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
#> <div class="learnr2-quiz">
#>   <div class="learnr2-quiz-caption">Arithmetic</div>
#>   <div class="learnr2-question" data-learnr2-question="eyJpZCI6IndoYXQtaXMtMi0yIiwidGV4dCI6IldoYXQgaXMgMiArIDI/IiwidHlwZSI6InNp&#10;bmdsZSIsImFuc3dlcnMiOlt7InRleHQiOiI0IiwiY29ycmVjdCI6dHJ1ZSwibWVzc2FnZSI6&#10;bnVsbH0seyJ0ZXh0IjoiMjIiLCJjb3JyZWN0IjpmYWxzZSwibWVzc2FnZSI6bnVsbH1dLCJj&#10;b3JyZWN0TWVzc2FnZSI6IkNvcnJlY3QhIiwiaW5jb3JyZWN0TWVzc2FnZSI6IkluY29ycmVj&#10;dC4iLCJhbGxvd1JldHJ5IjpmYWxzZSwicmFuZG9tQW5zd2VyT3JkZXIiOmZhbHNlLCJzdWJt&#10;aXRMYWJlbCI6IlN1Ym1pdCBBbnN3ZXIiLCJ0cnlBZ2FpbkxhYmVsIjoiVHJ5IEFnYWluIiwi&#10;ZWRpdExhYmVsIjoiRWRpdCBBbnN3ZXIiLCJhbGxvd0ltYWdlIjpmYWxzZSwidmFsaWRhdGUi&#10;OiJub25lIn0=">
#>     <noscript>This quiz question requires JavaScript.</noscript>
#>   </div>
#> </div>
```
