# MSPA for QGIS 3 and 4

A single QGIS plugin for **MSPA** (Morphological Spatial Pattern Analysis),
wrapping the MSPA 2.4 command line tool from
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone). The same package
works in QGIS 3 (Qt5) and QGIS 4 (Qt6).

| | |
|---|---|
| **Plugin version** | 2.2.4 |
| **MSPA version** | 2.4 (release 2.4.1) |
| **Host** | QGIS 3.16 or newer, and QGIS 4 |

## Supported platforms

| System | Architecture | Notes |
|---|---|---|
| Windows | x86_64 | QGIS installed with the OSGeo4W installer |
| Windows | ARM64 | only when QGIS itself runs natively on ARM64; x86_64 QGIS on Windows ARM uses the x86_64 executable |
| Linux | x86_64 | glibc 2.31 or newer (Ubuntu 20.04+, Debian 11+, …) |
| Linux | aarch64 | |
| macOS | Apple Silicon | Intel Macs are not supported by MSPA 2.4 |

QGIS ships its own GDAL, so no external GDAL, Python package or compiler is
needed. The plugin is installed in the user profile and does not require
administrator rights.

## Installation

1. Download `MSPA-QGIS-2.2.4.zip` from the
   [QGIS release](https://github.com/vogtpet/MSPA-plugins/releases/tag/qgis-v2.2.4)
   and verify it against `SHA256SUMS` if you wish.
2. In QGIS open **Plugins → Manage and Install Plugins…**.
3. Select **Install from ZIP**, choose the downloaded ZIP file and click
   **Install Plugin**.
4. Open the **Installed** tab, search for **MSPA** and make sure it is
   enabled.
5. The plugin is available as the **MSPA** entry in the **Plugins** menu and
   as a toolbar button.

The same ZIP is used for QGIS 3 and QGIS 4. If an older JRC version of the
plugin is installed, disable or remove it in **Installed** before installing
this version; both use the plugin folder `mspa`.

### Manual installation

The ZIP contains the plugin folder `mspa` at its root. Copy that folder into
the QGIS profile's `python/plugins` directory, restart QGIS and enable
**MSPA**:

* Windows: `%APPDATA%\QGIS\QGIS3\profiles\default\python\plugins` (QGIS 3)
  or `%APPDATA%\QGIS\QGIS4\profiles\default\python\plugins` (QGIS 4)
* Linux: `~/.local/share/QGIS/QGIS3/profiles/default/python/plugins` (QGIS 3)
  or `~/.local/share/QGIS/QGIS4/profiles/default/python/plugins` (QGIS 4)
* macOS: `~/Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins`
  (QGIS 3) or `~/Library/Application Support/QGIS/QGIS4/profiles/default/python/plugins`
  (QGIS 4)

## Usage

1. Open the plugin from **Plugins → MSPA → Mspa**.
2. **Select** the input image. It must be a single-band 8-bit GeoTIFF with a
   coordinate reference system.
3. Choose the MSPA parameters (**FGconn**, **EdgeWidth**, **Transition**,
   **Intext**).
4. Click **Start**. The image is prepared, MSPA runs and the result is shown
   with the extent, coordinate system and classes of the input.
5. Save the result as a GeoTIFF and add it to the map, or close the dialog to
   discard it.

The **MSPA guide** button opens the bundled JRC guide; the **Plugin guide**
button opens this document on GitHub.

## Input

A single-band 8-bit TIFF or GeoTIFF using the GTB encoding:

| Value | Meaning |
|---|---|
| 0 | Missing / NoData (optional) |
| 1 | Background |
| 2 | Foreground |

Standard `0/1` masks have to be recoded to `1/2` (background/foreground)
before use; the R plugin (`RMSPA`) offers an automatic conversion, the QGIS
plugin does not.

A GeoTIFF normally carries a coordinate reference system. Plain TIFF files
without georeferencing are also accepted; they are processed in pixel space
and the result is written without a coordinate reference system.

### Maximum input size

The same limits as RMSPA and the ArcGIS plugin:

| Limit | Value |
|---|---|
| Maximum input | **400,000,000 pixels in total** (about 20,000 × 20,000 for a square image) |
| Low memory (`-disk`) | switched on automatically above **65,000,000 pixels** (about 8,000 × 8,000) |

Above 400 million pixels use the MSPA standalone tool or GuidosToolbox.

## Output

The result is written to the folder you select as

```
<input name>_<FGconn>_<EdgeWidth>_<Transition>_<Intext>.tif
```

for example `input_8_1_1_1.tif`. When the input is georeferenced, its spatial
reference and extent are restored; a plain TIFF stays unreferenced. The
LZW-compressed TIFF keeps the MSPA colour table and
the GTB metadata (`TIFFTAG_IMAGEDESCRIPTION=GTB_MSPA, ...`) used by
GuidosToolbox to reload the parameters. The layer is added to the current
project. An existing result with the same name is overwritten only after a
confirmation.

## Updates

The plugin checks `qgis/VERSION` in the `MSPA-plugins` repository when it is
opened and shows a message when a newer plugin version is available, with a
link to the release. Updating is manual: download the new ZIP and install it
with **Install from ZIP**; the settings and the profile stay unchanged.

## Known limitations

* MSPA 2.4 does not support Intel Macs. Use the MSPA standalone tool or the R
  plugin there.
* Linux x86_64 requires glibc 2.31 or newer; older distributions (for example
  CentOS 7) cannot run the bundled executable.
* Batch processing of several files is not available; use GTB or GWB for that.
* Only single-band 8-bit TIFF/GeoTIFF inputs with the GTB encoding are accepted.
* The plugin is tested with QGIS 3 and QGIS 4 on Windows, Linux (x86_64 and
  aarch64; Ubuntu, Debian, Fedora and openSUSE) and macOS Apple Silicon.
  Please report any issue on the
  [tracker](https://github.com/vogtpet/MSPA-plugins/issues).

## Troubleshooting

* **The plugin does not appear in the menu.** Check that **MSPA** is enabled
  in **Plugins → Manage and Install Plugins → Installed** and that QGIS is
  version 3.16 or newer.
* **"The MSPA executable is missing"** – the ZIP was not installed completely.
  Reinstall it with **Install from ZIP** instead of copying individual files.
* **The file picker on Linux** is QGIS-independent and text-only by
  design, so that it cannot trigger GTK icon-theme crashes. The path field
  is editable; press Enter to validate a path without browsing.
* **macOS cannot start the bundled executable** after extracting the ZIP with
  Finder: Gatekeeper has quarantined the file. Install the ZIP through QGIS
  (which does not copy the quarantine flag), or remove the flag from the
  plugin folder with
  `xattr -dr com.apple.quarantine <profile>/python/plugins/mspa`.
* **Linux reports a GLIBC version error** – the distribution is older than
  glibc 2.31. Use a newer distribution, the standalone tool or the R plugin.
* **MSPA reports an error for a valid-looking image** – export the input as an
  uncompressed TIFF with the 0/1/2 encoding and try again; the message box
  shows MSPA's own output.

## Development

```sh
cd qgis
./scripts/fetch-resources.sh   # MSPA 2.4.1 binaries for all platforms, guide
./scripts/build-release.sh     # dist/MSPA-QGIS-<version>.zip + SHA256SUMS
```

The MSPA executables are not stored in Git; the build workflow fetches them
from the MSPAstandalone release named in `MSPA_RELEASE` (engine version in
`MSPA_VERSION`) and verifies the published SHA-256 checksums.

`VERSION`, the `version=` line of `mspa/metadata.txt` and `PLUGIN_VERSION` in
`mspa/mspa.py` must match; the build script checks this.

The code uses the `qgis.PyQt` compatibility layer and a small set of shims for
Qt5/Qt6 differences (`QAction` location, scoped enums, `exec()`), so the same
package runs in QGIS 3 and QGIS 4.

## License

The QGIS plugin is free software: you can redistribute it and/or modify it
under the terms of the **GNU General Public License, version 3 or later**
(GPL-3.0-or-later). See [../LICENSE](../LICENSE) for the full text.

The MSPA binaries are built and distributed by the European Commission's Joint
Research Centre under the same licence. See
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone#license).

The binaries link `libdeflate` (MIT) and `Lerc` (Apache-2.0) statically; the
notices are in [`mspa/third-party-licenses/`](mspa/third-party-licenses/) and
are included in the release archive.
