/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import "."

Dialog {
    id: dialog
    allowedOrientations: Orientation.All
    canAccept: dialog.query.length > 0
    property var history: []
    property string query: ""
    SilicaListView {
        id: listView
        anchors.fill: parent
        // Prevent list items from stealing focus.
        currentIndex: -1
        delegate: ListItem {
            id: listItem
            contentHeight: Theme.itemSizeSmall
            menu: contextMenu
            ListView.onRemove: animateRemoval(listItem)
            ListItemLabel {
                anchors.leftMargin: listView.searchField.textLeftMargin
                color: listItem.highlighted ?
                    Theme.highlightColor : Theme.primaryColor
                height: Theme.itemSizeSmall
                text: model.place
            }
            ContextMenu {
                id: contextMenu
                MenuItem {
                    text: "Remove"
                    onClicked: {
                        py.call_sync("poor.app.history.remove_place", [model.place]);
                        listView.model.remove(index);
                    }
                }
            }
            onClicked: {
                dialog.query = model.place;
                dialog.accept();
            }
        }
        header: Column {
            height: dialogHeader.height + gpsItem.height + searchField.height
            width: parent.width
            DialogHeader { id: dialogHeader }
            ListItem {
                id: gpsItem
                contentHeight: Theme.itemSizeSmall
                ListItemLabel {
                    anchors.leftMargin: listView.searchField.textLeftMargin
                    color: Theme.highlightColor
                    height: Theme.itemSizeSmall
                    text: "Current position"
                }
                onClicked: {
                    dialog.query = "Current position";
                    dialog.accept();
                }
            }
            SearchField {
                id: searchField
                placeholderText: "Address, landmark, etc."
                width: parent.width
                EnterKey.enabled: searchField.text.length > 0
                EnterKey.onClicked: dialog.accept();
                onTextChanged: {
                    dialog.query = searchField.text;
                    dialog.populate();
                }
            }
            Component.onCompleted: listView.searchField = searchField;
        }
        model: ListModel {}
        property var searchField
        VerticalScrollDecorator {}
    }
    onStatusChanged: {
        if (dialog.status == PageStatus.Activating) {
            dialog.history = py.evaluate("poor.app.history.places");
            dialog.populate();
        }
    }
    function populate() {
        // Load search history items from the Python backend.
        listView.model.clear();
        var query = listView.searchField.text.toLowerCase();
        var nstart = 0;
        for (var i = 0; i < dialog.history.length; i++) {
            var historyItem = dialog.history[i].toLowerCase();
            if (query.length > 0 && historyItem.indexOf(query) == 0) {
                listView.model.insert(nstart++, {"place": dialog.history[i]});
                if (listView.model.count >= 100) break;
            } else if (query == "" || historyItem.indexOf(query) > 0) {
                listView.model.append({"place": dialog.history[i]});
                if (listView.model.count >= 100) break;
            }
        }
        // XXX: Work around a bug causing the search field to disappear
        // if text has been typed, but there are no matches.
        listView.model.append({"place": listView.searchField.text});
    }
}
