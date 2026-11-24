# -*- coding: utf-8 -*-
"""
/***************************************************************************
 MSPA ArcGIS toolbox
 Morphological Spatial Pattern Analysis

 An ArcGIS toolbox for the MSPA command line tool from MSPAstandalone.
 The MSPA binary is fetched at build time; see README.md.

 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU General Public License, version 3 or later
 (GPL-3.0-or-later).
***************************************************************************/
"""

import arcpy
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from time import strftime

try:
    from urllib.request import urlopen  # Python 3
except ImportError:
    from urllib2 import urlopen  # Python 2

# ArcGIS Pro ships GDAL with the Python bindings (osgeo) in its conda
# environment. Make the DLLs of that environment findable before importing.
_conda_bin = os.path.join(sys.prefix, "Library", "bin")
if os.path.isdir(_conda_bin):
    os.environ["PATH"] = _conda_bin + os.pathsep + os.environ.get("PATH", "")
    _share = os.path.join(sys.prefix, "Library", "share")
    if "PROJ_LIB" not in os.environ and os.path.isdir(os.path.join(_share, "proj")):
        os.environ["PROJ_LIB"] = os.path.join(_share, "proj")
    if "GDAL_DATA" not in os.environ and os.path.isdir(os.path.join(_share, "gdal")):
        os.environ["GDAL_DATA"] = os.path.join(_share, "gdal")

GDAL_IMPORT_ERROR = None
try:
    from osgeo import gdal
    HAS_GDAL_PYTHON = True
except Exception as exc:
    gdal = None
    HAS_GDAL_PYTHON = False
    GDAL_IMPORT_ERROR = str(exc)


PLUGIN_VERSION = "2.3.0"
UPDATE_URL = ("https://raw.githubusercontent.com/vogtpet/MSPA-plugins/"
              "main/arcgis/VERSION")
RELEASE_URL = "https://github.com/vogtpet/MSPA-plugins/releases/tag/arcgis-v"

# Same limits as RMSPA: total pixels, not a per-axis limit.
MAX_PIXELS = 400000000      # about 20,000 x 20,000
DISK_PIXELS = 65000000      # -disk is used automatically above this (~8,000 x 8,000)


def version_tuple(value):
    try:
        return tuple(int(part) for part in str(value).strip().split("."))
    except (TypeError, ValueError):
        return ()


def check_for_update(messages):
    """Warn when the version published on GitHub is newer. Best effort."""
    try:
        response = urlopen(UPDATE_URL, timeout=5)
        data = response.read()
        if not isinstance(data, str):
            data = data.decode("utf-8", "ignore")
        latest = data.strip()
        if version_tuple(latest) > version_tuple(PLUGIN_VERSION):
            messages.AddWarningMessage(
                "A newer MSPA ArcGIS plugin (%s) is available: %s%s"
                % (latest, RELEASE_URL, latest))
    except Exception:
        pass


class Toolbox(object):
    def __init__(self):
        """Define the toolbox (the name of the toolbox is the name of the .pyt file)."""
        self.label = "MSPA Tools"
        self.alias = "MSPA"

        # List of tool classes associated with this toolbox
        self.tools = [MSPA]


