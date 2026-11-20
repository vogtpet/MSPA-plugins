# Changelog

RMSPA plugin versions follow [Semantic Versioning](https://semver.org/) and
are independent of the MSPA version. The MSPA version wrapped by a release is
stored in `MSPA_VERSION`.

## [2.2.10] - 2026-11-20

### Fixed

* Confirming *Overwrite* failed with `Can't access reactive value
  'pending_job' outside of reactive consumer`: the job description was passed
  to the job starter as a lazy promise and evaluated inside the `later()`
  callback. It is now forced inside the observer.

## [2.2.9] - 2026-11-20

### Added

* Before a job starts, RMSPA checks whether a result with the same name already
  exists (same input name and parameters) and asks for confirmation. The dialog
  offers *Overwrite* and *Cancel* and can remember the choice for the rest of
  the session.

## [2.2.8] - 2026-11-20

### Changed

* The macOS ARM binaries were rebuilt with a **macOS 11** deployment target
  (MSPAstandalone release v2.4.1 instead of v2.4); the previous bundle required
  macOS 27. `libdeflate` and `Lerc` are now linked statically, so the macOS
  application folder contains only the executable.
* Binary downloads use the new `MSPA_RELEASE` file (release tag of the archives)
  while `MSPA_VERSION` remains the engine version (2.4) used by the startup
  check.

## [2.2.7] - 2026-11-20

### Fixed

* Windows ARM: the native ARM64 system is now detected through
  `PROCESSOR_IDENTIFIER`, so `mspa_win64_ARM.exe` is used also when R/RStudio
  run as x86_64 under emulation. Previously the x86_64 executable was selected
  in that configuration.

### Changed

* The update check runs at every start instead of using the 24 h cache. The
  cached version is only used when GitHub cannot be reached, so the "Update
  available" dialog appears at the next start after a release.

## [2.2.6] - 2026-11-20

### Added

* macOS: the `com.apple.quarantine` flag is removed from the bundled binaries
  (`resources/`) automatically at startup, so the manual `xattr` command is no
  longer required.
* The Help panel shows the detected MSPA target and the architecture of the
  running R session.

### Fixed

* Windows: the drive list no longer produces the `shinyFiles` warning when a
  drive has no volume label, and the affected drive labels are repaired.

### Documentation

* Linux: system packages needed to compile `terra` on Debian/Ubuntu, Fedora and
  openSUSE, plus the distributions on which the plugin has been tested.

## [2.2.5] - 2026-11-19

### Fixed

* The *Release notes* button in the update dialog opened an empty window
  titled "rstudio" (a `target="_blank"` link in RStudio's viewer). It now uses
  `browseURL()` like the guide and GuidosToolbox links. A test guards against
  `target="_blank"` links in the application.

## [2.2.4] - 2026-11-19

### Fixed

* The update installer now chooses the destination by actually creating the
  staging directory instead of relying on `file.access()`, falling back to the
  per-user data directory (`tools::R_user_dir()`) and then to the temporary
  directory. This covers read-only parents (for example an installation in
  `/opt`, or an app placed directly in `$HOME`) and file systems where the
  access check is unreliable. `tests/update-test.R` covers the fallback.

## [2.2.3] - 2026-11-19

### Fixed

* The update installer failed with "The update could not be moved to its
  destination" when the temporary directory is on a different filesystem (for
  example tmpfs `/tmp` on Linux). The archive is now unpacked next to the
  installation, and the copy fallback creates the destination folder before
  copying (R's `file.copy()` does not create a missing destination).
* Added a regression test for the installer (`tests/update-test.R`), run in CI.

## [2.2.2] - 2026-11-19

### Fixed

* Processing failed with `Can't access reactive value 'encoding' outside of
  reactive consumer`: the job callback read `input$...` after the reactive
  domain had ended. The parameters are now captured before the job starts.
* The *Plugin guide* and *MSPA guide* buttons opened an empty window titled
  "rstudio" in RStudio. They now open the system browser via `browseURL()`,
  like the GuidosToolbox link.
* The release archive now contains the license text (`LICENSE`), the
  third-party notices (`THIRD-PARTY-NOTICES.md`) and the license texts of the
  bundled macOS libraries (`licenses/`).

### Changed

* The license section follows the wording of MSPAstandalone
  (GPL-3.0-or-later) and a third-party components section was added.

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
