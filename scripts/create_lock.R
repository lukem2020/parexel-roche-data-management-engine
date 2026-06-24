packages <- trimws(readLines("requirements.txt"))
packages <- packages[!grepl("^#", packages) & nzchar(packages)]

# pandas is a Python package, not available on CRAN for R
r_packages <- setdiff(packages, "pandas")

if ("pandas" %in% packages) {
  message("Skipping 'pandas' (Python package, not an R dependency).")
}

# teal.clinical is not on CRAN; the clinical teal modules package is teal.modules.clinical
if ("teal.clinical" %in% r_packages) {
  message("Mapping 'teal.clinical' -> 'teal.modules.clinical'.")
  r_packages[r_packages == "teal.clinical"] <- "teal.modules.clinical"
}

if (!requireNamespace("renv", quietly = TRUE)) {
  stop("renv is required but not installed.")
}

if (!file.exists("renv/activate.R")) {
  renv::init(bare = TRUE, restart = FALSE)
}

renv::install(r_packages)
renv::snapshot(type = "all", prompt = FALSE)

message("Lock file written to renv.lock")
