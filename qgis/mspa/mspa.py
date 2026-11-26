# -*- coding: utf-8 -*-
"""
/***************************************************************************
 Mspa
                                 A QGIS plugin
 Morphological Spatial Pattern Analysis
                              -------------------
        begin                : 2022-04-12
        copyright            : (C) 2022 by European Commission JRC
        email                : peter.vogt@ec.europa.eu
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 3 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
"""

import os
import platform
import shutil
import subprocess
import tempfile
import urllib.request
from time import strftime

from qgis.PyQt.QtCore import QCoreApplication, Qt, QUrl
from qgis.PyQt.QtGui import QDesktopServices, QIcon
from qgis.PyQt.QtWidgets import (
    QApplication, QFileDialog, QMessageBox, QProgressDialog)

try:  # Qt 6 moved QAction from QtWidgets to QtGui
    from qgis.PyQt.QtGui import QAction
except ImportError:  # Qt 5
    from qgis.PyQt.QtWidgets import QAction

from qgis.core import QgsProject, QgsRasterLayer

from .mspa_dialog import MspaDialog
from .mspa_picker import MspaPathDialog


def _qt_enum(owner, group, name):
    """Return a scoped Qt enum on Qt 6 or its unscoped Qt 5 equivalent."""
    nested = getattr(owner, group, None)
    if nested is not None and hasattr(nested, name):
        return getattr(nested, name)
    return getattr(owner, name)


MSG_INFORMATION = _qt_enum(QMessageBox, "Icon", "Information")
MSG_YES = _qt_enum(QMessageBox, "StandardButton", "Yes")
MSG_NO = _qt_enum(QMessageBox, "StandardButton", "No")
ROLE_ACCEPT = _qt_enum(QMessageBox, "ButtonRole", "AcceptRole")
ROLE_REJECT = _qt_enum(QMessageBox, "ButtonRole", "RejectRole")

try:
    WINDOW_MODAL = Qt.WindowModality.WindowModal
except AttributeError:  # Qt < 5.15
    WINDOW_MODAL = Qt.WindowModal

try:
    from osgeo import gdal
except ImportError:
    gdal = None

PLUGIN_VERSION = "2.2.4"

# QFileDialog asks the platform icon theme for file icons, which can
# abort QGIS on some Linux/GTK installations. Use a plain Qt picker there.
USE_CUSTOM_PICKER = platform.system() == "Linux"
UPDATE_URL = ("https://raw.githubusercontent.com/vogtpet/MSPA-plugins/"
              "main/qgis/VERSION")
RELEASE_URL = "https://github.com/vogtpet/MSPA-plugins/releases/tag/qgis-v"
GUIDE_URL = "https://ies-ows.jrc.ec.europa.eu/gtb/GTB/MSPA_Guide.pdf"
PLUGIN_DOC_URL = ("https://github.com/vogtpet/MSPA-plugins/"
                  "blob/main/qgis/README.md")

# Same limits as RMSPA and the ArcGIS plugin: total pixels, not per axis.
MAX_PIXELS = 400000000      # about 20,000 x 20,000
DISK_PIXELS = 65000000      # -disk is used automatically above this
MIN_SIZE = 50

BINARIES = {
    ("Windows", "x86_64"): "mspa_win64.exe",
    ("Windows", "arm64"): "mspa_win64_ARM.exe",
    ("Darwin", "arm64"): "mspa_macOS_ARM",
    ("Linux", "x86_64"): "mspa_linux",
    ("Linux", "arm64"): "mspa_linux_ARM",
}


def version_tuple(value):
    try:
        return tuple(int(part) for part in str(value).strip().split("."))
    except (TypeError, ValueError):
        return ()


def machine_name():
    machine = platform.machine().lower()
    if machine in ("amd64", "x64", "x86-64"):
        return "x86_64"
    if machine in ("arm64", "aarch64"):
        return "arm64"
    return machine


