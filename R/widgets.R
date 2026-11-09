# How every widget reaches the page. question(), quiz(), student_info(),
# download_answers_button() and tutorial_options() each build a payload
# list in R; the page gets a <div> carrying that payload as base64 JSON in a
# data-learnr2-* attribute, plus one shared html dependency (quiz.js,
# quiz.css and the language table), and quiz.js builds the widget in the
# browser. The print and knit_print methods of every widget class route
# through widget_html() below.

learnr2_dependency <- function() {
  htmltools::htmlDependency(
    name = "learnr2-quiz",
    version = as.character(utils::packageVersion("learnr2")),
    src = system.file("extdata", "quiz", package = "learnr2"),
    script = "quiz.js",
    stylesheet = "quiz.css",
    # The interface strings for the document language (R/language.R),
    # ahead of quiz.js on any page with at least one widget.
    head = language_script(),
    all_files = FALSE
  )
}

encode_payload <- function(payload) {
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
  jsonlite::base64_enc(charToRaw(as.character(json)))
}

# The inverse, for payloads read back out of a rendered page. jsonlite wraps
# long base64 at 76 columns and htmltools writes each newline as `&#10;`
# (a carriage return as `&#13;`), so those entities and any whitespace are
# dropped first; browsers' atob() ignores the newlines the same way. NULL
# if it still won't decode.
decode_payload <- function(b64) {
  clean <- gsub("&#10;|&#13;|\\s", "", b64)
  tryCatch(
    jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(clean)), simplifyVector = FALSE),
    error = function(e) NULL
  )
}

# The <div> for one widget: `attr` is the data-learnr2-* attribute carrying
# the payload, `noscript` the key of the string shown where JavaScript is
# off, `hidden` for a widget with nothing to show (tutorial_options()).
widget_div <- function(class, attr, payload, noscript = NULL, hidden = FALSE) {
  args <- list(class = class)
  args[[attr]] <- encode_payload(payload)
  if (hidden) {
    args$hidden <- NA
  }
  if (!is.null(noscript)) {
    args <- c(args, list(htmltools::tags$noscript(tutorial_string(noscript))))
  }
  do.call(htmltools::tags$div, args)
}

with_dependency <- function(tag) {
  htmltools::attachDependencies(tag, learnr2_dependency())
}

# A widget as an htmltools tag with the learnr2 dependency attached: one
# method per widget class, in the file that defines the class.
widget_html <- function(x) {
  UseMethod("widget_html")
}

# Console printing previews the widget in a browser only in an interactive
# session. htmltools::browsable() would open the browser unconditionally,
# which in a non-interactive session (R CMD check, Rscript, CI) launches
# whatever handles HTML on that machine; on CRAN's Debian checker that is
# Calibre, which left `calibre-*` directories in the temp dir and earned a
# "detritus in the temp directory" NOTE. Non-interactive prints emit the
# HTML source, like print(htmltools::tags$div()).
print_widget <- function(x) {
  print(widget_html(x), browse = interactive())
  invisible(x)
}

knit_widget <- function(x, ...) {
  knitr::knit_print(widget_html(x), ...)
}
