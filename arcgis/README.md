# MSPA for ArcGIS

An ArcGIS toolbox for **MSPA** (Morphological Spatial Pattern Analysis),
wrapping the MSPA 2.4 command line tool from
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone).

| | |
|---|---|
| **Plugin version** | 2.3.1 |
| **MSPA version** | 2.4 (release 2.4.1) |
| **Host** | ArcGIS Pro or ArcGIS Desktop 10.3–10.9 (64-bit Windows) |

## Supported platform

Windows x86_64. ArcGIS Pro and ArcGIS Desktop are Windows applications; on
Windows ARM they run under emulation and use the x86_64 MSPA executable.

## Installation

1. Download `MSPA-ArcGIS-2.3.1.zip` from the
   [ArcGIS release](https://github.com/vogtpet/MSPA-plugins/releases/tag/arcgis-v2.3.1)
   and verify it against `SHA256SUMS` if you wish.
2. Extract the archive to a **permanent** folder, for example
   `C:\Users\<user>\Documents\ArcGIS\MSPA-ArcGIS`. The `mspa` folder with
   `MSPA.pyt` and its `resources` must stay together; do not move only the
   `.pyt`.

Then follow the section for your host application.

### ArcGIS Pro

3. Open ArcGIS Pro and the **Catalog** pane (*View → Catalog Pane*).
4. Open **Favorites** and choose **Add Item → Toolbox**
   (or right-click **Favorites → Add Item → Toolbox**).
5. Browse to `...\MSPA-ArcGIS\mspa\MSPA.pyt` and add it.
6. The **MSPA** toolbox now appears under Favorites and is available in the
   project. Run the **MSPA** tool from there.

Alternatively, right-click **Toolboxes → Add Toolbox…**, select
`MSPA.pyt`, and then add the toolbox to Favorites.

ArcGIS Pro does not scan a special "My Toolboxes" folder, so adding the
toolbox to Favorites is the reliable installation.

### ArcGIS Desktop 10.3–10.9

3. Open the **ArcToolbox** window.
4. Right-click **ArcToolbox → Add Toolbox…**
5. Navigate to `...\MSPA-ArcGIS\mspa\MSPA.pyt` and select it.
6. The **MSPA Tools** toolbox now appears in the list of all available
   toolboxes. Run the **MSPA** tool from there.

If an earlier version was installed, remove the old toolbox entry (and the old
`%USERPROFILE%\MSPA-Toolbox` folder if it exists) before adding the new one.

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
archive and extract it over the existing folder.

## Known limitations

* **ArcGIS Pro** uses its built-in GDAL 3.x through the `osgeo` Python
  bindings for the TIFF conversion; no external GDAL or Visual C++ runtime is
  needed.
* **ArcGIS Desktop 10.x** has no `osgeo` and uses only ESRI functions: the
  input is read directly by MSPA (or converted with **Copy Raster** if
  needed), the extent is restored with a world file, the coordinate system
  with **Define Projection**, and the GTB metadata is written into the TIFF.
  No GDAL download, Visual C++ runtime or administrator rights are required.
  ArcGIS Desktop is legacy; ArcGIS Pro is recommended.
* Batch processing of several files is not available; use GTB or GWB for that.
* Windows x86_64 only; macOS and Linux are served by the R plugin and the
  standalone tool.

## Development

```sh
cd arcgis
./scripts/fetch-resources.sh   # MSPA 2.4.1 Windows binary and guide
./scripts/build-release.sh     # dist/MSPA-ArcGIS-<version>.zip + SHA256SUMS
```

The MSPA executable is not stored in Git; the build workflow fetches the
current MSPA binary from the MSPAstandalone release named in `MSPA_RELEASE`
(engine version in `MSPA_VERSION`).

## License

The ArcGIS toolbox is free software: you can redistribute it and/or modify it
under the terms of the **GNU General Public License, version 3 or later**
(GPL-3.0-or-later). See [../LICENSE](../LICENSE) for the full text.

The MSPA binaries are built and distributed by the European Commission's Joint
Research Centre under the same licence. See
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone#license).
