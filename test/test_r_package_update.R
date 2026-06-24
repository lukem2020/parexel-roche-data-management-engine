# Validate that the project library matches renv.lock.
#
# Run from the project root:
#   Rscript -e "testthat::test_file('test/test_r_package_update.R')"

locate_project_root <- function() {
  path <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  while (!identical(path, dirname(path))) {
    if (file.exists(file.path(path, "renv.lock"))) {
      return(path)
    }
    path <- dirname(path)
  }
  stop("Could not find project root containing renv.lock", call. = FALSE)
}

read_lockfile_versions <- function(lockfile_path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required to read renv.lock", call. = FALSE)
  }

  lock <- jsonlite::fromJSON(lockfile_path, simplifyVector = FALSE)
  packages <- lock$Packages

  if (is.null(packages) || length(packages) == 0) {
    stop("renv.lock does not contain any packages", call. = FALSE)
  }

  versions <- vapply(packages, function(pkg) pkg$Version, character(1))
  names(versions) <- vapply(packages, function(pkg) pkg$Package, character(1))
  versions
}

installed_version <- function(package) {
  as.character(utils::packageVersion(package))
}

normalize_version <- function(version) {
  as.character(package_version(version))
}

versions_match <- function(expected, actual) {
  identical(normalize_version(expected), normalize_version(actual))
}

project_root <- locate_project_root()
lockfile_path <- file.path(project_root, "renv.lock")
locked_versions <- read_lockfile_versions(lockfile_path)

if (file.exists(file.path(project_root, "renv", "activate.R"))) {
  source(file.path(project_root, "renv", "activate.R"), local = FALSE)
}

testthat::test_that("renv.lock exists and lists packages", {
  testthat::expect_true(file.exists(lockfile_path))
  testthat::expect_gt(length(locked_versions), 0L)
})

testthat::test_that("every package in renv.lock is installed", {
  missing <- character()

  for (package in names(locked_versions)) {
    if (!requireNamespace(package, quietly = TRUE)) {
      missing <- c(missing, package)
    }
  }

  testthat::expect_equal(
    missing,
    character(),
    info = paste(
      "Packages listed in renv.lock but not installed:",
      paste(missing, collapse = ", ")
    )
  )
})

testthat::test_that("installed package versions match renv.lock", {
  mismatches <- character()

  for (package in names(locked_versions)) {
    if (!requireNamespace(package, quietly = TRUE)) {
      next
    }

    expected <- locked_versions[[package]]
    actual <- installed_version(package)

    if (!versions_match(expected, actual)) {
      mismatches <- c(
        mismatches,
        sprintf("%s (lockfile: %s, installed: %s)", package, expected, actual)
      )
    }
  }

  testthat::expect_equal(
    mismatches,
    character(),
    info = paste(
      "Installed versions differ from renv.lock:",
      paste(mismatches, collapse = "; ")
    )
  )
})

testthat::test_that("project R version matches renv.lock", {
  lock <- jsonlite::fromJSON(lockfile_path, simplifyVector = FALSE)
  locked_r <- lock$R$Version
  actual_r <- paste(R.version$major, R.version$minor, sep = ".")

  testthat::expect_equal(
    actual_r,
    locked_r,
    info = sprintf(
      "R version mismatch (lockfile: %s, installed: %s)",
      locked_r,
      actual_r
    )
  )
})