class MSPA(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "MSPA"
        self.VERSION = PLUGIN_VERSION
        self.description = ("Analysis and description of image objects including "
                            "morphometric features and connecting pathways - "
                            "plugin version " + PLUGIN_VERSION)
        self.canRunInBackground = False
        self.plugin_dir = os.path.dirname(__file__)
        self.install_info = arcpy.GetInstallInfo()

    def getParameterInfo(self):
        """Define parameter definitions"""

        inputImage = arcpy.Parameter(
            displayName=("Input image - 0 = missing/nodata (optional), "
                         "1 = background, 2 = foreground"),
            name="InputImage",
            datatype="DEFile",
            parameterType="Required",
            direction="Input"
        )
        inputImage.filter.list = ['tif', 'tiff']

        fgConn = arcpy.Parameter(
            displayName="FGconn",
            name="FGconn",
            datatype="GPLong",
            parameterType="Required",
            direction="Input"
        )
        fgConn.filter.type = "ValueList"
        fgConn.filter.list = [8, 4]

        edgeWidth = arcpy.Parameter(
            displayName="EdgeWidth",
            name="EdgeWidth",
            datatype="GPLong",
            parameterType="Required",
            direction="Input"
        )
        edgeWidth.filter.type = "ValueList"
        edgeWidth.filter.list = [1, 2, 3, 4, 5]

        Transition = arcpy.Parameter(
            displayName="Transition",
            name="Transition",
            datatype="GPLong",
            parameterType="Required",
            direction="Input"
        )
        Transition.filter.type = "ValueList"
        Transition.filter.list = [1, 0]

        inText = arcpy.Parameter(
            displayName="Intext",
            name="Intext",
            datatype="GPLong",
            parameterType="Required",
            direction="Input"
        )
        inText.filter.type = "ValueList"
        inText.filter.list = [1, 0]

        savePath = arcpy.Parameter(
            displayName="Select the folder where to save the output file",
            name="SavePath",
            datatype="DEFolder",
            parameterType="Required",
            direction="Input"
        )

        lowMemory = arcpy.Parameter(
            displayName="Low memory mode (-disk)",
            name="LowMemory",
            datatype="GPBoolean",
            parameterType="Optional",
            direction="Input"
        )
        lowMemory.value = False

        parameters = [inputImage, fgConn, edgeWidth, Transition, inText,
                      savePath, lowMemory]
        return parameters

    def isLicensed(self):
        """Set whether tool is licensed to execute."""
        return True

    def updateParameters(self, parameters):
        """Modify the values and properties of parameters before internal
        validation is performed."""
        return

    def updateMessages(self, parameters):
        """Modify the messages created by internal validation for each tool
        parameter."""
        return

    @staticmethod
    def prepare_input_gdal(src, dst):
        """Normalise the input with ArcGIS Pro's GDAL Python bindings."""
        gdal.UseExceptions()
        gdal.Translate(
            dst, src,
            options=gdal.TranslateOptions(
                format="GTiff",
                creationOptions=["TILED=NO", "PROFILE=BASELINE", "COMPRESS=LZW"]))

    @staticmethod
    def write_result_gdal(src, dst, extent, tags):
        """Write the result with georeferencing and TIFF metadata.

        The MSPA output has no georeferencing. Assign the extent of the input
        image explicitly (like gdal_translate -a_ullr) instead of using
        outputBounds, which expects (ulx, uly, lrx, lry) and resamples.
        """
        gdal.UseExceptions()
        gdal.Translate(
            dst, src,
            options=gdal.TranslateOptions(
                format="GTiff",
                creationOptions=["COMPRESS=LZW"],
                metadataOptions=tags))
        dataset = gdal.Open(dst, gdal.GA_Update)
        if dataset is None:
            raise RuntimeError("the result image could not be reopened")
        xmin, ymin, xmax, ymax = extent
        width = float(dataset.RasterXSize)
        height = float(dataset.RasterYSize)
        dataset.SetGeoTransform((xmin, (xmax - xmin) / width, 0.0,
                                 ymax, 0.0, -(ymax - ymin) / height))
        dataset.FlushCache()
        dataset = None

    @staticmethod
    def write_world_file(path, extent, width, height):
        """Write an ESRI world file for a raster without internal georeferencing."""
        xmin, ymin, xmax, ymax = extent
        pixel_x = (float(xmax) - float(xmin)) / float(width)
        pixel_y = (float(ymax) - float(ymin)) / float(height)
        values = [pixel_x, 0.0, 0.0, -pixel_y,
                  float(xmin) + pixel_x / 2.0,
                  float(ymax) - pixel_y / 2.0]
        world = os.path.splitext(path)[0] + ".tfw"
        with open(world, "w") as handle:
            handle.write("\n".join("%.10f" % value for value in values))

    @staticmethod
    def remove_sidecars(path):
        """Remove world file and auxiliary files left by an earlier run."""
        stem = os.path.splitext(path)[0]
        for sidecar in (stem + ".tfw", stem + ".ovr", path + ".aux.xml",
                        path + ".ovr"):
            try:
                if os.path.isfile(sidecar):
                    os.remove(sidecar)
            except Exception:
                pass

    @staticmethod
    def write_tiff_tags(path, tags):
        """Add ASCII TIFF tags without GDAL.

        ArcGIS writes a GeoTIFF but does not carry the GTB metadata tags that
        GuidosToolbox uses to reload the parameters. Append a new IFD at the
        end of the file and point the header at it; the pixel data and all
        existing tags stay untouched.
        """
        with open(path, "rb") as handle:
            data = handle.read()
        if data[:4] == b"II*\x00":
            endian = "<"
        elif data[:4] == b"MM\x00*":
            endian = ">"
        else:
            raise RuntimeError("the result is not a classic TIFF file")
        if len(data) < 8:
            raise RuntimeError("the result is not a valid TIFF file")
        ifd_offset = struct.unpack(endian + "I", data[4:8])[0]
        if ifd_offset + 2 > len(data):
            raise RuntimeError("the result is not a valid TIFF file")
        count = struct.unpack(endian + "H", data[ifd_offset:ifd_offset + 2])[0]
        position = ifd_offset + 2
        entries = []
        for _ in range(count):
            if position + 12 > len(data):
                raise RuntimeError("the result is not a valid TIFF file")
            entries.append(data[position:position + 12])
            position += 12
        if position + 4 > len(data):
            raise RuntimeError("the result is not a valid TIFF file")
        next_offset = struct.unpack(endian + "I", data[position:position + 4])[0]

        replaced = set(tags)
        entries = [entry for entry in entries
                   if struct.unpack(endian + "H", entry[:2])[0] not in replaced]

        base = len(data)
        if base % 2:
            base += 1
        values_offset = base + 2 + 12 * (len(entries) + len(tags)) + 4
        values = b""
        for tag in sorted(tags):
            payload = str(tags[tag]).encode("ascii", "replace") + b"\x00"
            entry = struct.pack(endian + "HHI", tag, 2, len(payload))
            if len(payload) <= 4:
                entry += payload.ljust(4, b"\x00")
            else:
                entry += struct.pack(endian + "I", values_offset + len(values))
                values += payload
            entries.append(entry)
        entries.sort(key=lambda entry: struct.unpack(endian + "H", entry[:2])[0])

        ifd = struct.pack(endian + "H", len(entries))
        ifd += b"".join(entries)
        ifd += struct.pack(endian + "I", next_offset)

        with open(path, "ab") as handle:
            handle.write(b"\x00" * (base - len(data)))
            handle.write(ifd)
            handle.write(values)
        with open(path, "r+b") as handle:
            handle.seek(4)
            handle.write(struct.pack(endian + "I", base))

    @staticmethod
    def run_tool(args, cwd):
        """Run an executable without a shell and return (status, output)."""
        try:
            process = subprocess.Popen(
                args, cwd=cwd, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, universal_newlines=True)
            output, _ = process.communicate()
            return process.returncode, output or ""
        except Exception as exc:
            return 1, str(exc)

    def execute(self, parameters, messages):
        """The source code of the tool."""
        messages.AddMessage("MSPA ArcGIS plugin %s (MSPA 2.4)" % PLUGIN_VERSION)
        check_for_update(messages)

        if self.install_info['ProductName'] == 'ArcGISPro':
            try:
                project = arcpy.mp.ArcGISProject("current")
                if not project.listMaps():
                    messages.AddErrorMessage(
                        "Before proceeding, please add a Map to the project")
                    sys.exit(0)
            except Exception as exc:
                messages.AddErrorMessage(
                    "A current ArcGIS Pro project is required: " + str(exc))
                sys.exit(0)

        filepath = parameters[0].valueAsText
        if not filepath:
            messages.AddErrorMessage("Please select an input image.")
            sys.exit(0)

        try:
            spatial_ref = arcpy.Describe(filepath).spatialReference
        except Exception as exc:
            messages.AddErrorMessage("The input image could not be opened: " + str(exc))
            sys.exit(0)

        if not spatial_ref or spatial_ref.name == "Unknown":
            messages.AddErrorMessage(
                "The image has no projection. Please load an MSPA-compliant image.")
            sys.exit(0)

        dataset = arcpy.Raster(filepath)
        nbands = dataset.bandCount
        bandtype = dataset.pixelType
        xsize = int(dataset.width)
        ysize = int(dataset.height)
        pixels = xsize * ysize

        if nbands != 1:
            messages.AddErrorMessage(
                "The image is not a single band image. Please load an MSPA-compliant image.")
            sys.exit(0)
        if bandtype != "U8":
            messages.AddErrorMessage(
                "The band type is not Byte, it is " + bandtype +
                ". Please load an MSPA-compliant image.")
            sys.exit(0)
        if pixels > MAX_PIXELS:
            messages.AddErrorMessage(
                "The image has %d pixels (%.1f million), which is above the "
                "limit of %d million pixels (about 20,000 x 20,000). Use the "
                "MSPA standalone tool or GuidosToolbox for very large images."
                % (pixels, pixels / 1e6, MAX_PIXELS // 1000000))
            sys.exit(0)

        try:
            arcpy.CalculateStatistics_management(filepath,
                                                 skip_existing="SKIP_EXISTING")
            max_text = arcpy.GetRasterProperties_management(
                filepath, "MAXIMUM").getOutput(0)
            maxval = int(float(max_text))
        except Exception as exc:
            messages.AddErrorMessage(
                "The pixel values of the image could not be read: " + str(exc))
            sys.exit(0)

        if maxval > 2:
            messages.AddErrorMessage(
                "The maximum value for the band is bigger than 2 (%d). "
                "Please load an MSPA-compliant image." % maxval)
            sys.exit(0)
        if maxval < 2:
            messages.AddErrorMessage(
                "The image contains no foreground (value 2). Please load an "
                "MSPA-compliant image.")
            sys.exit(0)

        savepath = parameters[5].valueAsText
        if not savepath or not os.path.isdir(savepath):
            messages.AddErrorMessage("Please select a valid output folder.")
            sys.exit(0)

        low_value = parameters[6].value
        low_memory = (low_value is True or
                      str(low_value).strip().lower() in ("true", "1"))
        disk = low_memory or pixels > DISK_PIXELS

        fgconn = parameters[1].valueAsText
        edgewidth = parameters[2].valueAsText
        transition = parameters[3].valueAsText
        intext = parameters[4].valueAsText
        params_tag = "%s_%s_%s_%s" % (fgconn, edgewidth, transition, intext)

        input_name = os.path.splitext(os.path.basename(filepath))[0]
        inputparams = input_name + "_" + params_tag
        docname = inputparams + ".tif"
        movedfile = os.path.join(savepath, docname)

        if os.path.exists(movedfile):
            messages.AddWarningMessage(
                "The existing result will be overwritten: " + movedfile)
            try:
                os.remove(movedfile)
            except Exception as exc:
                messages.AddErrorMessage(
                    "The existing file could not be replaced (is it open in "
                    "ArcGIS?): " + str(exc))
                sys.exit(0)

        self.remove_sidecars(movedfile)

        resources = os.path.join(self.plugin_dir, "resources")
        mspa = os.path.join(resources, "mspa_win64.exe")

        if not os.path.isfile(mspa):
            messages.AddErrorMessage(
                "The plugin is incomplete; missing: " + mspa)
            sys.exit(0)

        use_gdal_python = HAS_GDAL_PYTHON
        if use_gdal_python:
            try:
                messages.AddMessage("Using the built-in GDAL " + gdal.__version__)
            except Exception:
                messages.AddMessage("Using the built-in GDAL.")
        else:
            if (self.install_info.get('ProductName') == 'ArcGISPro' and
                    GDAL_IMPORT_ERROR):
                messages.AddWarningMessage(
                    "ArcGIS Pro's GDAL bindings could not be loaded: "
                    + GDAL_IMPORT_ERROR)
            messages.AddMessage("Using ESRI functions (no GDAL).")

        workdir = tempfile.mkdtemp(prefix="mspa_")
        tmp_in = os.path.join(workdir, "in.tif")
        tmp_out = os.path.join(workdir, "out.tif")

        try:
            mspa_input = filepath
            if use_gdal_python:
                messages.AddMessage("Preparing the input image ...")
                try:
                    self.prepare_input_gdal(filepath, tmp_in)
                except Exception as exc:
                    messages.AddErrorMessage(
                        "The input image could not be prepared for MSPA:\n"
                        + str(exc))
                    sys.exit(0)
                if not os.path.isfile(tmp_in):
                    messages.AddErrorMessage(
                        "The input image could not be prepared for MSPA.")
                    sys.exit(0)
                mspa_input = tmp_in

            def run_mspa(source):
                args = [mspa, "-i", source, "-o", "out.tif", "-odir", workdir,
                        "-graphfg", fgconn, "-eew", edgewidth,
                        "-transition", transition, "-internal", intext]
                if disk:
                    args.append("-disk")
                return self.run_tool(args, workdir)

            messages.AddMessage(
                "Running MSPA%s ..." % (" (low memory mode)" if disk else ""))
            status, output = run_mspa(mspa_input)

            if status != 0 and not use_gdal_python:
                # MSPA could not read the input directly; let ArcGIS create a
                # plain TIFF and try again.
                messages.AddWarningMessage(
                    "MSPA could not read the input directly. Converting it "
                    "with ArcGIS and retrying ...")
                if os.path.exists(tmp_out):
                    try:
                        os.remove(tmp_out)
                    except Exception:
                        pass
                try:
                    arcpy.CopyRaster_management(filepath, tmp_in)
                except Exception as exc:
                    messages.AddErrorMessage(
                        "The input image could not be converted for MSPA: "
                        + str(exc))
                    sys.exit(0)
                if not os.path.isfile(tmp_in):
                    messages.AddErrorMessage(
                        "The input image could not be converted for MSPA.")
                    sys.exit(0)
                status, output = run_mspa(tmp_in)

            if status != 0 or not os.path.isfile(tmp_out):
                messages.AddErrorMessage(
                    "MSPA could not process the image:\n" + output +
                    "\n\nIf the input is a tiled or compressed TIFF, export "
                    "it as an uncompressed GeoTIFF and retry.")
                sys.exit(0)

            xmin = float(arcpy.GetRasterProperties_management(
                filepath, "LEFT").getOutput(0))
            xmax = float(arcpy.GetRasterProperties_management(
                filepath, "RIGHT").getOutput(0))
            ymin = float(arcpy.GetRasterProperties_management(
                filepath, "BOTTOM").getOutput(0))
            ymax = float(arcpy.GetRasterProperties_management(
                filepath, "TOP").getOutput(0))

            messages.AddMessage("Writing the result ...")
            tags = [
                "TIFFTAG_DATETIME=" + strftime("%Y:%m:%d %H:%M:%S"),
                "TIFFTAG_DOCUMENTNAME=" + docname,
                ("TIFFTAG_IMAGEDESCRIPTION=GTB_MSPA, "
                 "https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/ "
                 + params_tag),
            ]
            if use_gdal_python:
                try:
                    self.write_result_gdal(
                        tmp_out, movedfile,
                        (xmin, ymin, xmax, ymax), tags)
                    status, output = (0 if os.path.isfile(movedfile) else 1), ""
                except Exception as exc:
                    status, output = 1, str(exc)
            else:
                try:
                    # Create a world file for the ungeoreferenced result, then
                    # let ArcGIS bake both the extent and the coordinate system
                    # into a real GeoTIFF (no GDAL required).
                    staged = os.path.join(workdir, "geo.tif")
                    shutil.copyfile(tmp_out, staged)
                    self.write_world_file(staged,
                                          (xmin, ymin, xmax, ymax),
                                          xsize, ysize)
                    old_srs = arcpy.env.outputCoordinateSystem
                    try:
                        arcpy.env.outputCoordinateSystem = spatial_ref
                        try:
                            arcpy.CopyRaster_management(
                                staged, movedfile, "COMPRESS=LZW")
                        except Exception:
                            # Older ArcGIS versions may reject the TIFF
                            # creation option; write an uncompressed copy.
                            if os.path.isfile(movedfile):
                                os.remove(movedfile)
                            arcpy.CopyRaster_management(staged, movedfile)
                    finally:
                        arcpy.env.outputCoordinateSystem = old_srs
                    status, output = (0 if os.path.isfile(movedfile) else 1), ""
                except Exception as exc:
                    messages.AddWarningMessage(
                        "The result could not be converted by ArcGIS (%s). "
                        "Writing the TIFF with a world file instead." % exc)
                    try:
                        shutil.copyfile(tmp_out, movedfile)
                        self.write_world_file(movedfile,
                                              (xmin, ymin, xmax, ymax),
                                              xsize, ysize)
                        status, output = 0, ""
                    except Exception as copy_exc:
                        status, output = 1, str(copy_exc)
            if status != 0 or not os.path.isfile(movedfile):
                messages.AddErrorMessage(
                    "The result could not be written:\n" + output)
                sys.exit(0)

            try:
                arcpy.DefineProjection_management(movedfile, spatial_ref)
            except Exception as exc:
                messages.AddWarningMessage(
                    "The coordinate system could not be written into the "
                    "result: " + str(exc))

            if not use_gdal_python:
                try:
                    self.write_tiff_tags(movedfile, {
                        269: docname,
                        270: "GTB_MSPA, "
                             "https://forest.jrc.ec.europa.eu/en/"
                             "activities/lpa/gtb/ " + params_tag,
                        306: strftime("%Y:%m:%d %H:%M:%S"),
                    })
                except Exception as exc:
                    messages.AddWarningMessage(
                        "The GTB metadata could not be written into the "
                        "result: " + str(exc))

            try:
                layer = arcpy.MakeRasterLayer_management(
                    movedfile, inputparams).getOutput(0)
                if self.install_info['ProductName'] == 'Desktop':
                    document = arcpy.mapping.MapDocument("CURRENT")
                    dataframe = arcpy.mapping.ListDataFrames(document)[0]
                    arcpy.mapping.AddLayer(dataframe, layer, "TOP")
                else:
                    project = arcpy.mp.ArcGISProject("current")
                    project.listMaps()[0].addLayer(layer, "TOP")
                messages.AddMessage(
                    "GeoTiff image processed successfully: " + movedfile)
            except Exception as exc:
                messages.AddWarningMessage(
                    "The result was written but could not be added to the map: "
                    + str(exc))
        finally:
            shutil.rmtree(workdir, ignore_errors=True)
