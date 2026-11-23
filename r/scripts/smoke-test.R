#!/usr/bin/env Rscript
## ---------------------------------------------------------------------------
## RMSPA smoke test
##
## Runs the complete pipeline (input checks, staging, MSPA, GeoTIFF output) on
## the bundled example image and compares the result with the reference output
## of MSPAstandalone.
##
## Usage:
##   Rscript scripts/smoke-test.R
##   Rscript scripts/smoke-test.R --binary /path/to/mspa
##
## The binary defaults to resources/<target>/..., i.e. the file used by the
## application. On an unsupported platform (macOS Intel) pass --binary
## explicitly, for example to test a development build.
## ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
binary_arg <- NULL
for (i in seq_along(args)) {
  if (identical(args[i], "--binary") && i < length(args)) {
    binary_arg <- args[i + 1L]
  } else if (startsWith(args[i], "--binary=")) {
    binary_arg <- sub("^--binary=", "", args[i])
  }
}

script_dir <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f) == 1L && nzchar(f)) dirname(normalizePath(f)) else getwd()
})
app_dir <- normalizePath(file.path(script_dir, ".."))
setwd(app_dir)

suppressPackageStartupMessages(library(terra))
source("R/platform.R")
source("R/process.R")

binary <- if (!is.null(binary_arg)) binary_arg else
  Sys.getenv("MSPA_BINARY", unset = "")
if (!nzchar(binary)) binary <- mspa_binary(app_dir)
if (!nzchar(binary)) {
  stop("No MSPA binary for this platform (", mspa_target(), "). ",
       "Use --binary to point to one.", call. = FALSE)
}
if (!file.exists(binary)) {
  stop("The MSPA binary does not exist: ", binary, call. = FALSE)
}
if (!mspa_make_executable(binary)) {
  stop("The MSPA binary is not executable: ", binary, call. = FALSE)
}

cat("MSPA binary: ", binary, "\n", sep = "")
cat("Target:      ", mspa_target(), "\n", sep = "")

