# RMSPA – MSPA for R and RStudio

RMSPA is a Shiny application that runs **MSPA** (Morphological Spatial Pattern
Analysis) on a single-band GeoTIFF and writes a classified GeoTIFF. It is a
thin wrapper around the MSPA command line tool from
[MSPAstandalone](https://github.com/vogtpet/MSPAstandalone); all pattern
analysis is done by MSPA itself.

| | |
|---|---|
| **Plugin version** | 2.2.8 |
| **MSPA version** | 2.4 |
| **Host** | R ≥ 4.0 (64-bit), RStudio recommended |

## Supported platforms

| Operating system | Architecture | Bundled MSPA binary |
|---|---|---|
| Linux | x86_64 (glibc ≥ 2.31) | `mspa_linux` |
| Linux | aarch64 | `mspa_linux_ARM` |
| macOS | Apple Silicon (11 or later) | `mspa_macOS_ARM` |
| Windows | x86_64 | `mspa_win64.exe` |
| Windows | ARM64 | `mspa_win64_ARM.exe` |

macOS on Intel is no longer supported.

Tested with these builds: Linux x86_64 (Ubuntu 26.10), Linux aarch64 (Fedora,
openSUSE Tumbleweed, Ubuntu, Debian), Windows x86_64, Windows ARM64 and macOS
Apple Silicon.

The Help panel shows the detected MSPA target and the architecture of the
running R session. On Windows ARM the native ARM64 executable is used even
when R itself runs as x86_64 under emulation.

## Installation

RMSPA is distributed as a **release archive**. The Git repository contains the
sources only: the MSPA binaries are not committed, so an application started
from a clone cannot find `resources/`. If you cloned the repository, run
`./scripts/fetch-binaries.sh` (see [Development](#development)) before
starting the app.

1. Download `RMSPA-2.2.8.zip` from the
   [releases page](https://github.com/vogtpet/MSPA-plugins/releases) and verify
   it against `SHA256SUMS` if you wish.
2. Extract the archive. You get a folder `RMSPA` containing `app.R`,
   `VERSION`, the `R/` sources, the manual `www/MSPA_Guide.pdf`, an example
   image in `examples/` and the MSPA binaries in `resources/`.
3. Start RStudio and open `app.R`.
4. Click **Run App** (or run `shiny::runApp("path/to/RMSPA")`).

The first start installs the required R packages (`shiny`, `shinyFiles`,
`shinyjs`, `terra`, `later`) from CRAN if they are missing. This can take a few
minutes because `terra` may need to be compiled, in particular on Linux. To
install them in advance:

```r
install.packages(c("shiny", "shinyFiles", "shinyjs", "terra", "later"))
```

On Ubuntu/Debian the installation of `terra` is much faster with binary
packages from Posit Package Manager:

```r
options(repos = c(P3M = "https://packagemanager.posit.co/cran/__linux__/jammy/latest",
                  CRAN = "https://cloud.r-project.org"))
```

On Linux, `terra` has to be compiled when no binary package is available (the
normal case on aarch64). Install the development packages first:

| Distribution | Packages |
|---|---|
| Debian / Ubuntu | `sudo apt install build-essential libuv1-dev zlib1g-dev libgdal-dev libproj-dev libgeos-dev` |
| Fedora | `sudo dnf install gcc gcc-c++ libuv-devel zlib-devel gdal-devel proj-devel geos-devel` |
| openSUSE | `sudo zypper install gcc gcc-c++ libuv-devel zlib-devel gdal-devel proj-devel geos-devel` |

These are the packages needed to install `terra` on Fedora, openSUSE
Tumbleweed, Ubuntu and Debian (aarch64).

A GDAL installation is **not** required to *run* RMSPA; `terra` ships its own
GDAL. GDAL development files are only needed if `terra` has to be compiled
from source.

You can also run the application from a terminal, without RStudio:

```sh
Rscript path/to/RMSPA/app.R
```

## Usage

### Step 1 – input image

Select a single-band 8-bit GeoTIFF with a coordinate reference system.

MSPA uses the following pixel values:

| Value | Meaning |
|---|---|
| 0 | Missing (optional) |
| 1 | Background (mandatory) |
| 2 | Foreground (mandatory) |

This is the encoding used by GuidosToolbox. If your mask uses the common
`0 = background, 1 = foreground` convention, select **Binary mask (0/1)** as
the input encoding; RMSPA recodes the image to the GTB convention before
processing. The original file is never modified.

The interface reports the image size, data type, projection and the pixel
values it found, and explains why an image cannot be processed. All
intermediate files are written to a temporary directory, so the folder
`RMSPA` can be read-only.

### Step 2 – MSPA parameters

| Parameter | Meaning | Default |
|---|---|---|
| `FGconn` | Foreground connectivity (4 or 8) | 8 |
| `EdgeWidth` | Effective edge width in pixels (1–5) | 1 |
| `Transition` | Show transition pixels (1) or closed boundaries (0) | 1 |
| `Internal` | Include internal structures and openings (1/0) | 1 |
| Low memory | Pass `-disk` to MSPA; automatic above 65 million pixels | off |

The parameters are documented in `www/MSPA_Guide.pdf` and on the
[MSPA homepage](https://forest.jrc.ec.europa.eu/en/activities/lpa/mspa/).

### Step 3 – process

Select the output folder and click **Start**. Very large images (above
400 million pixels) are rejected by the interface; use the MSPA standalone
tool or GTB for those.

## Output

The result is saved as

```
<input name>_<FGconn>_<EdgeWidth>_<Transition>_<Internal>.tif
```

for example `forest_8_1_1_1.tif`. The georeference of the input image is
restored, the LZW-compressed GeoTIFF keeps the MSPA colour table and the GTB
metadata (`TIFFTAG_IMAGEDESCRIPTION=GTB_MSPA, ...`) so that GTB can load the
MSPA parameters automatically. `NoData` is set to 255, a value MSPA does not
use.

Pixel values follow the MSPA colour code (MSPA guide, page 6):

| Class | Colour (RGB) | Internal = 0 | Internal = 1 |
|---|---|---|---|
| Core | 0/200/0 | 17 | 17, 117 |
| Islet | 160/60/0 | 9 | 9, 109 |
| Perforation | 0/0/255 | 5 | 105 |
| Edge | 0/0/0 | 3 | 3, 103 |
| Loop | 255/255/0 | 65 | 65, 165 |
| Loop in edge | 255/255/0 | 67 | 67, 167 |
| Loop in perforation | 255/255/0 | 69 | 169 |
| Bridge | 255/0/0 | 33 | 33, 133 |
| Bridge in edge | 255/0/0 | 35 | 35, 135 |
| Bridge in perforation | 255/0/0 | 37 | 137 |
| Branch | 255/140/0 | 1 | 1, 101 |
| Background | 220/220/220 | 0 | 0 |
| Border-Opening | 194/194/194 | – | 220 |
| Core-Opening | 136/136/136 | – | 100 |
| No Data | 255/255/255 | 129 | 129 |

With `Internal = 1` the pixel values of internal structures are offset by
100 (for example 17 → 117).

## Updates

RMSPA checks `r/VERSION` in the `MSPA-plugins` repository at every start and
shows a message when a newer plugin version is available. You can also run
the check manually with **Check for updates**; the last result is cached for
offline use. The new version is downloaded
from the GitHub release, verified to contain the announced version and
unpacked **next to** the current installation, for example
`RMSPA-2.2.8/`. Close RMSPA, start `app.R` from the new folder, and delete the
old folder once the new version works. The current installation is never
modified by an update.

## Troubleshooting

**"MSPA is not available on this system."**
The message in the interface contains the details. Common reasons are a
missing file, a missing execute permission (RMSPA sets it automatically) or a
blocked executable.

**macOS: "cannot be opened" or the binary does not start**
RMSPA removes the `com.apple.quarantine` flag from its bundled binaries
(`resources/`) automatically at startup, so the manual step is normally not
needed. If macOS still blocks the executable, remove the flag manually:

```sh
xattr -dr com.apple.quarantine /path/to/RMSPA
```

Since RMSPA 2.2.8 the macOS ARM binary is built for **macOS 11 or later**
(MSPA 2.4.1). The previous archive (2.2.7 and earlier) required macOS 27.

**Windows: SmartScreen or antivirus warnings**
The MSPA executable is not code signed. Verify the SHA-256 checksum of the
archive and allow the file if you trust the source. The Visual C++ 2013
runtime is no longer required; the old GDAL bundle was removed in 2.2.0.

**Linux: `terra` does not install**
Either install the GDAL development packages (`libgdal-dev`, `libproj-dev`,
`libgeos-dev`) or use the Posit Package Manager binaries shown above.

**The output looks grey or white instead of the MSPA colours**
The colour table is stored in the GeoTIFF. Some GIS programs ignore it; use
"unique values" symbology with the MSPA colours from the table above, or use
GTB to display the result.

**Values in the output**
The full class encoding, including the internal offsets, is listed above and
in `www/MSPA_Guide.pdf`.

## Development

```sh
cd r
./scripts/fetch-binaries.sh        # MSPA binaries from the MSPAstandalone release
./scripts/fetch-guide.sh           # current MSPA_Guide.pdf from the JRC page
Rscript scripts/smoke-test.R       # end-to-end test against reference.tif
Rscript tests/app-callback-test.R  # server callback regression test
./scripts/build-release.sh         # dist/RMSPA-<version>.zip + SHA256SUMS
```

`build-release.sh` downloads the current `MSPA_Guide.pdf` from the JRC MSPA
page for every archive and falls back to `www/MSPA_Guide.pdf` if the server is
unavailable.

The binaries are not stored in the repository; `fetch-binaries.sh` downloads
the archives of the MSPA release named in `MSPA_RELEASE` (currently 2.4.1),
verifies the upstream checksums and records the provenance in
`resources/BINARIES.txt`. `MSPA_VERSION` is the engine version (2.4) that the
startup check compares with the binary.
`resources/` is ignored by git.

On a platform without a bundled binary (for example an Intel Mac) pass a
development build with `Rscript scripts/smoke-test.R --binary /path/to/mspa`.

The smoke test runs the complete pipeline on `examples/input.tif` and compares
the result with the reference output of MSPAstandalone. It also checks the
non-default parameters, both input encodings, the NoData value, the restored
projection and the GTB metadata.

Releases are built by GitHub Actions when a tag `r-v<version>` is pushed; the
tag must match `VERSION`.

## License

RMSPA is free software: you can redistribute it and/or modify it under the
terms of the **GNU General Public License, version 3 or later**
(GPL-3.0-or-later). See [LICENSE](LICENSE) for the full text.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

The bundled MSPA binaries and the third-party libraries are described in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md); the full license texts are in
[`licenses/`](licenses/). See also the [third-party components section of
MSPAstandalone](https://github.com/vogtpet/MSPAstandalone#third-party-components).
