## ---------------------------------------------------------------------------
## RMSPA - target detection and MSPA binary resolution
## ---------------------------------------------------------------------------
## RMSPA is a thin wrapper around the MSPA command line tool. The binaries are
## taken unchanged from the MSPAstandalone release named in MSPA_VERSION and
## stored per target below resources/:
##
##   resources/linux-x86_64/mspa_linux
##   resources/linux-aarch64/mspa_linux_ARM
##   resources/macos-arm64/mspa_macOS_ARM     (+ libdeflate, libLerc)
##   resources/windows-x86_64/mspa_win64.exe
##   resources/windows-arm64/mspa_win64_ARM.exe
##
## Supported targets follow MSPAstandalone. macOS on Intel is not supported.
## ---------------------------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) return(y)
  if (length(x) == 1L && is.na(x)) return(y)
  x
}

## Read the first non-empty line of a small text file.
read_first_line <- function(path, default = "") {
  if (!file.exists(path)) return(default)
  x <- tryCatch(readLines(path, n = 1L, warn = FALSE),
                error = function(e) character())
  if (length(x) == 0L) return(default)
  x <- trimws(x[1])
  if (nzchar(x)) x else default
}

## TRUE on Apple Silicon, including R running under Rosetta.
is_apple_silicon <- function() {
  if (!identical(Sys.info()[["sysname"]], "Darwin")) return(FALSE)
  if (identical(Sys.info()[["machine"]], "arm64")) return(TRUE)
  out <- tryCatch(
    suppressWarnings(system2("sysctl", c("-n", "hw.optional.arm64"),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  length(out) == 1L && identical(trimws(out), "1")
}

## Return the target name for the current machine, or NA if unsupported.
mspa_target <- function() {
  sys  <- Sys.info()[["sysname"]]
  mach <- Sys.info()[["machine"]]

  if (identical(sys, "Linux")) {
    if (grepl("^(aarch64|arm64)$", mach)) return("linux-aarch64")
    return("linux-x86_64")
  }

  if (identical(sys, "Darwin")) {
    ## macOS on Intel is no longer supported (MSPA 2.4 is built for arm64).
    return(if (is_apple_silicon()) "macos-arm64" else NA_character_)
  }

  if (identical(sys, "Windows")) {
    pa  <- toupper(Sys.getenv("PROCESSOR_ARCHITECTURE", unset = ""))
    paw <- toupper(Sys.getenv("PROCESSOR_ARCHITEW6432", unset = ""))
    if (identical(pa, "ARM64") || identical(paw, "ARM64") ||
        grepl("arm64|aarch64", R.version$arch, ignore.case = TRUE)) {
      return("windows-arm64")
    }
    return("windows-x86_64")
  }

  NA_character_
}

mspa_target_label <- function(target) {
  switch(as.character(target),
    "linux-x86_64"   = "Linux x86_64",
    "linux-aarch64"  = "Linux aarch64",
    "macos-arm64"    = "macOS Apple Silicon",
    "windows-x86_64" = "Windows x86_64",
    "windows-arm64"  = "Windows ARM64",
    as.character(target)
  )
}

mspa_binary_name <- function(target) {
  switch(as.character(target),
    "linux-x86_64"   = "mspa_linux",
    "linux-aarch64"  = "mspa_linux_ARM",
    "macos-arm64"    = "mspa_macOS_ARM",
    "windows-x86_64" = "mspa_win64.exe",
    "windows-arm64"  = "mspa_win64_ARM.exe",
    NA_character_
  )
}

mspa_binary <- function(app_dir, target = mspa_target()) {
  if (is.na(target)) return(NA_character_)
  file.path(app_dir, "resources", target, mspa_binary_name(target))
}

## Make the bundled executable runnable (zip archives do not always keep the
## executable bit) and report whether execution is possible.
mspa_make_executable <- function(path) {
  if (is.na(path) || !file.exists(path)) return(FALSE)
  if (file.access(path, mode = 1L) == 0L) return(TRUE)
  if (.Platform$OS.type != "windows") {
    try(Sys.chmod(path, mode = "0755", use_umask = FALSE), silent = TRUE)
  }
  file.access(path, mode = 1L) == 0L
}

unsupported_platform_message <- function() {
  sys <- Sys.info()[["sysname"]]
  if (identical(sys, "Darwin")) {
    return(paste0(
      "This version of RMSPA does not support macOS on Intel processors.\n\n",
      "The MSPA 2.4 reference builds are available for macOS Apple Silicon, ",
      "Linux (x86_64 and aarch64) and Windows (x86_64 and ARM64). ",
      "On an Intel Mac please use GuidosToolbox (GTB) or GuidosToolbox ",
      "Workbench (GWB)."
    ))
  }
  paste0(
    "The operating system '", sys, "' is not supported.\n\n",
    "Supported systems: Linux, macOS (Apple Silicon) and Windows ",
    "(both x86_64 and ARM64)."
  )
}

mspa_failure_hint <- function(target) {
  if (identical(target, "macos-arm64")) {
    return(paste0(
      "The bundled MSPA binary could not be started. Possible reasons:\n",
      "  - macOS quarantined the downloaded executable. Remove the quarantine\n",
      "    flag with:\n",
      "      xattr -dr com.apple.quarantine <RMSPA folder>\n",
      "  - the binary was built for a newer version of macOS than the one\n",
      "    installed on this Mac."
    ))
  }
  if (grepl("^windows", target)) {
    return(paste0(
      "The bundled MSPA binary could not be started. Check whether your ",
      "antivirus or Windows SmartScreen blocked the executable."
    ))
  }
  "The bundled MSPA binary could not be started."
}

## macOS: remove the quarantine flag from the bundled binaries. The MSPA
## executable and its libraries are downloaded inside the release archive and
## are not notarised, so Gatekeeper would otherwise refuse to start them.
## This is the same as running
##   xattr -dr com.apple.quarantine <RMSPA>/resources
## once by hand.
mspa_clear_quarantine <- function(path) {
  if (!identical(Sys.info()[["sysname"]], "Darwin")) return(invisible(FALSE))
  xattr <- "/usr/bin/xattr"
  if (!file.exists(xattr) || !file.exists(path)) return(invisible(FALSE))
  status <- suppressWarnings(tryCatch(
    system2(xattr, c("-dr", "com.apple.quarantine", shQuote(path)),
            stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  ))
  invisible(is.null(status) || identical(as.integer(status), 0L))
}

## Resolve the binary for this machine and check that it runs.
## Returns a list with ok, target, binary, version and detail.
mspa_runtime <- function(app_dir, expected_version = NULL) {
  target <- mspa_target()
  out <- list(ok = FALSE, target = target, binary = NA_character_,
              version = NA_character_, detail = "")

  if (is.na(target)) {
    out$detail <- unsupported_platform_message()
    return(out)
  }

  binary <- mspa_binary(app_dir, target)
  out$binary <- binary

  if (identical(Sys.info()[["sysname"]], "Darwin")) {
    mspa_clear_quarantine(file.path(app_dir, "resources"))
  }

  if (!file.exists(binary)) {
    hint <- ""
    if (dir.exists(file.path(app_dir, ".git")) ||
        !dir.exists(file.path(app_dir, "resources"))) {
      hint <- paste0(
        "\n\nThis looks like a source checkout: the MSPA binaries are not stored ",
        "in the Git repository. Download them with\n",
        "  ./scripts/fetch-binaries.sh\n",
        "or install RMSPA from the official release archive.")
    }
    out$detail <- sprintf(
      "The MSPA binary for %s is missing:\n  %s%s",
      mspa_target_label(target), binary, hint
    )
    return(out)
  }

  if (!mspa_make_executable(binary)) {
    out$detail <- sprintf(
      "The MSPA binary is not executable:\n  %s\n\nMake it executable with:\n  chmod 755 '%s'",
      binary, binary
    )
    return(out)
  }

  res <- tryCatch(
    suppressWarnings(system2(binary, "-h", stdout = TRUE, stderr = TRUE)),
    error = function(e) structure(conditionMessage(e), status = 127L)
  )
  status <- attr(res, "status") %||% 0L
  text <- paste(res, collapse = "\n")

  if (status != 0L || !grepl("Morphological Spatial Pattern Analysis", text)) {
    out$detail <- paste0(mspa_failure_hint(target),
                         if (nzchar(text)) paste0("\n\n", text) else "")
    return(out)
  }

  version <- regmatches(text, regexpr("Version [0-9]+\\.[0-9]+", text))
  out$version <- if (length(version) == 1L) sub("^Version ", "", version) else ""

  if (!is.null(expected_version) && nzchar(expected_version) &&
      nzchar(out$version) && !identical(out$version, expected_version)) {
    out$detail <- sprintf(
      "The bundled MSPA binary reports version %s but version %s is expected.\nThe installation may be incomplete.",
      out$version, expected_version
    )
    return(out)
  }

  out$ok <- TRUE
  out
}
