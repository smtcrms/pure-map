/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2018 Rinigus
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
import "platform"

StylerPL {
    id: styler

    property string fg                   // foreground color (scale bar, metrics)
    property string iconVariant          // type of icons, let empty for default version, "white" for white icons
    property real   indicatorSize: styler.themeIconSizeSmall*1.4142*(1 + 0.2) / 4 // indicator height and width - do not change in defaults or style
    property string itemBg               // map item (buttons, street name) outline
    property string itemFg               // map item (buttons, street name) foreground
    // itemPressed should never be specified in style nor defaults
    property color  itemPressed: Qt.rgba( (_itemColBg.r*3+_itemColFg.r)/4,
                                          (_itemColBg.g*3+_itemColFg.g)/4,
                                          (_itemColBg.b*3+_itemColFg.b)/4,
                                          (_itemColBg.a*3+_itemColFg.a)/4)
    property string maneuver             // maneuver circle inner color
    property string position             // variant of position marker, set to "" for default
    property string positionUncertainty  // position marker uncertainty
    property string route                // route color on the map. also used for maneuver markers
    property real   routeOpacity         // opacity of route
    property string shadowColor          // shadow color used on map buttons and panels
    property real   shadowOpacity: 0.35  // shadow opacity - do not change in defaults or style
    property int    shadowRadius: 10     // shadow radius - do not change in defaults or style

    // private properties
    property color  _itemColBg: itemBg
    property color  _itemColFg: itemFg

    function apply(guistyle) {
        defaults();
        if (guistyle == null) return;
        for (var i in guistyle) {
            if (guistyle.hasOwnProperty(i) && styler.hasOwnProperty(i)) {
                styler[i] = guistyle[i];
            }
        }
    }

    function defaults() {
        fg = "black";
        iconVariant = "";
        maneuver = "white";
        position = "";
        positionUncertainty = "#87cefa";
        route = "#0540ff";
        routeOpacity = 0.5;
        itemFg = "black";
        itemBg = "white";
        shadowColor = "black";

    }
}
