# Interface strings for the rendered page: the Continue and Start Over
# buttons, feedback, notes, errors, and the default labels of question(),
# student_info() and download_answers_button(). English is the reference,
# inst/extdata/quiz/lang/en.json; every other inst/extdata/quiz/lang/<lang>.json
# holds the same keys translated. quiz.js carries its own copy of the
# English table (STRINGS_EN) as a fallback; tests/js checks that the two
# match, so edit both when adding a key.
#
# The language is Quarto's own `lang:` YAML key, read here from
# rmarkdown::metadata while knitting, so a `lang: fr` tutorial gets French
# from Quarto (table of contents, code-copy tooltip) and from learnr2 alike.
# learnr2_dependency() injects the resolved table into the page's <head> as
# window.learnr2Strings, which quiz.js merges over its built-in English, and
# tutorial_options(language = ...) overrides single keys on top of that.

language_dir <- function() {
  system.file("extdata", "quiz", "lang", package = "learnr2")
}

# Language codes with a translation file, "en" first.
available_languages <- function() {
  files <- list.files(language_dir(), pattern = "[.]json$")
  langs <- sub("[.]json$", "", files)
  c("en", sort(setdiff(langs, "en")))
}

# The document language while knitting (`lang:` in the YAML header, via
# rmarkdown::metadata, which Quarto populates for knitr documents), else the
# `learnr2.lang` option, else English. Returned already resolved to a
# language we ship.
tutorial_lang <- function() {
  lang <- NULL
  if (isTRUE(getOption("knitr.in.progress"))) {
    lang <- rmarkdown::metadata$lang
  }
  if (is.null(lang)) {
    lang <- getOption("learnr2.lang")
  }
  resolve_lang(lang)
}

# Map a BCP 47 tag to a shipped translation: the exact tag if there is a
# file for it, else its primary subtag ("fr-CA" -> "fr"), else "en". NULL,
# NA and "" are English. Case-insensitive; "_" is accepted for "-".
resolve_lang <- function(lang) {
  if (is.null(lang) || length(lang) != 1 || is.na(lang) || !nzchar(lang)) {
    return("en")
  }
  lang <- tolower(gsub("_", "-", as.character(lang)))
  available <- available_languages()
  if (lang %in% available) {
    return(lang)
  }
  primary <- sub("-.*$", "", lang)
  if (primary %in% available) primary else "en"
}

strings_cache <- new.env(parent = emptyenv())

# The full string table for `lang`: English with the translation's keys laid
# over it, so a key missing from a translation still has a value. Cached per
# language; a page with forty widgets asks forty times.
tutorial_strings <- function(lang = tutorial_lang()) {
  lang <- resolve_lang(lang)
  cached <- strings_cache[[lang]]
  if (!is.null(cached)) {
    return(cached)
  }
  strings <- read_language_file("en")
  if (lang != "en") {
    translated <- read_language_file(lang)
    strings[names(translated)] <- translated
  }
  assign(lang, strings, envir = strings_cache)
  strings
}

read_language_file <- function(lang) {
  path <- file.path(language_dir(), paste0(lang, ".json"))
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

tutorial_string <- function(key, lang = tutorial_lang()) {
  value <- tutorial_strings(lang)[[key]]
  if (is.null(value)) {
    stop("Unknown interface string `", key, "`.", call. = FALSE)
  }
  value
}

# The <head> snippet learnr2_dependency() injects: the resolved table as a
# global quiz.js reads before rendering anything. "</" is escaped so a
# string can never close the script element.
language_script <- function(lang = tutorial_lang()) {
  json <- jsonlite::toJSON(tutorial_strings(lang), auto_unbox = TRUE)
  json <- gsub("</", "<\\/", as.character(json), fixed = TRUE)
  paste0("<script>window.learnr2Strings = ", json, ";</script>")
}
