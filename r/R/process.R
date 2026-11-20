## ---------------------------------------------------------------------------
## RMSPA - input validation and MSPA processing
## ---------------------------------------------------------------------------
## mspa_inspect()  validates an input image and returns the information shown
##                 in the user interface.
## mspa_process()  runs the complete pipeline
##
##                   input -> staging GeoTIFF -> mspa -> result GeoTIFF
##
## All intermediate files live in a temporary directory, so RMSPA can be
## installed in a read-only location and several users can work in parallel.
## No external GDAL command line tools are needed: terra provides GDAL.
## ---------------------------------------------------------------------------

MSPA_MAX_PIXELS  <- 4e8   # upper limit for the Shiny interface
MSPA_DISK_PIXELS <- 65e6  # above this, -disk (low memory) is used automatically
MSPA_CLASS_MAX   <- 220   # highest class code produced by MSPA 2.4
MSPA_NODATA      <- 255   # not used by MSPA; declared as NoData in the output

mspa_crs_label <- function(r) {
  d <- tryCatch(terra::crs(r, describe = TRUE), error = function(e) NULL)
  if (!is.null(d) && nrow(d) == 1L && !is.na(d$code) && nzchar(d$authority)) {
    return(sprintf("%s:%s", d$authority, d$code))
  }
  if (!nzchar(terra::crs(r))) return("none")
  name <- tryCatch(d$name, error = function(e) NULL)
  if (!is.null(name) && length(name) == 1L && !is.na(name) && nzchar(name)) name else "defined"
}

## Validate a SpatRaster for MSPA. Returns list(ok, message, info).
mspa_check_raster <- function(r, encoding = c("gtb", "mask"),
                              max_pixels = MSPA_MAX_PIXELS) {
  encoding <- match.arg(encoding)

  if (terra::nlyr(r) != 1L) {
    return(list(ok = FALSE, message = sprintf(
      "The image has %d bands. MSPA requires a single-band image.",
      terra::nlyr(r))))
  }

  datatype <- terra::datatype(r)
  if (!datatype %in% c("INT1U", "INT1S")) {
    return(list(ok = FALSE, message = sprintf(
      paste0("The image data type is %s. MSPA requires an 8-bit (byte) ",
             "image."), datatype)))
  }

  if (!nzchar(terra::crs(r))) {
    return(list(ok = FALSE, message = paste0(
      "The image has no coordinate reference system. ",
      "Please use a georeferenced GeoTIFF.")))
  }

  ncell <- terra::ncell(r)
  if (is.na(ncell) || ncell < 1) {
    return(list(ok = FALSE, message = "The image is empty."))
  }
  if (ncell > max_pixels) {
    return(list(ok = FALSE, message = sprintf(
      paste0("The image has %.1f million pixels, which is above the limit of ",
             "%.0f million pixels for this interface. Use the MSPA standalone ",
             "tool or GuidosToolbox for very large images."),
      ncell / 1e6, max_pixels / 1e6)))
  }

  freq <- tryCatch(terra::freq(r), error = function(e) NULL)
  if (is.null(freq) || nrow(freq) == 0L) {
    return(list(ok = FALSE, message = "The pixel values of the image could not be read."))
  }
  freq <- freq[!is.na(freq$value), , drop = FALSE]
  values <- sort(unique(freq$value))

  if (any(values < 0) || any(values > 2)) {
    shown <- paste(utils::head(values, 8), collapse = ", ")
    if (length(values) > 8L) shown <- paste0(shown, ", ...")
    return(list(ok = FALSE, message = sprintf(
      paste0("The image contains pixel values other than 0, 1 and 2 (found: %s). ",
             "MSPA requires a binary image. Please binarize the image first."),
      shown)))
  }

  fg_value <- if (identical(encoding, "gtb")) 2 else 1
  if (!fg_value %in% values) {
    if (identical(encoding, "gtb") && 1 %in% values) {
      msg <- paste0(
        "The image contains no foreground (value 2). MSPA uses the GTB encoding ",
        "1 = background and 2 = foreground.\n\n",
        "This looks like a 0/1 mask: switch 'Input encoding' to ",
        "'Binary mask (0/1)' to use it.")
    } else if (identical(encoding, "mask") && 2 %in% values) {
      msg <- paste0(
        "The image contains the value 2, so it is already GTB-encoded ",
        "(1 = background, 2 = foreground).\n\n",
        "Please switch 'Input encoding' to 'GTB (1/2)'.")
    } else {
      msg <- sprintf(
        "The image contains no foreground pixels (value %d).", fg_value)
    }
    return(list(ok = FALSE, message = msg))
  }

  fg_count <- sum(freq$count[freq$value == fg_value])
  info <- list(
    rows = terra::nrow(r),
    cols = terra::ncol(r),
    ncell = ncell,
    datatype = datatype,
    crs = mspa_crs_label(r),
    encoding = encoding,
    values = freq[, c("value", "count"), drop = FALSE],
    foreground = fg_count,
    disk = ncell > MSPA_DISK_PIXELS
  )
  list(ok = TRUE, message = "ok", info = info)
}

