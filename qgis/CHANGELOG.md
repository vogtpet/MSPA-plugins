# Changelog

MSPA QGIS 3 plugin versions follow [Semantic Versioning](https://semver.org/)
and are independent of the MSPA version. The MSPA version wrapped by a release
is stored in `MSPA_VERSION`; the binary release it is taken from is in
`MSPA_RELEASE`.

## [2.2.4] - 2026-11-26

### Added

* Plain TIFF inputs without a coordinate reference system are accepted. MSPA
  operates in pixel space; the result is written without georeferencing.
  GeoTIFF inputs still get their coordinate system and extent restored.

### Changed

* The input filter and documentation now say TIFF instead of GeoTIFF.

## [2.2.3] - 2026-11-26

### Fixed

* The Fedora 45 / QGIS 4 crash when selecting the input image persisted even
  with `DontUseNativeDialog`, `DontUseCustomDirectoryIcons` and an empty icon
  provider, because `QFileDialog` itself still asks the GTK icon theme for
  icons. On **Linux**, the plugin now uses its own small file/folder picker
  built from `QLineEdit`, `QListWidget` and `QPushButton`; it never creates a
  `QFileDialog` and never requests themed icons. Windows and macOS keep their
  native dialogs.

### Changed

* The Linux picker lists folders and `.tif`/`.tiff` files, with **Up** and
  **Home** buttons; the path field remains editable.

## [2.2.2] - 2026-11-26

### Fixed

* QGIS 4 on Fedora 45 still crashed when the file dialog was opened, even
  with `DontUseNativeDialog` and without the GTK platform theme: Qt's file
  dialog asked the platform icon theme for file and folder icons, and the
  GTK icon loader (`glycin` via `bwrap`) aborted the process with an
  out-of-memory error. The input and output dialogs now use an empty
  `QFileIconProvider`, so no themed icons are requested, in addition to
  `DontUseNativeDialog` and `DontUseCustomDirectoryIcons`.

### Added

* The path field can be edited directly. Pressing Enter validates the path
  and enables **Start** without opening a file dialog, as a fallback for
  platforms where the dialog cannot be used.

## [2.2.1] - 2026-11-26

### Fixed

* QGIS 4 on Fedora 45 crashed when the input image was selected: the native
  GTK file dialog failed while loading its theme icons (`glycin`/`bwrap`,
  "Cannot allocate memory") and aborted QGIS. The plugin now uses Qt's own
  file dialogs (`DontUseNativeDialog`) for the input image and the output
  folder, which avoids the GTK dialog entirely.

### Changed

* The plugin menu entry is now **MSPA** (previously "Mspa"), in line with the
  acronym.

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