tmp <- tempfile("rmspa-smoke-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)

failures <- 0L
check <- function(what, condition, detail = "") {
  if (isTRUE(condition)) {
    cat("ok    ", what, "\n", sep = "")
  } else {
    failures <<- failures + 1L
    cat("FAIL  ", what, if (nzchar(detail)) paste0(": ", detail) else "", "\n",
        sep = "")
  }
}

pixels <- function(path) as.integer(terra::values(terra::rast(path)))

## --- 1. default parameters --------------------------------------------------
cat("\n[1] default parameters\n")
res <- mspa_process("examples/input.tif", tmp, binary = binary,
                    input_name = "input.tif")
check("process completed", res$ok, res$message %||% "")
if (isTRUE(res$ok)) {
  check("output file name",
        identical(basename(res$outfile), "input_8_1_1_1.tif"),
        basename(res$outfile))
  check("pixel values match reference.tif",
        identical(pixels(res$outfile), pixels("tests/reference.tif")))
  out <- terra::rast(res$outfile)
  info <- tryCatch(paste(terra::describe(res$outfile), collapse = "\n"),
                   error = function(e) "")
  check("NoData is 255", grepl("NoData Value=255", info, fixed = TRUE),
        if (nzchar(info)) sub(".*(NoData Value=[^ ]*).*", "\\1", info) else "no gdalinfo output")
  check("CRS matches the input",
        isTRUE(terra::same.crs(out, terra::rast("examples/input.tif"))))
  check("no .aux.xml sidecar", !file.exists(paste0(res$outfile, ".aux.xml")))

  if (exists("metags", envir = asNamespace("terra"), inherits = FALSE)) {
    tags <- tryCatch(terra::metags(out), error = function(e) NULL)
    val <- if (is.null(tags)) NA_character_ else
      tags$value[match("TIFFTAG_IMAGEDESCRIPTION", tags$name)]
    check("GTB metadata written",
          !is.na(val) && startsWith(val, "GTB_MSPA,"),
          if (is.na(val)) "TIFFTAG_IMAGEDESCRIPTION missing" else val)
  }
}

## --- 2. non-default parameters ----------------------------------------------
cat("\n[2] graphfg = 4, internal = 0\n")
res2 <- mspa_process("examples/input.tif", tmp, graphfg = 4L, internal = 0L,
                     binary = binary, input_name = "input.tif")
check("process completed", res2$ok, res2$message %||% "")
if (isTRUE(res2$ok)) {
  check("output file name",
        identical(basename(res2$outfile), "input_4_1_1_0.tif"),
        basename(res2$outfile))
  check("pixel values match reference_nondefault.tif",
        identical(pixels(res2$outfile), pixels("tests/reference_nondefault.tif")))
}

## --- 3. input encodings -----------------------------------------------------
cat("\n[3] input encoding (0/1 mask versus GTB 1/2)\n")
src <- terra::rast("examples/input.tif")
fg <- terra::ifel(src == 2L, 1L, 0L)
maskfile <- file.path(tmp, "mask.tif")
gtbfile <- file.path(tmp, "gtb.tif")
terra::writeRaster(fg, maskfile, datatype = "INT1U", overwrite = TRUE)
terra::writeRaster(terra::ifel(fg == 1L, 2L, 1L), gtbfile,
                   datatype = "INT1U", overwrite = TRUE)

resm <- mspa_process(maskfile, tmp, encoding = "mask", binary = binary,
                     input_name = "mask.tif")
resg <- mspa_process(gtbfile, tmp, encoding = "gtb", binary = binary,
                     input_name = "gtb.tif")
check("mask input processed", resm$ok, resm$message %||% "")
check("GTB input processed", resg$ok, resg$message %||% "")
if (isTRUE(resm$ok) && isTRUE(resg$ok)) {
  check("encodings give identical results",
        identical(pixels(resm$outfile), pixels(resg$outfile)))
}

## --- 4. validation ----------------------------------------------------------
cat("\n[4] input validation\n")
bad <- file.path(tmp, "bad.tif")
values <- terra::rast(src)
values[] <- 0L
values[1, 1] <- 7L
terra::writeRaster(values, bad, datatype = "INT1U", overwrite = TRUE)
check("values above 2 are rejected",
      !isTRUE(mspa_inspect(bad, name = "bad.tif")$ok))
check("non-GeoTIFF names are rejected",
      !isTRUE(mspa_inspect("examples/input.tif", name = "input.png")$ok))

## Missing / NoData reporting
na_file <- file.path(tmp, "na.tif")
nra <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 20,
                   ymin = 0, ymax = 20, crs = "EPSG:4326")
terra::values(nra) <- 1L
nra[1, 1] <- 2L
nra[1, 2] <- NA
terra::writeRaster(nra, na_file, datatype = "INT1U", NAflag = 255,
                   overwrite = TRUE)
info_na <- mspa_inspect(na_file, encoding = "gtb")
check("missing cells are counted",
      isTRUE(info_na$ok) && as.numeric(info_na$info$missing) == 1)
check("the NoData value is reported",
      isTRUE(all.equal(info_na$info$nodata, 255)))

## --- summary ----------------------------------------------------------------
## --- 5. output naming -------------------------------------------------------
cat("\n[5] output naming\n")
check("parameters are part of the name",
      identical(mspa_output_name("forest.tif", 4L, 2L, 0L, 1L),
                "forest_4_2_0_1.tif"))
check(".tiff is stripped",
      identical(mspa_output_name("a.tiff", 8L, 1L, 1L, 1L), "a_8_1_1_1.tif"))

cat("\n")
if (failures > 0L) {
  cat("FAILED (", failures, " check(s))\n", sep = "")
  quit(status = 1L)
}
cat("All checks passed.\n")
