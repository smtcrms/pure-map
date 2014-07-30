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
import QtPositioning 5.0

import "js/util.js" as Util

Item {
    id: scaleBar
    anchors.bottom: map.bottom
    anchors.bottomMargin: 10
    anchors.left: map.menuButton.right
    height: base.height
    opacity: 0.9
    visible: scaleWidth > 0
    width: base.width
    z: 101
    property var prevCoord: QtPositioning.coordinate(0, 0)
    property var prevZoomLevel: -1
    property var scaleWidth: 0
    property var text: ""
    Rectangle {
        id: base
        color: "black"
        height: 2
        width: scaleBar.scaleWidth
    }
    Rectangle {
        anchors.bottom: base.top
        anchors.left: base.left
        color: "black"
        height: 10
        width: 2
    }
    Rectangle {
        anchors.bottom: base.top
        anchors.right: base.right
        color: "black"
        height: 10
        width: 2
    }
    Text {
        anchors.bottom: base.top
        anchors.bottomMargin: 2
        anchors.left: base.left
        color: "black"
        font.family: "sans-serif"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        text: scaleBar.text
        width: base.width
    }
    function update() {
        // Update scalebar for current zoom level and latitude.
        var x = map.center.longitude;
        var y = map.center.latitude;
        if (map.zoomLevel == scaleBar.prevZoomLevel &&
            Math.abs(y - scaleBar.prevCoord.latitude) < 0.1) return;
        var bbox = map.getBoundingBox();
        var tail = QtPositioning.coordinate(y, bbox[1]);
        var dist = Util.siground(map.center.distanceTo(tail)/2.5, 1);
        var tail = map.center.atDistanceAndAzimuth(dist, 45);
        var xend = Util.xcoord2xpos(tail.longitude, bbox[0], bbox[1], map.width);
        var yend = Util.ycoord2ypos(tail.latitude, bbox[2], bbox[3], map.height);
        var xd = Util.xcoord2xpos(x, bbox[0], bbox[1], map.width) - xend;
        var yd = Util.ycoord2ypos(y, bbox[2], bbox[3], map.height) - yend;
        scaleBar.scaleWidth = Math.sqrt(xd*xd + yd*yd);
        scaleBar.text = py.call_sync("poor.util.format_distance", [dist, 1]);
        scaleBar.prevCoord.longitude = map.center.longitude;
        scaleBar.prevCoord.latitude = map.center.latitude;
        scaleBar.prevZoomLevel = map.zoomLevel;
    }
}