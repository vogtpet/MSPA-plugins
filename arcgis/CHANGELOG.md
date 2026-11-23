# Changelog

MSPA ArcGIS plugin versions follow [Semantic Versioning](https://semver.org/)
and are independent of the MSPA version. The MSPA version wrapped by a release
is stored in `MSPA_VERSION`; the binary release it is taken from is in
`MSPA_RELEASE`.

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
