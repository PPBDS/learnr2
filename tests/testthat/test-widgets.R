# Covers R/widgets.R: learnr2_dependency(), encode_payload(),
# decode_payload(), widget_div(), with_dependency(), widget_html() and the
# shared print_widget()/knit_widget().

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

test_that("encode_payload() and decode_payload() round-trip, including htmltools' wrapped base64", {
  payload <- list(id = "q-1", text = "Une question, avec accents: é", answers = list("a", "b"), n = 1)
  encoded <- learnr2:::encode_payload(payload)
  decoded <- learnr2:::decode_payload(encoded)
  expect_equal(decoded$text, payload$text)
  expect_equal(decoded$answers, list("a", "b"))
  # jsonlite wraps long base64 and htmltools writes the newline as &#10;.
  long <- learnr2:::encode_payload(list(id = "x", long = strrep("a", 120)))
  expect_true(grepl("\n", long, fixed = TRUE))
  expect_equal(learnr2:::decode_payload(gsub("\n", "&#10;", long))$id, "x")
  expect_null(learnr2:::decode_payload("!!!"))
})

test_that("widget_div() carries the payload in the named attribute, with noscript text or hidden", {
  withr::local_options(list(learnr2.lang = NULL))
  div <- learnr2:::widget_div("learnr2-question", "data-learnr2-question", list(id = "q"),
                              noscript = "noscript_question")
  html <- as.character(div)
  expect_match(html, 'class="learnr2-question"', fixed = TRUE)
  expect_match(html, 'data-learnr2-question="', fixed = TRUE)
  expect_match(html, "<noscript>This quiz question requires JavaScript.</noscript>", fixed = TRUE)
  expect_false(grepl("hidden", html, fixed = TRUE))
  encoded <- sub('.*data-learnr2-question="([^"]+)".*', "\\1", html)
  expect_equal(learnr2:::decode_payload(encoded)$id, "q")

  hidden <- as.character(learnr2:::widget_div("learnr2-options", "data-learnr2-options", list(a = 1), hidden = TRUE))
  expect_match(hidden, "hidden", fixed = TRUE)
  expect_false(grepl("noscript", hidden, fixed = TRUE))
})

test_that("learnr2_dependency() bundles quiz.js, quiz.css and the language table", {
  dep <- learnr2:::learnr2_dependency()
  expect_s3_class(dep, "html_dependency")
  expect_equal(dep$name, "learnr2-quiz")
  expect_equal(dep$version, as.character(utils::packageVersion("learnr2")))
  expect_equal(dep$script, "quiz.js")
  expect_equal(dep$stylesheet, "quiz.css")
  expect_true(file.exists(file.path(dep$src$file, "quiz.js")))
  expect_true(file.exists(file.path(dep$src$file, "quiz.css")))
  expect_match(dep$head, "window.learnr2Strings", fixed = TRUE)
})

test_that("every widget class renders through widget_html() with the dependency attached", {
  widgets <- list(
    question("Q?", answer("a", correct = TRUE)),
    quiz(question("Q?", answer("a", correct = TRUE))),
    student_info(),
    download_answers_button(),
    tutorial_options()
  )
  for (w in widgets) {
    html <- learnr2:::widget_html(w)
    deps <- htmltools::findDependencies(html)
    expect_true(any(vapply(deps, function(d) d$name == "learnr2-quiz", logical(1))), info = class(w))
    expect_match(as.character(html), "data-learnr2-", fixed = TRUE)
  }
})

test_that("print_widget() prints the HTML source non-interactively and returns its input", {
  withr::local_options(viewer = function(...) stop("browser preview opened non-interactively"))
  q <- question("Q?", answer("a", correct = TRUE))
  expect_output(out <- learnr2:::print_widget(q), "data-learnr2-question")
  expect_identical(out, q)
  knitted <- learnr2:::knit_widget(q)
  expect_s3_class(knitted, "knit_asis")
})
