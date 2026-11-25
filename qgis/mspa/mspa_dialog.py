# -*- coding: utf-8 -*-
"""
/***************************************************************************
 MspaDialog
                                 A QGIS plugin
 Morphological Spatial Pattern Analysis
                             -------------------
        begin                : 2018-06-19
        copyright            : (C) 2017 by European Commission JRC
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

from qgis.PyQt import uic
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import QApplication, QDialog

FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), 'mspa_dialog_base.ui'))


class MspaDialog(QDialog, FORM_CLASS):
    def __init__(self, parent=None):
        """Constructor."""
        super(MspaDialog, self).__init__(parent)
        self.setupUi(self)
        self.setWindowIcon(QIcon(os.path.join(
            os.path.dirname(__file__), 'icon.png')))
        help_icon = QIcon(os.path.join(
            os.path.dirname(__file__), 'help.png'))
        self.pluginguideButton.setIcon(help_icon)
        self.mspaguideButton.setIcon(help_icon)
        self.centerOnScreen()

    def centerOnScreen(self):
        """Center the window on the primary screen."""
        screen = QApplication.primaryScreen()
        if screen is None:
            return
        self.adjustSize()
        geometry = screen.availableGeometry()
        self.move(geometry.x() + (geometry.width() - self.width()) // 2,
                  geometry.y() + (geometry.height() - self.height()) // 2)

    def closeEvent(self, event):
        self.showPath.clear()
        self.comboBox_1.setCurrentIndex(0)
        self.comboBox_2.setCurrentIndex(0)
        self.comboBox_3.setCurrentIndex(0)
        self.comboBox_4.setCurrentIndex(0)
        self.startButton.setEnabled(False)
        super(MspaDialog, self).closeEvent(event)
