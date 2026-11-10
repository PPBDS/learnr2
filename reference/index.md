# Package index

## Authoring tutorials

Scaffold and run interactive tutorials.

- [`create_tutorial()`](https://ppbds.github.io/learnr2/reference/create_tutorial.md)
  : Create a new learnr2 tutorial
- [`tutorial_options()`](https://ppbds.github.io/learnr2/reference/tutorial_options.md)
  : Set tutorial-wide options
- [`run_tutorial()`](https://ppbds.github.io/learnr2/reference/run_tutorial.md)
  : Run a bundled tutorial
- [`prerender_tutorials()`](https://ppbds.github.io/learnr2/reference/prerender_tutorials.md)
  : Render every installed Quarto tutorial into the cache
- [`available_tutorials()`](https://ppbds.github.io/learnr2/reference/available_tutorials.md)
  : List tutorials bundled with learnr2 (or any installed package)
- [`show_file()`](https://ppbds.github.io/learnr2/reference/show_file.md)
  : Display all or part of a text file

## Testing tutorials

Confirm tutorials render and follow the authoring rules.

- [`check_tutorials()`](https://ppbds.github.io/learnr2/reference/check_tutorials.md)
  : Check every tutorial in a package
- [`check_tutorial()`](https://ppbds.github.io/learnr2/reference/check_tutorial.md)
  : Check that a tutorial has the recommended components
- [`render_tutorials()`](https://ppbds.github.io/learnr2/reference/render_tutorials.md)
  : Render tutorials, as a test that they build

## Quiz questions

learnr-style quiz questions, graded in the browser.

- [`question()`](https://ppbds.github.io/learnr2/reference/question.md)
  : Create a quiz question
- [`answer()`](https://ppbds.github.io/learnr2/reference/answer.md) :
  Define an answer choice for a quiz question
- [`quiz()`](https://ppbds.github.io/learnr2/reference/quiz.md) : Group
  questions into a quiz

## Collecting student work

Gather reader identifying information, let them turn work in, and check
what comes back.

- [`student_info()`](https://ppbds.github.io/learnr2/reference/student_info.md)
  : Collect student identifying information
- [`download_answers_button()`](https://ppbds.github.io/learnr2/reference/download_answers_button.md)
  : Add a "download my answers" button
- [`check_submission()`](https://ppbds.github.io/learnr2/reference/check_submission.md)
  : Check a submission's fingerprint and provenance
- [`extract_submission_media()`](https://ppbds.github.io/learnr2/reference/extract_submission_media.md)
  : Write a submission's screenshots and recordings to files
- [`submission_time()`](https://ppbds.github.io/learnr2/reference/submission_time.md)
  : Recover a submission's download time
- [`load_tutorial()`](https://ppbds.github.io/learnr2/reference/load_tutorial.md)
  : Reopen a tutorial with a student's downloaded answers filled in

## Quarto-live extension

Manage the bundled quarto-live Quarto extension.

- [`add_live_extension()`](https://ppbds.github.io/learnr2/reference/add_live_extension.md)
  : Add the 'quarto-live' extension to a project
- [`live_extension_dir()`](https://ppbds.github.io/learnr2/reference/live_extension_dir.md)
  : Path to the bundled 'quarto-live' extension
