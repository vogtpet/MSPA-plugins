#!/usr/bin/env Rscript
## ---------------------------------------------------------------------------
## Install the R packages required by RMSPA (application and smoke test).
##
## Used by the CI workflows and useful for local development:
##   Rscript scripts/install-deps.R
##
## On Linux, RSPM (Posit Package Manager) is used when the CI environment
## provides it; the system libraries are installed by the workflow.
## ---------------------------------------------------------------------------

packages <- c("terra", "shiny", "shinyFiles", "shinyjs", "later")

repos <- getOption("repos")
rspm <- Sys.getenv("RSPM", unset = "")
if (nzchar(rspm)) {
  repos <- c(P3M = rspm, CRAN = "https://cloud.r-project.org")
} else if (is.null(repos) || length(repos) == 0L ||
           identical(unname(repos["CRAN"]), "@CRAN@")) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

install.packages(packages, repos = repos)

missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Could not install: ", paste(missing, collapse = ", "), call. = FALSE)
}
cat("Installed:", paste(packages, collapse = ", "), "\n")
