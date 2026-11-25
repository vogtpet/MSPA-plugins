# Changelog

MSPA QGIS 3 plugin versions follow [Semantic Versioning](https://semver.org/)
and are independent of the MSPA version. The MSPA version wrapped by a release
is stored in `MSPA_VERSION`; the binary release it is taken from is in
`MSPA_RELEASE`.

## [2.2.0] - 2026-11-25

One plugin for QGIS 3 and QGIS 4.

### Added

* QGIS 4 (Qt6) support in the same package as QGIS 3 (Qt5), using the
  `qgis.PyQt` compatibility layer.
* `qgisMaximumVersion=4.99`, so the plugin is listed for QGIS 3.16+ and
  QGIS 4.x.

### Changed

* The plugin is now maintained in `qgis/` and released as
  `MSPA-QGIS-<version>.zip` with the tag prefix `qgis-v` (previously
  `qgis3/`, `MSPA-QGIS3-<version>.zip`, `qgis3-v`).
* Qt5/Qt6 compatibility shims for the `QAction` location, scoped
  `QMessageBox` enums, `WindowModality` and `exec()`.
* Compiled Qt resources were removed; the window and button icons are loaded
  from `icon.png` and `help.png`, so the package is independent of PyQt5.

### Fixed

* The dialog no longer depends on `QDesktopWidget`, which was removed in Qt6.

## [2.1.1] - 2026-11-25

### Fixed

* Linux aarch64 (for example Ubuntu 26.10 or Debian 13 on ARM) was rejected
  with "MSPA does not support this platform: Linux aarch64". The architecture
  name is normalised to `arm64`, but the binary table still used `aarch64`.

## [2.1.0] - 2026-11-25

First release from the MSPA-plugins repository, based on the JRC QGIS plugin
version 2.0.

### Added

* MSPA 2.4.1 binaries for Windows x86_64 and ARM64, Linux x86_64 (glibc
  2.31 or newer) and aarch64, and macOS Apple Silicon. The correct executable
  is selected at runtime; the installer scripts with their `sed` rewrites are
  gone.
* The same limits as RMSPA and the ArcGIS plugin: 400 million pixels in
  total, with `-disk` switched on automatically above 65 million pixels.
* Update check against `qgis3/VERSION` in the MSPA-plugins repository, with a
  link to the GitHub release.
* The MSPA guide (`MSPA_Guide.pdf`) is bundled and opened offline from the
  dialog; the plugin guide opens the README on GitHub.
* Third-party license notices for libdeflate (MIT) and Lerc (Apache-2.0).

### Changed

* MSPA runs in a temporary folder instead of the plugin folder, so the plugin
  works when its folder is read-only and parallel runs do not overwrite each
  other's intermediate files.
* The input is normalised with the GDAL bindings shipped with QGIS; the
  output is a LZW-compressed GeoTIFF with the extent, coordinate system,
  colour table and GTB metadata (`TIFFTAG_IMAGEDESCRIPTION=GTB_MSPA, ...`)
  restored.
* Existing results are overwritten only after a confirmation.
* Errors, including MSPA's own output, are reported in a message box.

### Fixed

* The dialog is no longer disconnected after it is closed, so the plugin can
  be used more than once per QGIS session.
* Running MSPA no longer depends on the current working directory or on a
  hard-coded `mspa_win64.exe`.
* The input validation did not detect images without foreground correctly.

### Removed

* The platform installer scripts and the Plugin Builder files (`help/`,
  `i18n/`, `scripts/`, `test/`, `Makefile`, `pb_tool.cfg`,
  `plugin_upload.py`, `pylintrc`).
