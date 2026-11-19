## ---------------------------------------------------------------------------
## RMSPA - version check and in-app update
## ---------------------------------------------------------------------------
## The released plugin version is published in r/VERSION on the main branch of
## the MSPA-plugins repository. The check is best effort: it never blocks the
## application and it is silent when the network is unavailable.
##
## Update layout
##   repository : https://github.com/vogtpet/MSPA-plugins
##   version    : https://raw.githubusercontent.com/vogtpet/MSPA-plugins/main/r/VERSION
##   release    : https://github.com/vogtpet/MSPA-plugins/releases/tag/r-v<version>
##   asset      : .../releases/download/r-v<version>/RMSPA-<version>.zip
## ---------------------------------------------------------------------------

RMSPA_REPO <- "vogtpet/MSPA-plugins"

rmspa_update_url <- function() {
  Sys.getenv("RMSPA_UPDATE_URL", unset = paste0(
    "https://raw.githubusercontent.com/", RMSPA_REPO, "/main/r/VERSION"))
}

rmspa_release_tag <- function(version) paste0("r-v", version)

rmspa_release_url <- function(version) {
  sprintf("https://github.com/%s/releases/tag/%s",
          RMSPA_REPO, rmspa_release_tag(version))
}

rmspa_download_url <- function(version) {
  sprintf("https://github.com/%s/releases/download/%s/RMSPA-%s.zip",
          RMSPA_REPO, rmspa_release_tag(version), version)
}

rmspa_cache_dir <- function() {
  dir <- tryCatch(tools::R_user_dir("MSPA-plugins", "cache"),
                  error = function(e) file.path(tempdir(), "mspa-plugins-cache"))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

## Fetch the released version. Returns a version string or NULL.
rmspa_fetch_version <- function(timeout = 5) {
  old <- getOption("timeout")
  options(timeout = timeout)
  on.exit(options(timeout = old), add = TRUE)

  url <- rmspa_update_url()
  ## Bust the CDN cache for the plain-text version file. file:// and other
  ## local sources do not support a query string.
  if (grepl("^https?://", url)) url <- paste0(url, "?t=", as.integer(Sys.time()))
  con <- suppressWarnings(tryCatch(url(url, open = "rt", encoding = "UTF-8"),
                                   error = function(e) NULL))
  if (is.null(con)) return(NULL)
  on.exit(suppressWarnings(try(close(con), silent = TRUE)), add = TRUE)

  ## A 404 (for example before the first release) or an offline machine only
  ## warns here; the caller treats the empty result as "no information".
  lines <- suppressWarnings(tryCatch(readLines(con, n = 1L, warn = FALSE),
                                     error = function(e) character()))
  if (length(lines) == 0L) return(NULL)
  version <- trimws(sub("^\ufeff", "", lines[1]))
  if (!grepl("^[0-9]+(\\.[0-9]+)*$", version)) return(NULL)
  version
}

## Cached version lookup. Uses a 24 h cache and falls back to a stale value
## when the network is unavailable.
rmspa_remote_version <- function(max_age = 24 * 3600, refresh = FALSE) {
  cache <- file.path(rmspa_cache_dir(), "r-version.rds")
  stored <- suppressWarnings(tryCatch(readRDS(cache), error = function(e) NULL))

  if (!refresh && !is.null(stored$version) && !is.null(stored$time)) {
    age <- as.numeric(difftime(Sys.time(), stored$time, units = "secs"))
    if (is.finite(age) && age >= 0 && age < max_age) return(stored$version)
  }

  version <- rmspa_fetch_version()
  if (!is.null(version)) {
    try(saveRDS(list(version = version, time = Sys.time()), cache), silent = TRUE)
    return(version)
  }

  if (!is.null(stored$version)) return(stored$version)
  NULL
}

## Compare the installed version with the released version.
## Returns list(ok, available, current, latest, notes_url, download_url).
check_for_update <- function(current, refresh = FALSE, max_age = 24 * 3600) {
  latest <- rmspa_remote_version(max_age = max_age, refresh = refresh)
  if (is.null(latest)) {
    return(list(ok = FALSE, available = FALSE, current = current,
                message = "Could not reach GitHub. Please check your internet connection."))
  }
  available <- utils::compareVersion(latest, current) > 0
  list(ok = TRUE, available = available, current = current, latest = latest,
       notes_url = rmspa_release_url(latest),
       download_url = rmspa_download_url(latest),
       message = if (available) {
         sprintf("RMSPA %s is available (installed: %s).", latest, current)
       } else {
         sprintf("RMSPA %s is the latest version.", current)
       })
}

## Download and unpack a released version next to the running installation.
## Returns the path of the new application folder.
install_update <- function(version, app_dir, dest_root = NULL) {
  stopifnot(nzchar(version), dir.exists(app_dir))

  if (is.null(dest_root)) dest_root <- dirname(normalizePath(app_dir))
  dir.create(dest_root, recursive = TRUE, showWarnings = FALSE)
  if (file.access(dest_root, 2L) != 0L) {
    dest_root <- tryCatch(tools::R_user_dir("MSPA-plugins", "data"),
                          error = function(e) file.path(path.expand("~"), "MSPA-plugins"))
    dir.create(dest_root, recursive = TRUE, showWarnings = FALSE)
    if (file.access(dest_root, 2L) != 0L) {
      stop("No writable location found for the update.")
    }
  }

  zipfile <- tempfile(fileext = ".zip")
  stage <- tempfile("rmspa-update-")
  on.exit(unlink(c(zipfile, stage), recursive = TRUE), add = TRUE)

  old <- getOption("timeout")
  options(timeout = 600)
  on.exit(options(timeout = old), add = TRUE)

  utils::download.file(rmspa_download_url(version), zipfile,
                       mode = "wb", quiet = TRUE)
  if (!file.exists(zipfile) || file.size(zipfile) == 0) {
    stop("The update archive could not be downloaded.")
  }

  contents <- utils::unzip(zipfile, list = TRUE)
  if (!all(startsWith(contents$Name, "RMSPA/"))) {
    stop("The update archive has an unexpected layout.")
  }
  if (!"RMSPA/VERSION" %in% contents$Name) {
    stop("The update archive does not contain a VERSION file.")
  }

  dir.create(stage)
  utils::unzip(zipfile, exdir = stage)

  root <- file.path(stage, "RMSPA")
  installed <- read_first_line(file.path(root, "VERSION"))
  if (!identical(installed, version)) {
    stop(sprintf("The update archive contains version %s instead of %s.",
                 installed, version))
  }

  dest <- file.path(dest_root, paste0("RMSPA-", version))
  suffix <- 1L
  while (file.exists(dest)) {
    dest <- file.path(dest_root, sprintf("RMSPA-%s-%d", version, suffix))
    suffix <- suffix + 1L
  }

  moved <- suppressWarnings(file.rename(root, dest))
  if (!isTRUE(moved)) {
    if (!isTRUE(suppressWarnings(file.copy(root, dest, recursive = TRUE)))) {
      stop("The update could not be moved to its destination.")
    }
  }

  if (.Platform$OS.type != "windows") {
    bins <- list.files(file.path(dest, "resources"), recursive = TRUE,
                       full.names = TRUE)
    bins <- bins[!grepl("\\.(dylib|txt)$", bins, ignore.case = TRUE)]
    if (length(bins) > 0L) {
      try(Sys.chmod(bins, mode = "0755", use_umask = FALSE), silent = TRUE)
    }
  }

  normalizePath(dest, mustWork = FALSE)
}
