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
| R / RStudio | [`r/`](r/) | 2.2.0 | 2.4 | [RMSPA-2.2.0.zip](https://github.com/vogtpet/MSPA-plugins/releases/download/r-v2.2.0/RMSPA-2.2.0.zip) |
| QGIS 3 | [`qgis3/`](qgis3/) | – | 2.4 | planned |
| QGIS 4 | [`qgis4/`](qgis4/) | – | 2.4 | planned |
| ArcGIS | [`arcgis/`](arcgis/) | – | 2.4 | planned |

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
Releases are published as tags with a plugin prefix, for example `r-v2.2.0`,
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
* [GuidosToolbox (GTB)](https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/)
  and [GuidosToolbox Workbench (GWB)](https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/)

## Licence

The plugin code in this repository is licensed under the
[GNU General Public License v3.0](LICENSE), the licence of MSPA.

The MSPA binaries bundled with the releases are built and distributed by the
European Commission's Joint Research Centre. Please note the MSPA disclaimer:
the software is made available for non-commercial purposes; for commercial use
contact the JRC.
