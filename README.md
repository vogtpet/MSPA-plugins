# MSPA plugins

Application-specific wrappers around **MSPA** (Morphological Spatial Pattern
Analysis) for ArcGIS, QGIS 3, QGIS 4 and R/RStudio.

MSPA itself is developed by the European Commission's Joint Research Centre
(JRC). The reference implementation and its builds for Linux, macOS and
Windows are maintained in [MSPAstandalone](https://github.com/vogtpet/MSPAstandalone).
Each plugin in this repository wraps those binaries for one host application;
it does not contain a separate MSPA implementation.

## Plugins

| Plugin | Folder | Version | MSPA | Download |
|--------|--------|---------|------|----------|
| R / RStudio | [`r/`](r/) | 2.2.14 | 2.4 | [RMSPA-2.2.14.zip](https://github.com/vogtpet/MSPA-plugins/releases/download/r-v2.2.14/RMSPA-2.2.14.zip) |
| QGIS 3 | [`qgis3/`](qgis3/) | – | 2.4 | planned |
| QGIS 4 | [`qgis4/`](qgis4/) | – | 2.4 | planned |
| ArcGIS | [`arcgis/`](arcgis/) | 2.3.1 | 2.4 | [MSPA-ArcGIS-2.3.1.zip](https://github.com/vogtpet/MSPA-plugins/releases/download/arcgis-v2.3.1/MSPA-ArcGIS-2.3.1.zip) |

The installable archives are attached to the [releases](https://github.com/vogtpet/MSPA-plugins/releases).
The repository itself contains the sources; the MSPA binaries are downloaded
when an archive is built.

## Two version numbers

* **MSPA version** – the version of the MSPA engine, currently 2.4. It is the
  same for all plugins and is defined by
  [MSPAstandalone](https://github.com/vogtpet/MSPAstandalone/releases).
* **Plugin version** – the version of the wrapper for a host application.
  Every plugin has its own version number and its own release cycle. Plugin
  versions follow [Semantic Versioning](https://semver.org/).

## Updates

Every plugin publishes its current version in a plain text file, for example
`r/VERSION`. The installed plugin reads that file from GitHub and offers the
new release when the published version is higher than the installed one.
Releases are published as tags with a plugin prefix, for example `r-v2.2.14`
and `arcgis-v2.3.1`,
and the archives are attached to the corresponding GitHub release.

## Repository layout

```
MSPA-plugins/
├── r/          R/RStudio plugin (Shiny application)
├── qgis3/      QGIS 3 plugin
├── qgis4/      QGIS 4 plugin
├── arcgis/     ArcGIS toolbox
└── .github/    build and release workflows
```

Every plugin has its own folder with its sources, a `VERSION` file and a
`README.md` with installation and usage instructions. Released plugins also
have a `CHANGELOG.md`.

## Related resources

* [MSPA homepage](https://forest.jrc.ec.europa.eu/en/activities/lpa/mspa/)
* [MSPAstandalone](https://github.com/vogtpet/MSPAstandalone) – source code and
  reference builds of the MSPA engine
* [GuidosToolbox (GTB)](https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/),
  [GuidosToolbox Workbench (GWB)](https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/),
  and [pyGuidos](https://pyguidos-d46552.pages.code.europa.eu/index.html)

## License

The plugins in this repository and MSPA are free software: you can
redistribute them and/or modify them under the terms of the **GNU General
Public License, version 3 or later** (GPL-3.0-or-later). See [LICENSE](LICENSE)
for the full text.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

## Third-party components

The release archives contain the MSPA binaries built and distributed by the
European Commission's Joint Research Centre. They link the libraries listed in
the [third-party components section of
MSPAstandalone](https://github.com/vogtpet/MSPAstandalone#third-party-components);
the upstream notices are retained there.

The binaries link `libdeflate` (MIT) and `Lerc` (Apache-2.0) statically, so no dynamic libraries are bundled:

* libdeflate (MIT) – <https://github.com/ebiggers/libdeflate>
* Lerc (Apache-2.0) – <https://github.com/Esri/lerc>

The full license texts accompany every plugin (`third-party-licenses/` inside
the release archives, for example [`r/third-party-licenses/`](r/third-party-licenses/)) and are described in
[`r/THIRD-PARTY-NOTICES.md`](r/THIRD-PARTY-NOTICES.md).
