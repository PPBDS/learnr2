#' List tutorials bundled with learnr2 (or any installed package)
#'
#' Scans one package -- or, by default, every package installed -- for a
#' bundled `inst/tutorials/` directory, the same convention 'learnr' uses,
#' and lists the learnr2 tutorials in it: each subdirectory that contains a
#' `.qmd` document. Classic 'learnr' tutorials (`.Rmd`) in the same
#' directory are not listed; learnr2 neither lists nor runs them (see
#' [run_tutorial()]).
#' This lets tools like the "R Tutorials" VS Code extension discover
#' tutorials from separately-installed content packages (in the style of
#' 'primer.tutorials') without knowing their names in advance.
#'
#' A package loaded from its source tree with `pkgload::load_all()` (as
#' `devtools::load_all()` and `devtools::test()` do) counts as well: its
#' tutorials are read from the source `inst/tutorials/`, so a content
#' package's own tests see its working tree, not a stale installed copy.
#' See the section below.
#'
#' @param package Name of a single package to scan. Defaults to `NULL`,
#'   which scans every installed package, plus any package currently loaded
#'   with `pkgload::load_all()`.
#' @param type Kept so existing callers keep working: `"all"` (the
#'   default) and `"quarto"` both list every learnr2 tutorial. learnr2 no
#'   longer handles classic learnr tutorials, so `"rmarkdown"` is an error;
#'   use `learnr::available_tutorials()` for those.
#'
#' @return A data frame with one row per tutorial and columns `package`,
#'   `name`, `title` (`NA` if the tutorial's `.qmd` has no YAML `title`),
#'   `format` (always `"quarto"`), `path` (the installed `.qmd` file),
#'   `ordering` (the number set by `learnr2: ordering:` in the YAML header;
#'   `NA` if absent -- see "Ordering" below), and `package_dependencies` (a
#'   list column of the R packages each tutorial needs installed locally:
#'   always `character(0)`, since a learnr2 tutorial runs its code in the
#'   reader's browser). `format` and `package_dependencies` carry no
#'   information any more; they are kept so that tools written when learnr2
#'   also listed classic tutorials, such as the "R Tutorials" VS Code
#'   extension, keep working.
#'   `name` can be passed to [run_tutorial()]; `path` to
#'   [render_tutorials()] and [check_tutorial()].
#'
#' @section Ordering:
#' By default a package's tutorials are listed in the order of their
#' directory names, so authors usually number them (`01-intro`,
#' `02-data`, ...). A tutorial can instead set its position in its YAML
#' header, without renaming its directory (a directory name is the
#' tutorial's id, so renaming one breaks links and render caches):
#'
#' ```yaml
#' learnr2:
#'   ordering: 3
#' ```
#'
#' `available_tutorials()` reports it in the `ordering` column. Tools that
#' list tutorials, such as the "R Tutorials" VS Code extension, sort a
#' package's tutorials by `ordering` (lowest first), with tutorials that
#' don't set it after those that do, in directory-name order. A value that
#' is not a single number is ignored (reported as `NA`); [check_tutorial()]
#' flags it.
#'
#' @section Packages loaded with pkgload:
#' `system.file()` resolves against the *installed* copy of a package, and
#' 'pkgload' redirects it only for code inside the package being developed,
#' not for learnr2's calls. So this function and [run_tutorial()] check
#' whether `package` is a namespace loaded by `pkgload::load_all()` and, if
#' so, read its tutorials from the source tree's `inst/tutorials/`. A
#' content package's `devtools::test()` therefore sees its working tree,
#' not a stale install. Nothing changes for installed packages, and
#' 'pkgload' itself is not required.
#' @export
#' @examples
#' # Qualified with learnr2:: because the learnr package exports a function of
#' # the same name; this guarantees learnr2's version is used even if learnr is
#' # also attached and masks it on the search path.
#' learnr2::available_tutorials(package = "learnr2")
#' learnr2::available_tutorials(package = "learnr2", type = "quarto")
available_tutorials <- function(package = NULL, type = "all") {
  if (identical(type, "rmarkdown")) {
    stop('learnr2 does not list classic learnr (.Rmd) tutorials. ',
         'Use learnr::available_tutorials() for those.', call. = FALSE)
  }
  if (!is.character(type) || length(type) != 1 || !type %in% c("all", "quarto")) {
    stop('`type` must be "all" or "quarto".', call. = FALSE)
  }
  if (!is.null(package)) {
    check_string(package, "package")
    if (!nzchar(pkg_file(package = package))) {
      stop("No package found with name: \"", package, "\".", call. = FALSE)
    }
    packages <- package
  } else {
    packages <- union(dev_packages(), packages_with_tutorials())
  }

  rows <- lapply(packages, tutorials_in_package)
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(data.frame(
      package = character(0),
      name = character(0),
      title = character(0),
      format = character(0),
      path = character(0),
      ordering = numeric(0),
      package_dependencies = I(list()),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# One data frame row per learnr2 tutorial in `pkg`'s inst/tutorials/ -- each
# subdirectory holding a .qmd -- or NULL if there are none. Directories with
# only a classic learnr .Rmd (or no document) are skipped.
tutorials_in_package <- function(pkg) {
  root <- pkg_file("tutorials", package = pkg)
  if (!nzchar(root)) {
    return(NULL)
  }
  dirs <- fs::dir_ls(root, type = "directory")
  docs <- vapply(dirs, tutorial_doc, character(1), USE.NAMES = FALSE)
  keep <- !is.na(docs)
  if (!any(keep)) {
    return(NULL)
  }
  dirs <- dirs[keep]
  docs <- docs[keep]
  data.frame(
    package = pkg,
    name = fs::path_file(dirs),
    title = vapply(docs, tutorial_title, character(1), USE.NAMES = FALSE),
    format = "quarto",
    path = docs,
    ordering = vapply(docs, tutorial_ordering, numeric(1), USE.NAMES = FALSE),
    package_dependencies = I(rep(list(character(0)), length(docs))),
    stringsAsFactors = FALSE
  )
}

# system.file() that also sees a package loaded from its source tree with
# pkgload::load_all() -- what devtools::load_all() and devtools::test() do.
#
# pkgload makes such a package's *own* system.file() calls resolve to its
# source inst/, but learnr2's calls are not rewritten, so base system.file()
# finds either nothing (package not installed) or an installed copy that may
# be stale. pkgload marks a namespace it loaded with a `.__DEVTOOLS__`
# binding and registers the source directory as the namespace path; this
# reads both without needing pkgload itself. With no `...` it returns the
# package root, like system.file(package = pkg). Everything else goes to
# base system.file() unchanged.
pkg_file <- function(..., package) {
  root <- dev_package_path(package)
  if (is.null(root)) {
    return(system.file(..., package = package))
  }
  if (...length() == 0) {
    return(root)
  }
  path <- file.path(root, "inst", ...)
  if (file.exists(path)) path else ""
}

# Names of every installed package that ships a tutorials/ directory, found
# by listing the libraries on .libPaths() directly. utils::installed.packages()
# would also give the names, but it reads several files per installed
# package (its own help page warns against using it for this), whereas a
# tutorials/ directory is one file.exists() per package directory and most
# packages have none. First library wins for a name installed in several,
# matching system.file(). The libraries are a parameter only for testing.
packages_with_tutorials <- function(libs = .libPaths()) {
  found <- character(0)
  for (lib in libs) {
    pkgs <- list.dirs(lib, full.names = FALSE, recursive = FALSE)
    pkgs <- pkgs[!startsWith(pkgs, ".")]
    has_tutorials <- file.exists(file.path(lib, pkgs, "tutorials")) &
      file.exists(file.path(lib, pkgs, "DESCRIPTION"))
    found <- c(found, pkgs[has_tutorials])
  }
  unique(found)
}

# The source directory of `package` if pkgload::load_all() loaded it, else
# NULL. Checking isNamespaceLoaded() first means an unloaded or uninstalled
# package is simply not a dev package, with no error.
dev_package_path <- function(package) {
  if (!isNamespaceLoaded(package)) {
    return(NULL)
  }
  ns <- asNamespace(package)
  if (!exists(".__DEVTOOLS__", envir = ns, inherits = FALSE)) {
    return(NULL)
  }
  getNamespaceInfo(ns, "path")
}

# Every namespace currently loaded by pkgload::load_all().
dev_packages <- function() {
  loaded <- loadedNamespaces()
  loaded[!vapply(lapply(loaded, dev_package_path), is.null, logical(1))]
}

# The first .qmd directly inside `dir`, or NA if it has none.
tutorial_doc <- function(dir) {
  doc <- fs::dir_ls(dir, glob = "*.qmd")
  if (length(doc) == 0) NA_character_ else as.character(doc[1])
}

# TRUE if `package` has a tutorial directory `name` holding a classic learnr
# .Rmd and no .qmd: something run_tutorial() can name helpfully, rather than
# report as unknown.
is_classic_tutorial <- function(name, package) {
  dir <- pkg_file("tutorials", name, package = package)
  nzchar(dir) && fs::dir_exists(dir) &&
    is.na(tutorial_doc(dir)) && length(fs::dir_ls(dir, glob = "*.Rmd")) > 0
}

# The YAML `title:` of `doc`, or NA if `doc` is NA or has no YAML `title`.
tutorial_title <- function(doc) {
  if (is.na(doc)) {
    return(NA_character_)
  }
  front_matter <- tryCatch(
    rmarkdown::yaml_front_matter(doc),
    error = function(e) NULL
  )
  title <- front_matter$title
  if (is.null(title)) NA_character_ else as.character(title)
}

# The YAML `learnr2: ordering:` of `doc` as a number, or NA if `doc` is NA,
# has no such key, or the value is not a single number (see "Ordering" in
# ?available_tutorials; check_tutorial() reports a malformed one).
tutorial_ordering <- function(doc) {
  if (is.na(doc)) {
    return(NA_real_)
  }
  front_matter <- tryCatch(
    rmarkdown::yaml_front_matter(doc),
    error = function(e) NULL
  )
  ordering <- front_matter$learnr2$ordering
  if (is.numeric(ordering) && length(ordering) == 1 && !is.na(ordering)) {
    as.numeric(ordering)
  } else {
    NA_real_
  }
}
