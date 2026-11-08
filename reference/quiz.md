# Group questions into a quiz

Group questions into a quiz

## Usage

``` r
quiz(..., caption = NULL)
```

## Arguments

- ...:

  One or more
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  objects.

- caption:

  Heading shown above the questions. `NULL`, the default, means the page
  language's "Quiz" (see the "Language" section of
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md)).

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
#>   <div class="learnr2-question" data-learnr2-question="eyJpZCI6IndoYXQtaXMtMi0yIiwidGV4dCI6IldoYXQgaXMgMiArIDI/IiwidHlwZSI6InNp&#10;bmdsZSIsImFuc3dlcnMiOlt7InRleHQiOiI0IiwiY29ycmVjdCI6dHJ1ZSwibWVzc2FnZSI6&#10;bnVsbH0seyJ0ZXh0IjoiMjIiLCJjb3JyZWN0IjpmYWxzZSwibWVzc2FnZSI6bnVsbH1dLCJj&#10;b3JyZWN0TWVzc2FnZSI6bnVsbCwiaW5jb3JyZWN0TWVzc2FnZSI6bnVsbCwiYWxsb3dSZXRy&#10;eSI6ZmFsc2UsInJhbmRvbUFuc3dlck9yZGVyIjpmYWxzZSwic3VibWl0TGFiZWwiOm51bGws&#10;InRyeUFnYWluTGFiZWwiOm51bGwsImVkaXRMYWJlbCI6bnVsbCwiYWxsb3dJbWFnZSI6ZmFs&#10;c2UsImFsbG93VGV4dCI6dHJ1ZSwic2hvd1RleHQiOnRydWUsInZhbGlkYXRlIjoibm9uZSJ9&#10;">
#>     <noscript>This quiz question requires JavaScript.</noscript>
#>   </div>
#> </div>
```
