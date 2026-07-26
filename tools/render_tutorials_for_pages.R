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

rendered <- data.frame(name = character(0), title = character(0), html = character(0))

for (i in seq_len(nrow(tutorials))) {
  name <- tutorials$name[i]
  title <- tutorials$title[i]
  if (is.na(title)) {
    title <- name
  }

  src <- system.file("tutorials", name, package = "learnr2")
  work_dir <- fs::path(site_dir, name)
  fs::dir_copy(src, work_dir, overwrite = TRUE)

  learnr2::add_live_extension(work_dir)

  qmd <- fs::dir_ls(work_dir, glob = "*.qmd")[1]
  message("Rendering ", name, " (", qmd, ")...")
  quarto::quarto_render(input = as.character(qmd), quiet = FALSE)

  html <- fs::path_ext_set(qmd, "html")
  if (!fs::file_exists(html)) {
    stop("Expected rendered file not found: ", html, call. = FALSE)
  }

  rendered <- rbind(rendered, data.frame(
    name = name,
    title = title,
    html = fs::path(name, fs::path_file(html)),
    stringsAsFactors = FALSE
  ))
}

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
