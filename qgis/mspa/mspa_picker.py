# -*- coding: utf-8 -*-
"""
/***************************************************************************
 MspaPathDialog
                                 A QGIS plugin
 Morphological Spatial Pattern Analysis
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

from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import (
    QDialog, QHBoxLayout, QLabel, QLineEdit, QListWidget, QListWidgetItem,
    QPushButton, QVBoxLayout)

# Qt.ItemDataRole.UserRole is 0x0100 in both Qt 5 and Qt 6.
USER_ROLE = 0x0100


class MspaPathDialog(QDialog):
    """Small file/folder chooser built from plain Qt widgets.

    QFileDialog asks the platform icon theme for file and folder icons. On
    some Linux systems (for example Fedora 45 with GTK's glycin loader) that
    lookup aborts the whole process. This dialog does not request theme icons
    and does not use QFileDialog at all.
    """

    def __init__(self, parent, title, start_path, directory=False):
        super(MspaPathDialog, self).__init__(parent)
        self.directory_only = directory
        self.current = ""
        self.setWindowTitle(title)
        self.setWindowIcon(QIcon(os.path.join(
            os.path.dirname(__file__), "icon.png")))
        self.resize(720, 480)

        self.path = QLineEdit()
        self.path.setToolTip(
            "Full path: press Enter to open a folder or select a file")
        self.list = QListWidget()
        self.status = QLabel("")
        self.status.setWordWrap(True)

        self.up_button = QPushButton("Up")
        self.home_button = QPushButton("Home")
        self.accept_button = QPushButton(
            "Select folder" if directory else "Open")
        self.cancel_button = QPushButton("Cancel")
        self.accept_button.setDefault(True)

        buttons = QHBoxLayout()
        buttons.addWidget(self.up_button)
        buttons.addWidget(self.home_button)
        buttons.addStretch(1)
        buttons.addWidget(self.accept_button)
        buttons.addWidget(self.cancel_button)

        layout = QVBoxLayout(self)
        layout.addWidget(self.path)
        layout.addWidget(self.list, 1)
        layout.addWidget(self.status)
        layout.addLayout(buttons)

        self.path.returnPressed.connect(self.accept_path)
        self.list.itemDoubleClicked.connect(self.open_item)
        self.up_button.clicked.connect(self.go_up)
        self.home_button.clicked.connect(self.go_home)
        self.accept_button.clicked.connect(self.accept_selection)
        self.cancel_button.clicked.connect(self.reject)

        start = start_path or os.path.expanduser("~")
        if not os.path.isdir(start):
            start = os.path.dirname(start) or os.path.expanduser("~")
        self.set_directory(start)

    def set_directory(self, path):
        path = os.path.abspath(path)
        if not os.path.isdir(path):
            self.status.setText("Not a folder: " + path)
            return
        self.current = path
        self.path.setText(path)
        self.status.setText("")
        self.list.clear()
        try:
            names = os.listdir(path)
        except OSError as exc:
            self.status.setText(str(exc))
            return

        folders = []
        files = []
        for name in names:
            full = os.path.join(path, name)
            if os.path.isdir(full):
                folders.append(name)
            elif (not self.directory_only
                  and name.lower().endswith((".tif", ".tiff"))):
                files.append(name)

        for name in sorted(folders, key=str.lower):
            item = QListWidgetItem(name + os.sep)
            item.setData(USER_ROLE, os.path.join(path, name))
            self.list.addItem(item)
        for name in sorted(files, key=str.lower):
            item = QListWidgetItem(name)
            item.setData(USER_ROLE, os.path.join(path, name))
            self.list.addItem(item)

        self.accept_button.setEnabled(True)

    def result_path(self):
        return self.path.text().strip()

    def open_item(self, item):
        path = item.data(USER_ROLE)
        if os.path.isdir(path):
            self.set_directory(path)
        else:
            self.path.setText(path)
            self.accept()

    def accept_path(self):
        path = self.path.text().strip()
        if os.path.isdir(path):
            self.set_directory(path)
            return
        if self.directory_only:
            self.status.setText("Please select a folder.")
            return
        if os.path.isfile(path):
            self.accept()
            return
        self.status.setText("File not found: " + path)

    def accept_selection(self):
        item = self.list.currentItem()
        path = item.data(USER_ROLE) if item is not None else ""
        if not path:
            path = self.path.text().strip()
        if self.directory_only:
            if os.path.isdir(path):
                self.path.setText(path)
                self.accept()
            elif os.path.isdir(self.current):
                self.path.setText(self.current)
                self.accept()
            else:
                self.status.setText("Please select a folder.")
            return
        if os.path.isdir(path):
            self.set_directory(path)
        elif os.path.isfile(path):
            self.path.setText(path)
            self.accept()
        else:
            self.status.setText("File not found: " + path)

    def go_up(self):
        parent = os.path.dirname(self.current)
        if parent and parent != self.current:
            self.set_directory(parent)

    def go_home(self):
        self.set_directory(os.path.expanduser("~"))
