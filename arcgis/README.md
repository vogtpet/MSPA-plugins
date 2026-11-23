# MSPA for ArcGIS

An ArcGIS toolbox for **MSPA** (Morphological Spatial Pattern Analysis),
wrapping the MSPA 2.4 command line tool from
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone).

| | |
|---|---|
| **Plugin version** | 2.2.0 |
| **MSPA version** | 2.4 (release 2.4.1) |
| **Host** | ArcGIS Pro or ArcGIS Desktop 10.3–10.9 (64-bit Windows) |

## Supported platform

Windows x86_64. ArcGIS Pro and ArcGIS Desktop are Windows applications; on
Windows ARM they run under emulation and use the x86_64 MSPA executable.

## Installation

1. Download `MSPA-ArcGIS-2.2.0.zip` from the
   [ArcGIS release](https://github.com/vogtpet/MSPA-plugins/releases/tag/arcgis-v2.2.0)
   and verify it against `SHA256SUMS` if you wish.
2. Extract the archive.
3. Run `install_MSPA-ToolboxArc_Windows.bat`. It copies the `mspa` folder to
   *My Toolboxes* for every detected ArcGIS Desktop installation and to
   `%USERPROFILE%\MSPA-Toolbox` for ArcGIS Pro.
4. **ArcGIS Pro:** open the Catalog pane, right-click **Toolboxes → Add
   Toolbox** and select `%USERPROFILE%\MSPA-Toolbox\MSPA.pyt`. ArcGIS Pro 3.x
   does not have the ArcMap *My Toolboxes* folder. To make the toolbox
   available in every new project, add it to your project template (for
   example `...\ArcGIS\Template\template.atbx`).
   **ArcGIS Desktop:** add `MSPA.pyt` to ArcToolbox (the installer copied it to
   *My Toolboxes*).

You can also copy the `mspa` folder manually to a folder of your choice and
add `MSPA.pyt` there.

## Input

A single-band 8-bit GeoTIFF with a coordinate reference system, using the GTB
encoding:

| Value | Meaning |
|---|---|
| 0 | Missing / NoData (optional) |
| 1 | Background |
| 2 | Foreground |

The input label in the tool states this encoding. Standard `0/1` masks have to
be recoded to `1/2` (background/foreground) before use; the R plugin
(`RMSPA`) offers an automatic conversion, the ArcGIS toolbox does not.

### Maximum input size

The same limits as RMSPA:

| Limit | Value |
|---|---|
| Maximum input | **400,000,000 pixels in total** (about 20,000 × 20,000 for a square image) |
| Low memory (`-disk`) | switched on automatically above **65,000,000 pixels** (about 8,000 × 8,000) |

The *Low memory mode (-disk)* parameter forces `-disk` for smaller images as
well. Above 400 million pixels use the MSPA standalone tool or GuidosToolbox.

## Output

The result is written to the selected folder as

```
<input name>_<FGconn>_<EdgeWidth>_<Transition>_<Intext>.tif
```

for example `input_8_1_1_1.tif`. The spatial reference of the input is
restored, the LZW-compressed GeoTIFF keeps the MSPA colour table and the GTB
metadata (`TIFFTAG_IMAGEDESCRIPTION=GTB_MSPA, ...`) used by GuidosToolbox to
reload the parameters. The layer is added to the current map (ArcGIS Pro) or
data frame (ArcGIS Desktop). An existing result with the same name is
overwritten after a warning in the tool messages.

## Updates

The toolbox checks `arcgis/VERSION` in the `MSPA-plugins` repository each time
it runs and adds a warning when a newer plugin version is available, with a
link to the release. Installation of a new version is manual: download the
archive, extract it and run the installer again.

## Known limitations

* **ArcGIS Pro** uses its built-in GDAL 3.x through the `osgeo` Python
  bindings for the TIFF conversion; no external GDAL or Visual C++ runtime is
  needed.
* **ArcGIS Desktop 10.x** has no `osgeo`; it falls back to the bundled legacy
  GDAL 1.11 (2017) `gdal_translate.exe`, which requires the Microsoft Visual
  C++ 2013 x64 Redistributable (`vcredist_x64.exe`). ArcGIS Desktop is legacy;
  ArcGIS Pro is recommended.
* Batch processing of several files is not available; use GTB or GWB for that.
* Windows x86_64 only; macOS and Linux are served by the R plugin and the
  standalone tool.

## Development

```sh
cd arcgis
./scripts/fetch-resources.sh   # MSPA 2.4.1 Windows binary, GDAL bundle, guide
./scripts/build-release.sh     # dist/MSPA-ArcGIS-<version>.zip + SHA256SUMS
```

The MSPA executable and the GDAL bundle are not stored in Git; the build
workflow fetches the current MSPA binary from the MSPAstandalone release named
in `MSPA_RELEASE` (engine version in `MSPA_VERSION`) and the legacy GDAL bundle
from the JRC ArcGIS archive.

## License

The ArcGIS toolbox is free software: you can redistribute it and/or modify it
under the terms of the **GNU General Public License, version 3 or later**
(GPL-3.0-or-later). See [../LICENSE](../LICENSE) for the full text.

The MSPA binaries are built and distributed by the European Commission's Joint
Research Centre under the same licence. See
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone#license).
