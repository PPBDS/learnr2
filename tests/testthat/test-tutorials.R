# Covers R/tutorials.R: available_tutorials() and its helpers (tutorials_in_package(),
# pkg_file(), packages_with_tutorials(), dev_package_path(), tutorial_doc(),
# is_classic_tutorial(), tutorial_title(), tutorial_ordering()), including the
# pkgload::load_all() case a content package's own tests rely on. Shared stubs
# live in helper-stubs.R.

# withr is a Suggests package: skip the whole file if it isn't installed,
# so a check run without Suggests (CRAN's noSuggests) passes.
testthat::skip_if_not_installed("withr")

test_that("available_tutorials(package = 'learnr2') lists the bundled tutorials", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_s3_class(tutorials, "data.frame")
  expect_true(all(
    c("package", "name", "title", "format", "path", "package_dependencies") %in% names(tutorials)
  ))
  expect_true("hello-learnr2" %in% tutorials$name)
  expect_true(all(tutorials$package == "learnr2"))
  # `path` is the installed document itself, ready for render_tutorials().
  expect_true(all(fs::file_exists(tutorials$path)))
  expect_match(tutorials$path[tutorials$name == "hello-learnr2"], "hello-learnr2\\.qmd$")
})

test_that("available_tutorials() with no package scans every installed package", {
  tutorials <- available_tutorials()
  expect_true("hello-learnr2" %in% tutorials$name[tutorials$package == "learnr2"])
})

test_that("packages_with_tutorials() finds tutorials/ dirs by listing libraries, not installed.packages()", {
  # Two fake libraries: a package with tutorials, one without, a stray
  # non-package directory that happens to have tutorials/, and a hidden dir.
  lib1 <- withr::local_tempdir()
  lib2 <- withr::local_tempdir()
  mk <- function(lib, pkg, tutorials = TRUE, description = TRUE) {
    d <- fs::path(lib, pkg)
    fs::dir_create(d)
    if (description) writeLines(paste0("Package: ", pkg), fs::path(d, "DESCRIPTION"))
    if (tutorials) fs::dir_create(fs::path(d, "tutorials"))
  }
  mk(lib1, "withTut")
  mk(lib1, "noTut", tutorials = FALSE)
  mk(lib1, "notAPackage", description = FALSE)
  mk(lib1, ".hidden")
  mk(lib2, "withTut")       # same name in a second library: counted once
  mk(lib2, "secondLibTut")

  found <- learnr2:::packages_with_tutorials(c(lib1, lib2))
  expect_setequal(found, c("withTut", "secondLibTut"))
  expect_identical(learnr2:::packages_with_tutorials(character(0)), character(0))
  expect_identical(learnr2:::packages_with_tutorials(fs::path(lib1, "does-not-exist")), character(0))

  # The real libraries contain learnr2 itself (installed or load_all()-ed
  # via a dev package is covered elsewhere); and the scan never calls
  # installed.packages().
  local_mocked_bindings(installed.packages = function(...) stop("installed.packages() must not be called"),
                        .package = "utils")
  expect_no_error(learnr2:::packages_with_tutorials())
  expect_no_error(available_tutorials())
})

test_that("available_tutorials() errors on an unknown or malformed package", {
  expect_error(available_tutorials(package = ""), "single non-empty string")
  expect_error(available_tutorials(package = c("a", "b")), "single non-empty string")
  expect_error(available_tutorials(package = 1), "single non-empty string")
  expect_error(available_tutorials(package = "not-a-real-package-xyz"), "No package found")
})

test_that("available_tutorials() validates type, and refuses rmarkdown with a pointer to learnr", {
  expect_error(available_tutorials(type = "learnr"), '"all" or "quarto"')
  expect_error(available_tutorials(type = c("all", "quarto")), '"all" or "quarto"')
  expect_error(available_tutorials(type = "rmarkdown"), "learnr::available_tutorials")
})

test_that("available_tutorials() reports every tutorial as quarto; type = 'quarto' is the same list", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_true(all(tutorials$format == "quarto"))
  expect_identical(available_tutorials(package = "learnr2", type = "quarto"), tutorials)
})

test_that("available_tutorials() returns a typed zero-row frame for a package with no tutorials", {
  # 'utils' is installed but ships no inst/tutorials/.
  res <- available_tutorials(package = "utils")
  expect_s3_class(res, "data.frame")
  expect_identical(nrow(res), 0L)
  expect_named(res, c("package", "name", "title", "format", "path", "ordering", "package_dependencies"))
  expect_type(res$package_dependencies, "list")
})

# ---- package_dependencies ------------------------------------------------

test_that("a quarto tutorial needs no local packages: package_dependencies is character(0)", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_type(tutorials$package_dependencies, "list")
  expect_identical(
    tutorials$package_dependencies[[which(tutorials$name == "hello-learnr2")]],
    character(0)
  )
})

# ---- internal helpers ---------------------------------------------------

test_that("tutorials_in_package() returns NULL for a package with no tutorials/ dir", {
  expect_null(learnr2:::tutorials_in_package("utils"))
})

test_that("tutorial_doc() finds a .qmd and ignores a classic .Rmd", {
  d <- withr::local_tempdir()
  expect_true(is.na(learnr2:::tutorial_doc(d)))

  fs::file_create(fs::path(d, "lesson.Rmd"))
  expect_true(is.na(learnr2:::tutorial_doc(d)))

  fs::file_create(fs::path(d, "lesson.qmd"))
  expect_match(learnr2:::tutorial_doc(d), "lesson\\.qmd$")
})