def mspa_binary(plugin_dir):
    """Return the MSPA executable for this platform."""
    system = platform.system()
    machine = machine_name()
    name = BINARIES.get((system, machine))
    if name is None:
        raise RuntimeError(
            "MSPA does not support this platform: %s %s.\n\n"
            "Supported platforms are Windows x86_64 and ARM64, Linux "
            "x86_64 (glibc 2.31 or newer) and aarch64, and macOS on Apple "
            "Silicon. On Intel Macs use the MSPA standalone tool or the R "
            "plugin." % (system, platform.machine()))
    path = os.path.join(plugin_dir, "binaries", name)
    if not os.path.isfile(path):
        raise RuntimeError(
            "The MSPA executable is missing from the plugin:\n%s\n\n"
            "Reinstall the plugin." % path)
    if os.name != "nt" and not os.access(path, os.X_OK):
        try:
            os.chmod(path, 0o755)
        except OSError:
            pass
    return path


class Mspa:
    """QGIS Plugin Implementation."""

    def __init__(self, iface):
        """Constructor."""
        self.iface = iface
        self.plugin_dir = os.path.dirname(__file__)
        self.VERSION = PLUGIN_VERSION
        self.actions = []
        self.menu = self.tr(u'&MSPA')
        self.toolbar = self.iface.addToolBar(u'MSPA')
        self.toolbar.setObjectName(u'MSPA')
        self._update_checked = False
        self._input = None

        self.dlg = MspaDialog()
        self.dlg.setWindowTitle("MSPA Plugin - version " + PLUGIN_VERSION)
        self.dlg.selectButton.clicked.connect(self.select_input)
        self.dlg.showPath.editingFinished.connect(self.validate_path)
        self.dlg.startButton.clicked.connect(self.process_image)
        self.dlg.pluginguideButton.clicked.connect(self.open_plugin_guide)
        self.dlg.mspaguideButton.clicked.connect(self.open_mspa_guide)

    def tr(self, message):
        """Get the translation for a string using Qt translation API."""
        return QCoreApplication.translate('Mspa', message)

    def add_action(self, icon_path, text, callback, enabled_flag=True,
                   add_to_menu=True, add_to_toolbar=True, status_tip=None,
                   whats_this=None, parent=None):
        """Add a toolbar icon to the toolbar."""
        icon = QIcon(icon_path)
        action = QAction(icon, text, parent)
        action.triggered.connect(callback)
        action.setEnabled(enabled_flag)

        if status_tip is not None:
            action.setStatusTip(status_tip)
        if whats_this is not None:
            action.setWhatsThis(whats_this)
        if add_to_toolbar:
            self.toolbar.addAction(action)
        if add_to_menu:
            self.iface.addPluginToMenu(self.menu, action)

        self.actions.append(action)
        return action

    def initGui(self):
        """Create the menu entries and toolbar icons inside the QGIS GUI."""
        icon_path = os.path.join(self.plugin_dir, 'icon.png')
        self.add_action(
            icon_path,
            text=self.tr(u'MSPA'),
            callback=self.run,
            parent=self.iface.mainWindow())

    def unload(self):
        """Remove the plugin menu item and icon from QGIS GUI."""
        for action in self.actions:
            self.iface.removePluginMenu(self.tr(u'&MSPA'), action)
            self.iface.removeToolBarIcon(action)
        del self.toolbar
        self.dlg.deleteLater()

    def run(self):
        """Show the dialog and check for a newer plugin version."""
        self.check_for_update()
        self.dlg.show()
        self.dlg.raise_()

    def check_for_update(self):
        """Warn when the version published on GitHub is newer."""
        if self._update_checked:
            return
        self._update_checked = True
        try:
            response = urllib.request.urlopen(UPDATE_URL, timeout=5)
            latest = response.read().decode("utf-8", "ignore").strip()
        except Exception:
            return
        if version_tuple(latest) > version_tuple(PLUGIN_VERSION):
            QMessageBox.information(
                self.dlg, "MSPA update",
                "A newer MSPA QGIS plugin (%s) is available:\n%s%s"
                % (latest, RELEASE_URL, latest))

    def open_plugin_guide(self):
        QDesktopServices.openUrl(QUrl(PLUGIN_DOC_URL))

    def open_mspa_guide(self):
        guide = os.path.join(self.plugin_dir, "MSPA_Guide.pdf")
        if os.path.isfile(guide):
            QDesktopServices.openUrl(QUrl.fromLocalFile(guide))
        else:
            QDesktopServices.openUrl(QUrl(GUIDE_URL))

    def choose_input_file(self):
        """Ask for the input image without using themed file icons."""
        start = ""
        if self._input:
            start = os.path.dirname(self._input["path"])
        if USE_CUSTOM_PICKER:
            dialog = MspaPathDialog(
                self.dlg, "Select the MSPA input image", start)
            if dialog.exec():
                return dialog.result_path()
            return ""
        filename, _ = QFileDialog.getOpenFileName(
            self.dlg, "Select the MSPA input image", start,
            "TIFF images (*.tif *.tiff)")
        return filename or ""

    def choose_output_directory(self, start):
        """Ask for the output folder."""
        if USE_CUSTOM_PICKER:
            dialog = MspaPathDialog(
                self.dlg, "Select the output folder", start, directory=True)
            if dialog.exec():
                return dialog.result_path()
            return ""
        return QFileDialog.getExistingDirectory(
            self.dlg, "Select the output folder", start) or ""

    def validate_path(self):
        """Allow the path field to be used without opening a file dialog."""
        filename = self.dlg.showPath.text().strip()
        if not filename:
            self.dlg.startButton.setEnabled(False)
            return
        try:
            self.read_input(filename)
        except ValueError as exc:
            self.dlg.startButton.setEnabled(False)
            self.dlg.showPath.setToolTip(str(exc))
        else:
            self.dlg.startButton.setEnabled(True)
            self.dlg.showPath.setToolTip("")

    def select_input(self):
        """Ask for the input image and validate it."""
        filename = self.choose_input_file()
        if not filename:
            return
        self.dlg.showPath.setText(filename)
        self.dlg.startButton.setEnabled(False)
        try:
            self.read_input(filename)
        except ValueError as exc:
            QMessageBox.critical(self.dlg, "MSPA", str(exc))
            return
        self.dlg.startButton.setEnabled(True)

    def read_input(self, filename):
        """Validate the image and remember its georeferencing."""
        self._input = None
        if gdal is None:
            raise ValueError(
                "QGIS's GDAL Python bindings (osgeo) are not available.")
        if not os.path.isfile(filename):
            raise ValueError("The selected image does not exist.")

        dataset = gdal.Open(filename, gdal.GA_ReadOnly)
        if dataset is None:
            raise ValueError(
                "The image could not be opened. Please load an "
                "MSPA-compliant image.")

        projection = dataset.GetProjection()
        gcps = dataset.GetGCPs()
        gcp_projection = dataset.GetGCPProjection()
        if not projection:
            projection = gcp_projection

        geotransform = dataset.GetGeoTransform()
        has_transform = (geotransform is not None
                         and tuple(geotransform) != (0.0, 1.0, 0.0, 0.0, 0.0, 1.0))
        width = dataset.RasterXSize
        height = dataset.RasterYSize
        bands = dataset.RasterCount
        band = dataset.GetRasterBand(1) if bands else None

        if bands != 1:
            raise ValueError(
                "The image is not a single band image. Please load an "
                "MSPA-compliant image.")
        bandtype = gdal.GetDataTypeName(band.DataType)
        if bandtype != "Byte":
            raise ValueError(
                "The band type is not Byte, it is " + bandtype +
                ". Please load an MSPA-compliant image.")
        if width < MIN_SIZE and height < MIN_SIZE:
            raise ValueError(
                "The x and/or the y size of the image is smaller than %d "
                "pixels. Please load an MSPA-compliant image." % MIN_SIZE)
        pixels = width * height
        if pixels > MAX_PIXELS:
            raise ValueError(
                "The image has %d pixels (%.1f million), which is above the "
                "limit of %d million pixels (about 20,000 x 20,000). Use the "
                "MSPA standalone tool or GuidosToolbox for very large images."
                % (pixels, pixels / 1e6, MAX_PIXELS // 1000000))

        try:
            _minimum, maximum = band.ComputeRasterMinMax(False)
        except Exception:
            raise ValueError(
                "The pixel values of the image could not be read. Please "
                "load an MSPA-compliant image.")
        if maximum is None:
            raise ValueError(
                "The pixel values of the image could not be read. Please "
                "load an MSPA-compliant image.")
        if maximum > 2:
            raise ValueError(
                "The maximum value for the band is bigger than 2 (%d). "
                "Please load an MSPA-compliant image." % int(maximum))
        if maximum < 2:
            raise ValueError(
                "The image contains no foreground (value 2). Please load an "
                "MSPA-compliant image.")

        self._input = {
            "path": filename,
            "width": width,
            "height": height,
            "pixels": pixels,
            "projection": projection,
            "geotransform": geotransform if has_transform else None,
            "gcps": gcps,
            "gcp_projection": gcp_projection,
        }
        dataset = None

    def normalise_input(self, source, target):
        """Write a plain, tiled-free TIFF that MSPA can read."""
        dataset = gdal.Open(source, gdal.GA_ReadOnly)
        if dataset is None:
            raise RuntimeError("The input image could not be opened.")
        driver = gdal.GetDriverByName("GTiff")
        result = driver.CreateCopy(
            target, dataset, 1,
            ["TILED=NO", "PROFILE=BASELINE", "COMPRESS=LZW"])
        dataset = None
        if result is None:
            raise RuntimeError(
                "The input image could not be prepared for MSPA.")
        result = None

    def set_georeferencing(self, path, params_tag):
        """Restore the extent, projection and GTB metadata of the result."""
        dataset = gdal.Open(path, gdal.GA_Update)
        if dataset is None:
            raise RuntimeError("The MSPA result could not be reopened.")
        if self._input["projection"]:
            dataset.SetProjection(self._input["projection"])
        if self._input["gcps"]:
            dataset.SetGCPs(self._input["gcps"],
                            self._input["gcp_projection"])
        elif self._input["geotransform"] is not None:
            dataset.SetGeoTransform(self._input["geotransform"])
        input_name = os.path.splitext(
            os.path.basename(self._input["path"]))[0]
        dataset.SetMetadataItem(
            "TIFFTAG_DOCUMENTNAME", input_name + "_" + params_tag + ".tif")
        dataset.SetMetadataItem(
            "TIFFTAG_IMAGEDESCRIPTION",
            "GTB_MSPA, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/ "
            + params_tag)
        dataset.SetMetadataItem(
            "TIFFTAG_DATETIME", strftime("%Y:%m:%d %H:%M:%S"))
        dataset.FlushCache()
        dataset = None

    def process_image(self):
        """Run MSPA on the selected image."""
        filename = self.dlg.showPath.text().strip()
        if not filename:
            QMessageBox.critical(
                self.dlg, "MSPA", "Please select an input image first.")
            return
        if self._input is None or self._input["path"] != filename:
            try:
                self.read_input(filename)
            except ValueError as exc:
                QMessageBox.critical(self.dlg, "MSPA", str(exc))
                return

        params = (self.dlg.comboBox_1.currentText(),
                  self.dlg.comboBox_2.currentText(),
                  self.dlg.comboBox_3.currentText(),
                  self.dlg.comboBox_4.currentText())
        params_tag = "_".join(params)
        self.dlg.startButton.setEnabled(False)

        progress = QProgressDialog("Running MSPA ...", "Cancel", 0, 0,
                                   self.dlg)
        progress.setWindowTitle("MSPA")
        progress.setRange(0, 0)
        progress.setWindowModality(WINDOW_MODAL)
        progress.setMinimumDuration(0)
        progress.show()
        QApplication.processEvents()

        workdir = None
        try:
            executable = mspa_binary(self.plugin_dir)
            workdir = tempfile.mkdtemp(prefix="mspa_qgis_")
            source = os.path.join(workdir, "in.tif")
            result = os.path.join(workdir, "out.tif")
            self.normalise_input(self._input["path"], source)

            args = [executable, "-i", source, "-o", "out.tif",
                    "-odir", workdir,
                    "-graphfg", params[0], "-eew", params[1],
                    "-transition", params[2], "-internal", params[3]]
            if self._input["pixels"] > DISK_PIXELS:
                args.append("-disk")

            startup = {}
            if os.name == "nt":
                startup["creationflags"] = getattr(
                    subprocess, "CREATE_NO_WINDOW", 0x08000000)
            process = subprocess.Popen(
                args, cwd=workdir, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, universal_newlines=True,
                **startup)
            while True:
                try:
                    output, _ = process.communicate(timeout=0.2)
                    break
                except subprocess.TimeoutExpired:
                    QApplication.processEvents()
                    if progress.wasCanceled():
                        process.kill()
                        output, _ = process.communicate()
                        raise RuntimeError("MSPA was cancelled.")
            progress.close()

            if process.returncode != 0 or not os.path.isfile(result):
                raise RuntimeError(
                    "MSPA could not process the image:\n"
                    + (output or "").strip() +
                    "\n\nIf the input is a tiled or compressed TIFF, export "
                    "it as an uncompressed GeoTIFF and retry.")
            if not os.path.isfile(result) or os.path.getsize(result) == 0:
                raise RuntimeError("MSPA did not write a result image.")

            self.set_georeferencing(result, params_tag)
            self.save_result(result, params_tag)
            self.dlg.close()
        except Exception as exc:
            progress.close()
            QMessageBox.critical(self.dlg, "MSPA", str(exc))
        finally:
            progress.close()
            self.dlg.startButton.setEnabled(True)
            if workdir:
                shutil.rmtree(workdir, ignore_errors=True)

    def save_result(self, result, params_tag):
        """Ask where to store the GeoTIFF and add it to the map."""
        box = QMessageBox(self.dlg)
        box.setWindowTitle("MSPA finished")
        box.setIcon(MSG_INFORMATION)
        box.setText("The image was processed successfully.")
        box.setInformativeText(
            "Save the result as a GeoTIFF and add it to the map?")
        box.setDetailedText(
            "MSPA parameters:\nFGconn: %s\nEdgeWidth: %s\n"
            "Transition: %s\nIntext: %s" % (
                self.dlg.comboBox_1.currentText(),
                self.dlg.comboBox_2.currentText(),
                self.dlg.comboBox_3.currentText(),
                self.dlg.comboBox_4.currentText()))
        save = box.addButton("Save GeoTIFF", ROLE_ACCEPT)
        box.addButton("Close", ROLE_REJECT)
        box.exec()
        if box.clickedButton() is not save:
            return

        directory = self.choose_output_directory(
            os.path.dirname(self._input["path"]))
        if not directory:
            return

        docname = (os.path.splitext(
            os.path.basename(self._input["path"]))[0]
            + "_" + params_tag + ".tif")
        target = os.path.join(directory, docname)
        if os.path.exists(target):
            answer = QMessageBox.question(
                self.dlg, "MSPA",
                "The file already exists and will be overwritten:\n" + target,
                MSG_YES | MSG_NO, MSG_NO)
            if answer != MSG_YES:
                return

        dataset = gdal.Open(result, gdal.GA_ReadOnly)
        driver = gdal.GetDriverByName("GTiff")
        created = driver.CreateCopy(
            target, dataset, 1, ["COMPRESS=LZW"])
        dataset = None
        if created is None:
            raise RuntimeError(
                "The result could not be saved in the selected folder. "
                "Please check that the folder is writable and try again.")
        created = None

        # CreateCopy may not carry every tag; set them on the final file.
        self.set_georeferencing(target, params_tag)

        layer = QgsRasterLayer(target, docname[:-4])
        if not layer.isValid():
            raise RuntimeError(
                "The result was saved but could not be loaded as a layer:\n"
                + target)
        QgsProject.instance().addMapLayer(layer)
        self.iface.messageBar().pushSuccess(
            "MSPA", "GeoTIFF saved: " + target)
