#!/usr/bin/env Rscript
# Renders every tutorial bundled in inst/tutorials/ to static HTML for
# publishing under the "tutorials/" path of the pkgdown gh-pages site (see
# .github/workflows/tutorials.yaml, which runs this after installing the
# package with `local::.`). Each tutorial is copied to its own subdirectory
# of _site/tutorials/ (mirroring learnr2::run_tutorial()'s approach) rather
# than rendered in place, since inst/tutorials/ is checked out read-only-ish
# source and add_live_extension() needs to write a copy of the extension
# next to each .qmd.

site_dir <- fs::path_abs(fs::path("_site", "tutorials"))
fs::dir_create(site_dir)

tutorials <- learnr2::available_tutorials(package = "learnr2")
if (nrow(tutorials) == 0) {
  stop("No tutorials found via learnr2::available_tutorials().", call. = FALSE)
}

# Fail the build on any authoring mistake the static checks catch, before
# spending time rendering. hello-learnr2 is a feature tour that deliberately
# shows the R source of its widget chunks and has no "minutes" question.
for (i in seq_len(nrow(tutorials))) {
  skip <- if (tutorials$name[i] == "hello-learnr2") c("echo", "minutes") else NULL
  learnr2::check_tutorial(tutorials$path[i], skip = skip)
}

# render_tutorials() copies each tutorial to site_dir/<name>/, adds the
# extension, renders it, and errors naming the tutorial on failure.
html <- learnr2::render_tutorials(tutorials$path, output_dir = site_dir, quiet = FALSE)

rendered <- data.frame(
  name = tutorials$name,
  title = ifelse(is.na(tutorials$title), tutorials$name, tutorials$title),
  html = as.character(fs::path(tutorials$name, fs::path_file(html[tutorials$name]))),
  stringsAsFactors = FALSE
)

links <- paste0(
  "<li><a href=\"", rendered$html, "\">", rendered$title, "</a></li>",
  collapse = "\n    "
)

index_html <- paste0(
  "<!DOCTYPE html>\n",
  "<html lang=\"en\">\n",
  "<head>\n",
  "  <meta charset=\"utf-8\">\n",
  "  <title>learnr2 tutorials</title>\n",
  "</head>\n",
  "<body>\n",
  "  <h1>learnr2 tutorials</h1>\n",
  "  <ul>\n    ", links, "\n  </ul>\n",
  "</body>\n",
  "</html>\n"
)

writeLines(index_html, fs::path(site_dir, "index.html"))
message("Wrote ", fs::path(site_dir, "index.html"))