test_that("tutorial_title() reads the YAML title, or NA when absent/unparseable", {
  expect_true(is.na(learnr2:::tutorial_title(NA_character_)))

  no_title <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "format: html", "---", "", "# Body"), no_title)
  expect_true(is.na(learnr2:::tutorial_title(no_title)))

  titled <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "title: Hello There", "---", "", "# Body"), titled)
  expect_identical(learnr2:::tutorial_title(titled), "Hello There")

  # Malformed YAML front matter -> tryCatch swallows the error -> NA.
  bad <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "title: a: b", "---"), bad)
  expect_true(is.na(learnr2:::tutorial_title(bad)))
})

test_that("tutorial_ordering() reads learnr2: ordering:, or NA when absent/invalid", {
  expect_true(is.na(learnr2:::tutorial_ordering(NA_character_)))
  header <- function(...) {
    f <- tempfile(fileext = ".qmd")
    writeLines(c("---", ..., "---", "", "# Body"), f)
    f
  }
  expect_true(is.na(learnr2:::tutorial_ordering(header("title: T"))))
  expect_identical(learnr2:::tutorial_ordering(header("learnr2:", "  ordering: 3")), 3)
  expect_identical(learnr2:::tutorial_ordering(header("learnr2:", "  ordering: 2.5")), 2.5)
  # Not a number, not a single value, or a top-level key: ignored.
  expect_true(is.na(learnr2:::tutorial_ordering(header("learnr2:", "  ordering: first"))))
  expect_true(is.na(learnr2:::tutorial_ordering(header("learnr2:", "  ordering: [1, 2]"))))
  expect_true(is.na(learnr2:::tutorial_ordering(header("ordering: 3"))))
})

test_that("available_tutorials() has an ordering column", {
  tutorials <- available_tutorials(package = "learnr2")
  expect_true("ordering" %in% names(tutorials))
  expect_type(tutorials$ordering, "double")
})

# ---- packages loaded with pkgload::load_all() ----------------------------


test_that("available_tutorials() sees a package loaded with pkgload::load_all()", {
  root <- local_dev_tutorial_package()

  # Not installed, so base system.file() cannot find its tutorials (base::
  # explicitly: under devtools::test() pkgload shims the bare name in this
  # test environment). This is exactly the lookup that used to come up empty.
  expect_false(nzchar(base::system.file("tutorials", package = "fakeTutorials")))

  # ... but the dev package is found, from its source inst/tutorials/.
  tutorials <- available_tutorials(package = "fakeTutorials")
  expect_equal(nrow(tutorials), 1)
  expect_equal(tutorials$package, "fakeTutorials")
  expect_equal(tutorials$name, "demo")  # not "classic", not "empty"
  expect_equal(tutorials$title, "Demo Tutorial")
  expect_equal(tutorials$format, "quarto")
  expect_identical(tutorials$package_dependencies[[1]], character(0))
  # path_real() resolves symlinks (macOS's /var -> /private/var) on both sides.
  expect_equal(
    as.character(fs::path_real(tutorials$path)),
    as.character(fs::path_real(fs::path(root, "inst", "tutorials", "demo", "demo.qmd")))
  )
  expect_equal(
    as.character(fs::path_real(learnr2:::pkg_file("tutorials", package = "fakeTutorials"))),
    as.character(fs::path_real(fs::path(root, "inst", "tutorials")))
  )
  expect_identical(learnr2:::pkg_file("no-such-dir", package = "fakeTutorials"), "")

  # The no-package scan includes it alongside installed packages.
  all_tutorials <- available_tutorials()
  expect_true("fakeTutorials" %in% all_tutorials$package)
  expect_true("learnr2" %in% all_tutorials$package)
})

test_that("a dev package is invisible again once unloaded", {
  local({
    local_dev_tutorial_package()
    expect_equal(nrow(available_tutorials(package = "fakeTutorials")), 1)
  })
  expect_error(available_tutorials(package = "fakeTutorials"), "No package found")
})

test_that("pkg_file() falls back to system.file() for installed and unknown packages", {
  # utils is installed and never pkgload-loaded, so both must agree exactly.
  # (learnr2 itself is a dev package under devtools::test(), so it is not a
  # clean installed example here.)
  expect_identical(
    learnr2:::pkg_file("DESCRIPTION", package = "utils"),
    base::system.file("DESCRIPTION", package = "utils")
  )
  expect_true(nzchar(learnr2:::pkg_file("DESCRIPTION", package = "utils")))
  expect_identical(
    learnr2:::pkg_file(package = "utils"),
    base::system.file(package = "utils")
  )
  expect_identical(learnr2:::pkg_file(package = "not-a-real-package-xyz"), "")
  expect_null(learnr2:::dev_package_path("not-a-real-package-xyz"))
  expect_null(learnr2:::dev_package_path("utils"))
})

# ---- hello-learnr2 bundled content ------------------------------------

test_that("the hello-learnr2 tutorial is bundled and demonstrates quiz questions", {
  qmd <- system.file(
    "tutorials", "hello-learnr2", "hello-learnr2.qmd",
    package = "learnr2"
  )
  expect_true(nzchar(qmd))
  contents <- paste(readLines(qmd), collapse = "\n")
  expect_match(contents, "learnr2::question\\(")
  expect_match(contents, "learnr2::quiz\\(")
})

test_that("is_classic_tutorial() is TRUE only for an .Rmd-only tutorial directory", {
  local_dev_tutorial_package()
  expect_true(learnr2:::is_classic_tutorial("classic", "fakeTutorials"))
  expect_false(learnr2:::is_classic_tutorial("demo", "fakeTutorials"))
  expect_false(learnr2:::is_classic_tutorial("empty", "fakeTutorials"))
  expect_false(learnr2:::is_classic_tutorial("nope", "fakeTutorials"))
})
