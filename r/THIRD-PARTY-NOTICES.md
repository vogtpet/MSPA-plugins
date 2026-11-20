# Third-party notices

RMSPA bundles the MSPA command line tool. On macOS, `libdeflate` and `Lerc`
are linked statically into the executable.

## MSPA and miallib

Morphological Spatial Pattern Analysis 2.4, including miallib.
Copyright (C) European Commission, Joint Research Centre.
License: GNU General Public License, version 3 or later (GPL-3.0-or-later).
Source: <https://github.com/vogtpet/MSPAstandalone>

The MSPA binaries link the image libraries listed in the
[third-party components section of
MSPAstandalone](https://github.com/vogtpet/MSPAstandalone#third-party-components)
(libtiff, libjpeg-turbo, libpng, libwebp, jbigkit, zlib, zstd, xz/liblzma,
libdeflate, Lerc). The upstream notices are retained in that repository.

## libdeflate (linked statically)

<https://github.com/ebiggers/libdeflate>
Copyright (C) 2016 Eric Biggers, 2024 Google LLC.
License: MIT. Full text: [licenses/MIT.txt](licenses/MIT.txt).

## Lerc (linked statically)

<https://github.com/Esri/lerc>
Copyright (C) Esri.
License: Apache License 2.0. Full text:
[licenses/Apache-2.0.txt](licenses/Apache-2.0.txt).

## R packages

The R packages used by RMSPA (shiny, shinyFiles, shinyjs, terra, later) are
installed from CRAN by the user and are not part of the release archive. Their
license terms are shown by `packageDescription("<package>")$License`.
