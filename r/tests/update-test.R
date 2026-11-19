## ---------------------------------------------------------------------------
## Regression test for install_update().
##
## The archive is unpacked next to the running installation. This used to fail
## with "The update could not be moved to its destination" when tempdir() was
## on a different filesystem (tmpfs /tmp on Linux): the rename failed and the
## directory copy fallback did not create the destination.
##
## Usage: Rscript tests/update-test.R
## ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
here <- if (length(file_arg) == 1L && nzchar(file_arg)) {
  dirname(normalizePath(file_arg))
} else {
  normalizePath("tests", mustWork = FALSE)
}
app_dir <- normalizePath(file.path(here, ".."))
setwd(app_dir)

source("R/platform.R")

failed <- FALSE
check <- function(what, condition, detail = "") {
  if (isTRUE(condition)) {
    cat("ok    ", what, "\n", sep = "")
  } else {
    failed <<- TRUE
    cat("FAIL  ", what, if (nzchar(detail)) paste0(": ", detail) else "", "\n",
        sep = "")
  }
}

tmp <- tempfile("rmspa-update-test-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)

## Minimal release archive with the layout RMSPA/...
pkg <- file.path(tmp, "RMSPA")
dir.create(pkg)
writeLines("9.9.9", file.path(pkg, "VERSION"))
writeLines("dummy", file.path(pkg, "app.R"))
zipfile <- file.path(tmp, "RMSPA-9.9.9.zip")
old_wd <- setwd(tmp)
utils::zip(zipfile, "RMSPA", flags = "-r9X")
setwd(old_wd)

check("test archive created", file.exists(zipfile))

env <- new.env(parent = globalenv())
sys.source("R/platform.R", envir = env)
sys.source("R/update.R", envir = env)
env$rmspa_download_url <- function(version) paste0("file://", zipfile)

dest_root <- file.path(tmp, "dest")
dir.create(dest_root)

## 1. Normal path: the staging directory is next to the destination.
p1 <- env$install_update("9.9.9", app_dir, dest_root = dest_root)
check("installed next to the application", dir.exists(p1) &&
        identical(basename(p1), "RMSPA-9.9.9"), p1)
check("installed VERSION", identical(read_first_line(file.path(p1, "VERSION")),
                                     "9.9.9"))
check("installed app.R", file.exists(file.path(p1, "app.R")))

## 2. Fallback: rename is impossible, contents must still be copied.
env$file.rename <- function(from, to) FALSE
p2 <- env$install_update("9.9.9", app_dir, dest_root = dest_root)
check("fallback installed a second copy", dir.exists(p2) &&
        identical(basename(p2), "RMSPA-9.9.9-1"), p2)
check("fallback copied VERSION",
      file.exists(file.path(p2, "VERSION")))
check("fallback copied app.R",
      file.exists(file.path(p2, "app.R")))

## 3. Unwritable destination (a file, so no directory can be created there):
##    the installer must fall back to a writable location.
env$file.rename <- base::file.rename
not_a_dir <- file.path(tmp, "not-a-directory")
writeLines("x", not_a_dir)
p3 <- env$install_update("9.9.9", app_dir, dest_root = not_a_dir)
check("fell back to a writable location",
      dir.exists(p3) && file.exists(file.path(p3, "VERSION")), p3)
if (dir.exists(p3)) unlink(p3, recursive = TRUE, force = TRUE)

cat("\n")
if (failed) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("All checks passed.\n")
