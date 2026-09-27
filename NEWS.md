# learnr2 0.1.0

* Printing a `question()`, `quiz()`, `student_info()`, or
  `download_answers_button()` at the console now opens a browser preview only
  in an interactive session; non-interactive prints (scripts, `R CMD check`)
  emit the HTML source instead of launching the system browser.

# learnr2 0.0.0

We hope to replace both **learnr** and **tutorial.helpers** with **learnr2**. There is no reason to have two packages, or to not have **learnr2** do everything we want a tutorial package to do.

Create interactive R tutorials that run entirely in the browser using 'Quarto' and 'WebR' via the 'quarto-live' extension.
