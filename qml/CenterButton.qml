/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2018 Osmo Salomaa, 2018 Rinigus
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

MapButton {
    id: button
    anchors.bottom: parent.verticalCenter
    anchors.right: parent.right
    iconHeight: styler.themeIconSizeSmall
    iconSource: app.getIcon("icons/center")
    indicator: map.autoCenter
    states: [
        State {
            when: hidden && (app.mode === modes.navigate || app.mode === modes.followMe) && !app.portrait
            AnchorChanges {
                target: button
                anchors.bottom: navigationSign.bottom
                anchors.horizontalCenter: undefined
                anchors.left: undefined
                anchors.right: northArrow.left
                anchors.top: undefined
            }
            PropertyChanges {
                target: button
                anchors.bottomMargin: 0
            }
        },
        State {
            when: hidden && (app.mode === modes.navigate || app.mode === modes.followMe)
            AnchorChanges {
                target: button
                anchors.bottom: navigationSign.bottom
                anchors.horizontalCenter: northArrow.horizontalCenter
                anchors.left: undefined
                anchors.right: undefined
                anchors.top: undefined
            }
            PropertyChanges {
                target: button
                anchors.bottomMargin: 0
            }
        },
        State {
            when: hidden
            AnchorChanges {
                target: button
                anchors.bottom: parent.verticalCenter
                anchors.horizontalCenter: undefined
                anchors.left: parent.right
                anchors.right: undefined
                anchors.top: undefined
            }
            PropertyChanges {
                target: button
                anchors.topMargin: 0
            }
        },
        State {
            when: (app.mode === modes.navigate || app.mode === modes.followMe) && !app.portrait
            AnchorChanges {
                target: button
                anchors.bottom: undefined
                anchors.horizontalCenter: undefined
                anchors.left: undefined
                anchors.right: northArrow.left
                anchors.top: navigationSign.bottom
            }
        },
        State {
            when: (app.mode === modes.navigate || app.mode === modes.followMe)
            AnchorChanges {
                target: button
                anchors.bottom: undefined
                anchors.horizontalCenter: northArrow.horizontalCenter
                anchors.left: undefined
                anchors.right: undefined
                anchors.top: navigationSign.bottom
            }
        }
    ]
    transitions: Transition {
        AnchorAnimation { duration: app.conf.animationDuration; }
        onRunningChanged: {
            if (running) button.visible = true;
            else if (hidden) button.visible = false;
            else button.visible = true;
        }
    }
    z: 500

    property bool hidden: app.infoPanelOpen || (map.cleanMode && !app.conf.mapModeCleanShowCenter)
    property bool nextClickToAuto: false

    Timer {
        id: timer
        interval: 5000
        repeat: false
        onTriggered: button.nextClickToAuto = false;
    }

    onClicked: {
        // same ID is used as in MapGestureArea
        var notifyId = "centerButton";
        if (app.map.autoCenter) {
            app.map.autoCenter = false;
            notification.flash(app.tr("Auto-center off"),
                               notifyId);
            return;
        }

        map.centerOnPosition();
        if (nextClickToAuto) {
            map.autoCenter = true;
            notification.flash(app.tr("Auto-center on"),
                               notifyId);
        }
        else {
            nextClickToAuto = true;
            timer.restart();
            notification.flash(app.tr("Tap center button again for auto-center"),
                               notifyId,
                               timer.interval / 1000);
        }
    }
}