mspa_ext_message <- function(name) {
  ext <- tolower(tools::file_ext(name))
  if (!ext %in% c("tif", "tiff")) {
    return(paste0(
      "The selected file is not a GeoTIFF (.tif or .tiff). ",
      "MSPA requires a single-band GeoTIFF."))
  }
  NULL
}

## Validate an input file. Returns list(ok, message, info).
mspa_inspect <- function(path, encoding = c("gtb", "mask"),
                         name = NULL, max_pixels = MSPA_MAX_PIXELS) {
  encoding <- match.arg(encoding)

  if (!is.null(name)) {
    msg <- mspa_ext_message(name)
    if (!is.null(msg)) return(list(ok = FALSE, message = msg))
  }

  if (!file.exists(path)) {
    return(list(ok = FALSE, message = "The selected file could not be read."))
  }

  r <- tryCatch(terra::rast(path), error = function(e) NULL)
  if (is.null(r)) {
    return(list(ok = FALSE, message = paste0(
      "The selected file could not be opened as a raster image. ",
      "Please use a single-band GeoTIFF.")))
  }

  mspa_check_raster(r, encoding = encoding, max_pixels = max_pixels)
}

## Name of the result file. The parameters are part of the name, so the same
## input and settings always produce the same file name.
mspa_output_name <- function(input_name, graphfg = 8L, eew = 1L,
                             transition = 1L, internal = 1L) {
  base <- tools::file_path_sans_ext(basename(input_name))
  if (!nzchar(base)) base <- "mspa"
  sprintf("%s_%d_%d_%d_%d.tif", base,
          as.integer(graphfg), as.integer(eew),
          as.integer(transition), as.integer(internal))
}

