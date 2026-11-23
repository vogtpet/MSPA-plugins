# Changelog

MSPA ArcGIS plugin versions follow [Semantic Versioning](https://semver.org/)
and are independent of the MSPA version. The MSPA version wrapped by a release
is stored in `MSPA_VERSION`; the binary release it is taken from is in
`MSPA_RELEASE`.

## [2.2.5] - 2026-11-23

### Changed

* The Windows installer (`install_MSPA-ToolboxArc_Windows.bat`) was removed.
  ArcGIS Pro does not scan the folder it copied to, so the README now
  documents the reliable procedure: extract the archive to a permanent
  folder, add `MSPA.pyt` with **Catalog → Toolboxes → Add Toolbox**, and mark
  the toolbox as a favorite (or add it to new projects).

## [2.2.4] - 2026-11-23

### Fixed

* The ArcGIS Pro installer could not copy `MSPA.pyt`: `xcopy` prompted for a
  file or directory because the target subfolder did not exist. The installer
  now creates `…\Toolboxes\mspa`, copies the contents and reports whether
  `MSPA.pyt` arrived.

## [2.2.3] - 2026-11-23

### Changed

* The ArcGIS Pro installation target is now
  `%LOCALAPPDATA%\ESRI\ArcGISPro\Toolboxes` instead of
  `%USERPROFILE%\MSPA-Toolbox`, so the toolbox is picked up by ArcGIS Pro
  directly.

## [2.2.2] - 2026-11-23

### Fixed

* The result was flipped vertically. The GDAL Python path passed the bounds to
  `outputBounds` in the wrong order (GDAL expects `ulx uly lrx lry`) and let
  GDAL warp the raster. The result is now copied and the geotransform is
  assigned explicitly, exactly like `gdal_translate -a_ullr`.

## [2.2.1] - 2026-11-23

### Added

* The tool messages start with the plugin version, and the GDAL import error
  is reported when ArcGIS Pro's bindings cannot be loaded.

### Fixed

* The conda environment's `Library/bin` is added to the DLL search path before
  importing `osgeo`, so ArcGIS Pro's own GDAL 3.x can be used reliably.

## [2.2.0] - 2026-11-23

### Changed

* ArcGIS Pro uses its built-in GDAL 3.x through the `osgeo` Python bindings
  for the TIFF conversion. The legacy `gdal_translate.exe` (and its Visual
  C++ 2013 runtime requirement) is no longer used by ArcGIS Pro.
* The bundled legacy GDAL is only a fallback for ArcGIS Desktop 10.x; a
  warning is shown when it is used.

### Fixed

* The README links to the ArcGIS release tag and explains how to add the
  toolbox in ArcGIS Pro (Catalog → Toolboxes → Add Toolbox), including the
  project template option.

## [2.1.0] - 2026-11-23

### Added

* The `Low memory mode (-disk)` parameter; `-disk` is also used automatically
  above 65 million pixels.
* The update check reads `arcgis/VERSION` from the `MSPA-plugins` repository.

### Changed

* The maximum input size is now **400 million pixels in total** (about
  20,000 × 20,000), matching RMSPA; it was 65 million pixels.
* The MSPA executable is taken from MSPAstandalone release v2.4.1 (engine 2.4).
* Input validation no longer loads the whole image into a numpy array: it
  checks the maximum value only, so large images work, including in 32-bit
  ArcGIS Desktop.
* External programs are started with `subprocess` and argument lists, so paths
  containing spaces work; intermediate files are written to a unique temporary
  folder with distinct input/output names.
* The 50 × 50 pixel minimum was removed (as in RMSPA).
* The input parameter documents the GTB encoding.
* The installer copies the current `MSPA_Guide.pdf` and `README.md` and no
  longer ships the outdated toolbox PDF.

### Fixed

* Stale `out.tif` files and mixed input/output names can no longer be picked up.
* `.tiff`/`.TIF` input names are handled consistently.
