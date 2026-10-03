# learnr2 0.1.0

* `question()` gains `show_text`. Set `show_text = FALSE` to keep the prompt
  out of the widget box when it is already written as ordinary text on the
  page above it; the prompt stays in the saved data and is still read by
  screen readers.
* Printing a `question()`, `quiz()`, `student_info()`, or
  `download_answers_button()` at the console now opens a browser preview only
  in an interactive session; non-interactive prints (scripts, `R CMD check`)
  emit the HTML source instead of launching the system browser.

# learnr2 0.0.0

We hope to replace both **learnr** and **tutorial.helpers** with **learnr2**. There is no reason to have two packages, or to not have **learnr2** do everything we want a tutorial package to do.

Create interactive R tutorials that run entirely in the browser using 'Quarto' and 'WebR' via the 'quarto-live' extension.
