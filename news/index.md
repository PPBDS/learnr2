# Changelog

## learnr2 0.1.0

- Printing a
  [`question()`](https://ppbds.github.io/learnr2/reference/question.md),
  [`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md),
  [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md),
  or
  [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
  at the console now opens a browser preview only in an interactive
  session; non-interactive prints (scripts, `R CMD check`) emit the HTML
  source instead of launching the system browser.

## learnr2 0.0.0

We hope to replace both **learnr** and **tutorial.helpers** with
**learnr2**. There is no reason to have two packages, or to not have
**learnr2** do everything we want a tutorial package to do.

Create interactive R tutorials that run entirely in the browser using
‘Quarto’ and ‘WebR’ via the ‘quarto-live’ extension.