## Run MSPA on one image.
##
## binary     path to the MSPA executable (see mspa_binary())
## input_name original file name, used for the output file name
##
## Returns list(ok, message, outfile, params, disk, classes).
mspa_process <- function(input, outdir,
                         graphfg = 8L, eew = 1L, transition = 1L, internal = 1L,
                         encoding = c("gtb", "mask"), binary,
                         input_name = basename(input),
                         max_pixels = MSPA_MAX_PIXELS, low_mem = FALSE) {
  encoding <- match.arg(encoding)
  params <- list(graphfg = as.integer(graphfg), eew = as.integer(eew),
                 transition = as.integer(transition), internal = as.integer(internal))

  fail <- function(message) {
    list(ok = FALSE, message = message, outfile = NULL, params = params)
  }

  if (!file.exists(input)) {
    return(fail("The input image could not be found."))
  }
  if (!dir.exists(outdir)) {
    return(fail(sprintf("The output folder does not exist:\n  %s", outdir)))
  }
  if (file.access(outdir, 2L) != 0L) {
    return(fail(sprintf("The output folder is not writable:\n  %s", outdir)))
  }
  if (is.na(binary) || !file.exists(binary)) {
    return(fail("The MSPA executable is missing. Please reinstall RMSPA."))
  }

  ## Work with absolute paths before changing the working directory.
  input <- normalizePath(input, mustWork = FALSE)
  outdir <- normalizePath(outdir, mustWork = FALSE)
  binary <- normalizePath(binary, mustWork = FALSE)

  tmp <- tempfile("rmspa-")
  if (!dir.create(tmp)) {
    return(fail("Could not create a temporary working directory."))
  }
  on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)

  ## MSPA is started from the temporary directory with short, relative file
  ## names. This keeps the command line independent of the depth of the
  ## temporary directory and of the length of the user's path.
  old_wd <- getwd()
  setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)

  src <- tryCatch(terra::rast(input), error = function(e) NULL)
  if (is.null(src)) {
    return(fail("The input image could not be read. Please use a GeoTIFF."))
  }

  check <- mspa_check_raster(src, encoding = encoding, max_pixels = max_pixels)
  if (!check$ok) return(fail(check$message))

  ## Normalise the input. Missing data becomes 0. A 0/1 mask is recoded to the
  ## GTB convention: 0 -> 1 (background), 1 -> 2 (foreground).
  ## The staging file is a plain GeoTIFF without overviews that the MSPA TIFF
  ## reader can always handle.
  values <- if (identical(encoding, "mask")) {
    terra::ifel(is.na(src), 0, terra::ifel(src == 1, 2, 1))
  } else {
    terra::ifel(is.na(src), 0, src)
  }
  stage <- "input.tif"
  err <- tryCatch({
    terra::writeRaster(values, stage, datatype = "INT1U", overwrite = TRUE,
                       gdal = c("TILED=NO", "COMPRESS=LZW"))
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err)) {
    return(fail(paste0("Could not prepare the input image:\n", err)))
  }

  disk <- isTRUE(low_mem) || terra::ncell(src) > MSPA_DISK_PIXELS
  args <- c("-i", "input.tif",
            "-o", "out.tif",
            "-odir", ".",
            "-graphfg", params$graphfg,
            "-eew", params$eew,
            "-transition", params$transition,
            "-internal", params$internal)
  if (disk) args <- c(args, "-disk")

  res <- tryCatch(
    suppressWarnings(system2(binary, args, stdout = TRUE, stderr = TRUE)),
    error = function(e) structure(conditionMessage(e), status = 127L)
  )
  status <- attr(res, "status") %||% 0L
  mspa_out <- "out.tif"

  if (status != 0L || !file.exists(mspa_out)) {
    log <- utils::tail(as.character(res), 15L)
    return(fail(paste0(
      "MSPA could not process the image (exit status ", status, ").",
      if (length(log) > 0L) paste0("\n\n", paste(log, collapse = "\n")) else "")))
  }

  rst <- tryCatch(suppressWarnings(terra::rast(mspa_out)), error = function(e) NULL)
  if (is.null(rst)) {
    return(fail("The MSPA output could not be read."))
  }

  ## Restore the georeference of the original image and add the GTB metadata
  ## that lets GTB reload the MSPA parameters.
  terra::crs(rst) <- terra::crs(src)
  terra::ext(rst) <- terra::ext(src)

  max_value <- tryCatch(terra::global(rst, "max", na.rm = TRUE)[[1, 1]],
                        error = function(e) NA_real_)
  if (!is.finite(max_value) || max_value >= MSPA_NODATA) {
    return(fail(sprintf(
      paste0("Unexpected pixel value in the MSPA output (maximum %s). ",
             "NoData would overwrite valid classes. Please report this."),
      max_value)))
  }

  p <- params
  tags <- c(
    TIFFTAG_DATETIME = format(Sys.time(), "%Y:%m:%d %H:%M:%S"),
    TIFFTAG_DOCUMENTNAME = "",
    TIFFTAG_IMAGEDESCRIPTION = sprintf(
      "GTB_MSPA, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/ %d_%d_%d_%d",
      p$graphfg, p$eew, p$transition, p$internal)
  )

  out_name <- mspa_output_name(input_name, p$graphfg, p$eew,
                               p$transition, p$internal)
  tags[["TIFFTAG_DOCUMENTNAME"]] <- out_name
  outfile <- file.path(outdir, out_name)

  final <- "final.tif"
  err <- tryCatch({
    ## metags() is available in terra >= 1.8; without it the GeoTIFF simply
    ## keeps the metadata written by MSPA itself.
    tryCatch(terra::metags(rst) <- tags, error = function(e) NULL)
    terra::writeRaster(rst, final, datatype = "INT1U", NAflag = MSPA_NODATA,
                       overwrite = TRUE,
                       gdal = c("TILED=NO", "COMPRESS=LZW"))
    unlink(paste0(final, ".aux.xml"))
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err)) {
    return(fail(paste0("The result image could not be created:\n", err)))
  }

  unlink(paste0(outfile, ".aux.xml"))
  copied <- suppressWarnings(file.copy(final, outfile, overwrite = TRUE))
  if (!isTRUE(copied)) {
    return(fail(sprintf("The result could not be written to:\n  %s", outfile)))
  }
  unlink(paste0(outfile, ".aux.xml"))

  classes <- tryCatch(terra::freq(rst), error = function(e) NULL)

  list(ok = TRUE, message = "ok", outfile = outfile, params = params,
       disk = disk, classes = classes,
       size = c(rows = terra::nrow(src), cols = terra::ncol(src)),
       crs = mspa_crs_label(src))
}
