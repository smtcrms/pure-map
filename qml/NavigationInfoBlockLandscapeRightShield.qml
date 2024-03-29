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

// used to cover speed in navigation info block in landscape
// dimesions are set in NavigationInfoBlock
Rectangle {
    x: width > 0 ? app.screenWidth - (width - radius) : app.screenWidth
    y: height > 0 ? app.screenHeight - (height - radius) : app.screenHeight
    color: navigationInfoBlock.color
    height: navigationInfoBlock.shieldRightHeight > 0 ? navigationInfoBlock.shieldRightHeight + radius : 0
    radius: styler.themePaddingLarge
    width: navigationInfoBlock.shieldRightWidth > 0 ? navigationInfoBlock.shieldRightWidth + radius : 0
    z: 400

    MouseArea {
        anchors.fill: parent
        onClicked: !app.portrait && app.showMenu();
    }

}
