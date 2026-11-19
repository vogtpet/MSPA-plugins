# Changelog

RMSPA plugin versions follow [Semantic Versioning](https://semver.org/) and
are independent of the MSPA version. The MSPA version wrapped by a release is
stored in `MSPA_VERSION`.

## [2.2.1] - 2026-11-19

### Fixed

* Finishing a job crashed the application with
  `Error in session$sendModal("remove", NULL): attempt to apply non-function`.
  The job runs in a `later::later()` callback, where no default reactive domain
  is active; `removeModal()`, `showModal()` and `shinyjs` now receive the
  session explicitly (or are replaced by a reactive busy flag).
* The startup version check no longer prints warnings when the cache file does
  not exist yet or when the version file is unavailable (for example a 404
  before the first release).

## [2.2.0] - 2026-11-19

First release from the `MSPA-plugins` repository. Based on the 2.1 plugin
released by the JRC, with the following changes.

### Added

* Support for Linux aarch64 and Windows ARM64. The Linux x86_64 binary is now
  the glibc 2.31 compatibility build from MSPAstandalone.
* Input encoding selector: GTB encoding (1 = background, 2 = foreground) or a
  plain 0/1 binary mask (converted to the GTB encoding before processing).
* Update check against the `MSPA-plugins` repository, with download and
  unpacking of the new version next to the current installation.
* Startup self-test of the bundled MSPA binary with actionable error messages
  (missing file, missing execute permission, macOS quarantine, wrong version).
* Low memory mode (`-disk`), switched on automatically above 65 million
  pixels.
* The GTB metadata (`TIFFTAG_IMAGEDESCRIPTION`) is written by terra, together
  with the datetime and document name.

### Changed

* The MSPA binaries are taken unchanged from the official MSPAstandalone
  release (`MSPA_VERSION`). Provenance and checksums are listed in
  `resources/BINARIES.txt` inside the release archive.
* The output is written with terra only. A system GDAL installation is no
  longer required to run RMSPA.
* All intermediate files are written to a temporary directory, so RMSPA can be
  installed in a read-only location and several users can work in parallel.
* Validation uses `terra::freq()` instead of histogram heuristics and reports
  the actual problem (wrong encoding, wrong data type, values above 2,
  missing projection, image too large).
* The arbitrary 50 x 50 pixel minimum size was removed.
* Version comparison uses `utils::compareVersion()`, so 2.10 is newer than
  2.9.
* The output file name is derived with `tools::file_path_sans_ext()`.
* MSPA is started from a temporary working directory with short relative file
  names, so neither the location of the plugin nor a deep temporary folder can
  exceed the path limits of the MSPA build.
* The bundled MSPA version and the plugin version are displayed in the
  interface.

### Fixed

* The output GeoTIFF no longer declares `NoData = 0`, which made background
  pixels disappear in statistics and GIS software. NoData is now 255, a value
  that MSPA does not use.
* The Start button is no longer silently disabled for images without the
  foreground value 2; the interface now explains what to do.
* `.tiff` inputs no longer produce truncated output names.
* Paths containing spaces work on Windows (arguments are quoted).
* Errors from the MSPA process are reported with exit status and stderr
  instead of the generic "Unable to process the image".
* A failed run can no longer pick up the result of a previous run.

### Removed

* macOS on Intel processors. MSPA 2.4 is built for Apple Silicon, Linux
  (x86_64, aarch64) and Windows (x86_64, ARM64).
* The bundled GDAL 1.11.4 for Windows (`resources/gdal_win`, about 24 MB) and
  the dependency on the `gdal_translate` command line tool.
* The outdated `MSPA-extensionR.pdf`; the plugin guide in this repository is
  the current documentation. `MSPA_Guide.pdf` is still included.
* The JRC version endpoint; updates are checked on GitHub.
