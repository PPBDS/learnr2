# Covers R/language.R: available_languages(), tutorial_lang(),
# resolve_lang(), tutorial_strings(), tutorial_string() and
# language_script(), plus the parity of the shipped translation files.

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

test_that("every translation has exactly the English keys, all non-empty", {
  en <- learnr2:::read_language_file("en")
  expect_gt(length(en), 40)
  expect_true(all(nzchar(unlist(en))))
  for (lang in setdiff(learnr2:::available_languages(), "en")) {
    translated <- learnr2:::read_language_file(lang)
    expect_setequal(names(translated), names(en))
    expect_true(all(nzchar(unlist(translated))), info = lang)
    # Placeholders are part of the contract with quiz.js.
    for (key in grep("\\{", unlist(en), value = TRUE)) {
      holders <- regmatches(en[[names(en)[en == key]]], gregexpr("\\{\\w+\\}", key))[[1]]
      expect_true(all(vapply(holders, grepl, logical(1), x = translated[[names(en)[en == key]]], fixed = TRUE)),
                  info = paste(lang, key))
    }
  }
})

test_that("available_languages() lists English first, then the shipped translations", {
  langs <- learnr2:::available_languages()
  expect_identical(langs[1], "en")
  expect_true("fr" %in% langs)
})

test_that("resolve_lang() falls back from a regional tag to its language, then to English", {
  expect_identical(learnr2:::resolve_lang("fr"), "fr")
  expect_identical(learnr2:::resolve_lang("fr-CA"), "fr")
  expect_identical(learnr2:::resolve_lang("FR_fr"), "fr")
  expect_identical(learnr2:::resolve_lang("de"), "en")
  expect_identical(learnr2:::resolve_lang(NULL), "en")
  expect_identical(learnr2:::resolve_lang(""), "en")
  expect_identical(learnr2:::resolve_lang(NA), "en")
})

test_that("tutorial_lang() is English outside a render and honours the learnr2.lang option", {
  withr::local_options(list(knitr.in.progress = NULL, learnr2.lang = NULL))
  expect_identical(learnr2:::tutorial_lang(), "en")
  withr::local_options(list(learnr2.lang = "fr"))
  expect_identical(learnr2:::tutorial_lang(), "fr")
})

test_that("tutorial_strings() lays a translation over English, key by key", {
  en <- learnr2:::tutorial_strings("en")
  fr <- learnr2:::tutorial_strings("fr")
  expect_identical(names(fr), names(en))
  expect_identical(fr$continue, "Continuer")
  expect_identical(en$continue, "Continue")
  expect_identical(learnr2:::tutorial_string("start_over", "fr"), "Recommencer")
  expect_error(learnr2:::tutorial_string("no_such_key"), "Unknown interface string")
})

test_that("language_script() injects the resolved table and cannot close its own script tag", {
  script <- learnr2:::language_script("fr")
  expect_match(script, "^<script>window.learnr2Strings = \\{", perl = TRUE)
  expect_match(script, "Continuer", fixed = TRUE)
  expect_false(grepl("</", sub("</script>$", "", script), fixed = TRUE))
})

test_that("the dependency, the widgets and their noscript text follow the document language", {
  withr::local_options(list(learnr2.lang = "fr"))
  dep <- learnr2:::learnr2_dependency()
  expect_match(dep$head, "Recommencer", fixed = TRUE)
  expect_match(as.character(learnr2:::question_div(question("Q?", answer("a", correct = TRUE)))),
               "Cette question", fixed = TRUE)
  expect_match(as.character(learnr2:::info_div(student_info())), "Ce formulaire", fixed = TRUE)
  expect_match(as.character(learnr2:::download_button_div(download_answers_button())),
               "Ce bouton", fixed = TRUE)
  expect_match(as.character(learnr2:::quiz_html(quiz(question("Q?", answer("a", correct = TRUE))))),
               ">Quiz<", fixed = TRUE)
  expect_match(as.character(learnr2:::quiz_html(quiz(question("Q?", answer("a", correct = TRUE)), caption = "Arithmétique"))),
               ">Arithmétique<", fixed = TRUE)
})

test_that("question() leaves its labels to the language table unless given", {
  q <- question("Q?", answer("a", correct = TRUE))
  expect_null(q$payload$submitLabel)
  expect_null(q$payload$correctMessage)
  custom <- question("Q?", answer("a", correct = TRUE), correct = "Bravo", submit_button = "Go")
  expect_equal(custom$payload$correctMessage, "Bravo")
  expect_equal(custom$payload$submitLabel, "Go")
  expect_error(question("Q?", answer("a", correct = TRUE), correct = c("a", "b")), "single non-empty string")
  expect_error(quiz(question("Q?", answer("a", correct = TRUE)), caption = ""), "single non-empty string")
})
