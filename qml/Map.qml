/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa, 2018 Rinigus
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
import QtPositioning 5.3
import MapboxMap 1.0
import "."

import "js/util.js" as Util

MapboxMap {
    id: map
    anchors.fill: parent
    cacheDatabaseDefaultPath: true
    cacheDatabaseStoreSettings: false
    center: QtPositioning.coordinate(49, 13)
    metersPerPixelTolerance: Math.max(0.001, metersPerPixel*0.01) // 1 percent from the current value
    pitch: {
        if (app.mode === modes.explore || app.mode === modes.exploreRoute || format === "raster" || !map.autoRotate || !app.conf.tiltWhenNavigating) return 0;
        if (app.mode === modes.navigate) return 60;
        if (app.mode === modes.followMe) return 60;
        return 0; // should never get here
    }
    pixelRatio: styler.themePixelRatio * 1.5
    zoomLevel: 4.0

    property int    animationTime: {
        if (!map.ready) return 0;
        if (app.mode === modes.explore || app.mode === modes.exploreRoute)
            return 1000;
        // support smooth animations for position marker
        // and map center only if GPS is accurate
        return (gps.accurate ? gps.timePerUpdate : 0);
    }
    property bool   autoCenter: false
    property bool   autoRotate: false
    property bool   autoZoom: false
    property bool   cleanMode: app.conf.mapModeCleanOnStart
    property int    counter: 0
    property var    direction: {
        // prefer map matched direction, if available
        if (gps.directionValid) return gps.direction;
        if (app.navigationStatus.direction!==undefined && app.navigationStatus.direction!==null)
            return app.navigationStatus.direction;
        if (gps.directionCalculated) return gps.direction;
        return undefined;
    }
    property string firstLabelLayer: ""
    property string format: ""
    property bool   hasRoute: false
    property var    maneuvers: []
    property var    position: gps.position
    property bool   ready: false
    property var    route: {}

    readonly property var images: QtObject {
        readonly property string pixel:         "pure-image-pixel"
        readonly property string poi:           "pure-image-poi"
        readonly property string poiBookmarked: "pure-image-poi-bookmarked"
    }

    readonly property var layers: QtObject {
        readonly property string dummies:         "pure-layer-dummies"
        readonly property string maneuvers:       "pure-layer-maneuvers-active"
        readonly property string nodes:           "pure-layer-maneuvers-passive"
        readonly property string pois:            "pure-layer-pois"
        readonly property string poisBookmarked:  "pure-layer-pois-bookmarked"
        readonly property string poisSelected:    "pure-layer-pois-selected"
        readonly property string route:           "pure-layer-route"
    }

    readonly property var sources: QtObject {
        readonly property string maneuvers:      "pure-source-maneuvers"
        readonly property string pois:           "pure-source-pois"
        readonly property string poisBookmarked: "pure-source-pois-bookmarked"
        readonly property string poisSelected:   "pure-source-pois-selected"
        readonly property string route:          "pure-source-route"
    }

    Behavior on bearing {
        RotationAnimation {
            direction: RotationAnimation.Shortest
            duration: map.ready ? 500 : 0
            easing.type: Easing.Linear
        }
    }

    Behavior on center {
        CoordinateAnimation {
            duration: map.ready ? animationTime : 0
            easing.type: app.mode === modes.explore || app.mode === modes.exploreRoute ? Easing.InOutQuad : Easing.Linear
        }
    }

    Behavior on margins {
        PropertyAnimation {
            duration: map.ready ? 500 : 0
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on pitch {
        NumberAnimation {
            duration: map.ready ? 1000 : 0
            easing.type: Easing.Linear
        }
    }

    MapGestureArea {
        id: gestureArea
        integerZoomLevels: map.format === "raster"
        map: map
    }

    NarrationTimer {}

    PositionMarker { id: positionMarker }

    Timer {
        // map view mode switch timer
        interval: app.conf.mapModeAutoSwitchTime > 0 ? app.conf.mapModeAutoSwitchTime*1000 : 1000
        repeat: true
        running: !cleanMode && app.conf.mapModeAutoSwitchTime > 0
        onTriggered: {
            if (!cleanMode && app.conf.mapModeAutoSwitchTime > 0)
                cleanMode = true;
        }
    }

    Timer {
        // auto zoom
        interval: 1000
        repeat: true
        running: map.autoZoom

        // keeping reference metersPerPixel and zoomLevel. Map does
        // update metersPerPixel with some tolerance to avoid too many
        // updates. So, for calculations, we have to keep reference zoom
        // level and metersPerPixel
        property real mpp: map.metersPerPixel
        property real zmref: map.zoomLevel

        onMppChanged: zmref = map.zoomLevel

        onTriggered: {
            if (!gps.position.speedValid) return;
            var dist = mpp * map.height;
            var speed = gps.position.speed;
            var newZoom = zmref;
            var zstep = 0.1;
            if (speed > 0) newZoom -= Math.log(speed*app.conf.mapZoomAutoTime / dist) / Math.log(2);
            else newZoom = app.conf.mapZoomAutoZeroSpeedZ;
            newZoom = Math.round(newZoom / zstep) * zstep;

            if (newZoom > app.conf.mapZoomAutoZeroSpeedZ) {
                if (map.zoomLevel < app.conf.mapZoomAutoZeroSpeedZ)
                    map.setZoomLevel(app.conf.mapZoomAutoZeroSpeedZ);
            } else if (Math.abs(map.zoomLevel - newZoom) > zstep*0.5)
                map.setZoomLevel(newZoom);
        }
    }

    Connections {
        target: app
        onModeChanged: setMode()
        onPortraitChanged: map.updateMargins()
    }

    Connections {
        target: infoPanel
        onHeightChanged: map.updateMargins()
    }

    Connections {
        target: menuButton
        onHeightChanged: map.updateMargins();
    }

    Connections {
        target: navigationBlock
        onHeightChanged: map.updateMargins();
    }

    Connections {
        target: navigationInfoBlock
        onHeightChanged: map.updateMargins();
    }

    Connections {
        target: pois
        onPoiChanged: map.updatePois()
    }

    Connections {
        target: py
        onBasemapChanged: map.setBasemap();
    }

    Connections {
        target: streetName
        onHeightChanged: map.updateMargins();
    }

    Component.onCompleted: {
        map.initSources();
        map.initIcons();
        map.initLayers();
        map.configureLayers();
        map.initProperties();
        map.updatePois();
        map.updateMargins();
        map.setMode();
    }

    onAutoRotateChanged: {
        // Update map rotation to match travel direction.
        map.bearing = map.autoRotate && map.direction ? map.direction : 0;
        map.updateMargins();
    }

    onDirectionChanged: {
        // Update map rotation to match travel direction.
        var direction = map.direction || 0;
        if (map.autoRotate && Math.abs(direction - map.bearing) > 10)
            map.bearing = direction;
    }

    onErrorStringChanged: app.openMapErrorMessage(map.errorString)

    onHeightChanged: {
        map.updateMargins();
    }

    onPositionChanged: {
        map.autoCenter && map.centerOnPosition();
    }

    function _addManeuver(maneuver) {
        // Add new maneuver marker to the map.
        map.maneuvers.push({
            "arrive_instruction": maneuver.arrive_instruction || "",
            "depart_instruction": maneuver.depart_instruction || "",
            "coordinate": QtPositioning.coordinate(maneuver.y, maneuver.x),
            "duration": maneuver.duration || 0,
            "icon": maneuver.icon || "flag",
            // Needed to have separate layers via filters.
            "name": maneuver.passive ? "passive" : "active",
            "narrative": maneuver.narrative || "",
            "passive": maneuver.passive || false,
            "sign": maneuver.sign || undefined,
            "street": maneuver.street|| undefined,
            "travel_type": maneuver.travel_type || "",
            "verbal_alert": maneuver.verbal_alert || "",
            "verbal_post": maneuver.verbal_post || "",
            "verbal_pre": maneuver.verbal_pre || "",
        });
    }

    function addManeuvers(maneuvers) {
        // Add new maneuver markers to the map.
        maneuvers.forEach(map._addManeuver);
        py.call("poor.app.narrative.set_maneuvers", [maneuvers], null);
        map.updateManeuvers();
        map.saveManeuvers();
    }

    function addRoute(route, amend) {
        // Add new route polyline to the map.
        if (!amend) app.setModeExploreRoute();
        map.clearRoute();
        route.coordinates = route.x.map(function(value, i) {
            return QtPositioning.coordinate(route.y[i], route.x[i]);
        });
        map.route = {
            "coordinates": route.coordinates || [],
            "language": route.language || "en",
            "mode": route.mode || "car",
            "provider": route.provider || "",
            "x": route.x,
            "y": route.y
        };
        py.call("poor.app.narrative.set_mode", [route.mode || "car"], null);
        py.call("poor.app.narrative.set_route", [route.x, route.y], function() {
            map.hasRoute = true;
        });
        map.updateRoute();
        map.saveRoute();
        map.saveManeuvers();
        app.navigationStarted = !!amend;
    }

    function centerOnPosition() {
        // Center on the current position.
        map.setCenter(
            map.position.coordinate.longitude,
            map.position.coordinate.latitude);
    }

    function clearRoute() {
        // Remove route polyline from the map.
        map.maneuvers = [];
        map.route = {};
        py.call("poor.app.narrative.unset", [], null);
        app.navigationStatus.clear();
        map.hasRoute = false;
        map.updateManeuvers();
        map.updateRoute();
        map.saveManeuvers();
        map.saveRoute();
    }

    function configureLayers() {
        // Configure layer for selected POI markers.
        map.setPaintProperty(map.layers.poisSelected, "circle-opacity", 0);
        map.setPaintProperty(map.layers.poisSelected, "circle-radius", 16 / map.pixelRatio);
        map.setPaintProperty(map.layers.poisSelected, "circle-stroke-color", styler.route);
        map.setPaintProperty(map.layers.poisSelected, "circle-stroke-opacity", styler.routeOpacity);
        map.setPaintProperty(map.layers.poisSelected, "circle-stroke-width", 13 / map.pixelRatio);
        // Configure layer for non-bookmarked POI markers.
        map.setLayoutProperty(map.layers.pois, "icon-allow-overlap", true);
        map.setLayoutProperty(map.layers.pois, "icon-anchor", "bottom");
        map.setLayoutProperty(map.layers.pois, "icon-image", map.images.poi);
        map.setLayoutProperty(map.layers.pois, "icon-size", 1.0 / map.pixelRatio);
        map.setLayoutProperty(map.layers.pois, "text-anchor", "top");
        map.setLayoutProperty(map.layers.pois, "text-field", "{name}");
        map.setLayoutProperty(map.layers.pois, "text-optional", true);
        map.setLayoutProperty(map.layers.pois, "text-size", 12);
        map.setPaintProperty(map.layers.pois, "text-color", styler.itemFg);
        map.setPaintProperty(map.layers.pois, "text-halo-color", styler.itemBg);
        map.setPaintProperty(map.layers.pois, "text-halo-width", 2);
        // Configure layer for bookmarked POI markers.
        map.setLayoutProperty(map.layers.poisBookmarked, "icon-allow-overlap", true);
        map.setLayoutProperty(map.layers.poisBookmarked, "icon-anchor", "bottom");
        map.setLayoutProperty(map.layers.poisBookmarked, "icon-image", map.images.poiBookmarked);
        map.setLayoutProperty(map.layers.poisBookmarked, "icon-size", 1.0 / map.pixelRatio);
        map.setLayoutProperty(map.layers.poisBookmarked, "text-anchor", "top");
        map.setLayoutProperty(map.layers.poisBookmarked, "text-field", "{name}");
        map.setLayoutProperty(map.layers.poisBookmarked, "text-optional", true);
        map.setLayoutProperty(map.layers.poisBookmarked, "text-size", 12);
        map.setPaintProperty(map.layers.poisBookmarked, "text-color", styler.itemFg);
        map.setPaintProperty(map.layers.poisBookmarked, "text-halo-color", styler.itemBg);
        map.setPaintProperty(map.layers.poisBookmarked, "text-halo-width", 2);
        // Configure layer for route polyline.
        map.setLayoutProperty(map.layers.route, "line-cap", "round");
        map.setLayoutProperty(map.layers.route, "line-join", "round");
        map.setPaintProperty(map.layers.route, "line-color", styler.route);
        map.setPaintProperty(map.layers.route, "line-opacity", styler.routeOpacity);
        map.setPaintProperty(map.layers.route, "line-width", 22 / map.pixelRatio);
        // Configure layer for active maneuver markers.
        map.setPaintProperty(map.layers.maneuvers, "circle-color", styler.maneuver);
        map.setPaintProperty(map.layers.maneuvers, "circle-pitch-alignment", "map");
        map.setPaintProperty(map.layers.maneuvers, "circle-radius", 11 / map.pixelRatio);
        map.setPaintProperty(map.layers.maneuvers, "circle-stroke-color", styler.route);
        map.setPaintProperty(map.layers.maneuvers, "circle-stroke-opacity", styler.routeOpacity);
        map.setPaintProperty(map.layers.maneuvers, "circle-stroke-width", 8 / map.pixelRatio);
        // Configure layer for passive maneuver markers.
        map.setPaintProperty(map.layers.nodes, "circle-color", styler.maneuver);
        map.setPaintProperty(map.layers.nodes, "circle-pitch-alignment", "map");
        map.setPaintProperty(map.layers.nodes, "circle-radius", 5 / map.pixelRatio);
        map.setPaintProperty(map.layers.nodes, "circle-stroke-color", styler.route);
        map.setPaintProperty(map.layers.nodes, "circle-stroke-opacity", styler.routeOpacity);
        map.setPaintProperty(map.layers.nodes, "circle-stroke-width", 8 / map.pixelRatio);
        // Configure layer for dummy symbols that knock out road shields etc.
        map.setLayoutProperty(map.layers.dummies, "icon-image", map.images.pixel);
        map.setLayoutProperty(map.layers.dummies, "icon-padding", 20 / map.pixelRatio);
        map.setLayoutProperty(map.layers.dummies, "icon-rotation-alignment", "map");
        map.setLayoutProperty(map.layers.dummies, "visibility", "visible");
    }

    function fitViewToPois(pois) {
        // Set center and zoom so that given POIs are visible.
        map.autoCenter = false;
        map.autoRotate = false;
        map.fitView(pois.map(function(poi) {
            return poi.coordinate || QtPositioning.coordinate(poi.y, poi.x);
        }));
    }

    function fitViewToRoute() {
        // Set center and zoom so that the whole route is visible.
        map.autoCenter = false;
        map.autoRotate = false;
        map.fitView(map.route.coordinates);
    }

    function getDestination() {
        // Return coordinates of the route destination.
        var destination = map.route.coordinates[map.route.coordinates.length - 1];
        return [destination.longitude, destination.latitude];
    }

    function getPosition() {
        // Return the coordinates of the current position.
        return [map.position.coordinate.longitude, map.position.coordinate.latitude];
    }

    function initIcons() {
        var suffix = "";
        if (styler.position) suffix = "-" + styler.position;
        map.addImagePath(map.images.poi, Qt.resolvedUrl(app.getIconScaled("icons/marker/marker-stroked" + suffix, true)));
        map.addImagePath(map.images.poiBookmarked, Qt.resolvedUrl(app.getIconScaled("icons/marker/marker" + suffix, true)));
    }

    function initLayers() {
        // Initialize layers for POI markers, route polyline and maneuver markers.
        map.addLayer(map.layers.poisSelected, {"type": "circle", "source": map.sources.poisSelected});
        map.addLayer(map.layers.pois, {"type": "symbol", "source": map.sources.pois});
        map.addLayer(map.layers.poisBookmarked, {"type": "symbol", "source": map.sources.poisBookmarked});
        map.addLayer(map.layers.route, {"type": "line", "source": map.sources.route}, map.firstLabelLayer);
        map.addLayer(map.layers.maneuvers, {
            "type": "circle",
            "source": map.sources.maneuvers,
            "filter": ["==", "name", "active"],
        }, map.firstLabelLayer);
        map.addLayer(map.layers.nodes, {
            "type": "circle",
            "source": map.sources.maneuvers,
            "filter": ["==", "name", "passive"],
        }, map.firstLabelLayer);
        // Add transparent 1x1 pixels at maneuver points to knock out road shields etc.
        // that would otherwise overlap with the above maneuver and node circles.
        map.addImagePath(map.images.pixel, Qt.resolvedUrl("icons/pixel.png"));
        map.addLayer(map.layers.dummies, {"type": "symbol", "source": map.sources.maneuvers});
    }

    function initProperties() {
        // Initialize map properties and restore saved overlays.
        map.setBasemap();
        map.setModeExplore();
        map.setZoomLevel(app.conf.get("zoom"));
        map.autoCenter = app.conf.get("auto_center");
        map.autoRotate = app.conf.get("auto_rotate");
        var center = app.conf.get("center");
        map.setCenter(center[0], center[1]);
        map.loadRoute();
        map.loadManeuvers();
        map.ready = true;
    }

    function initSources() {
        // Initialize sources for map overlays.
        map.addSourcePoints(map.sources.poisSelected, []);
        map.addSourcePoints(map.sources.pois, []);
        map.addSourcePoints(map.sources.poisBookmarked, []);
        map.addSourceLine(map.sources.route, []);
        map.addSourcePoints(map.sources.maneuvers, []);
    }

    function initVoiceNavigation() {
        // Initialize a TTS engine for the current routing instructions.
        if (app.conf.voiceNavigation) {
            var args = [map.route.language, app.conf.voiceGender];
            py.call_sync("poor.app.narrative.set_voice", args);
            var engine = py.evaluate("poor.app.narrative.voice_engine");
            if (engine) {
                notification.flash(app.tr("Voice navigation on"), "mapVoice");
                app.playMaybe("std:starting navigation");
            } else
                notification.flash(app.tr("Voice navigation unavailable: missing Text-to-Speech (TTS) engine for selected language"), "mapVoice");
        } else {
            py.call_sync("poor.app.narrative.set_voice", [null, null]);
        }
    }

    function loadManeuvers() {
        // Restore maneuver markers from JSON file.
        py.call("poor.storage.read_maneuvers", [], function(data) {
            data && data.length > 0 && map.addManeuvers(data);
        });
    }

    function loadRoute() {
        // Restore route polyline from JSON file.
        py.call("poor.storage.read_route", [], function(data) {
            data.x && data.x.length > 0 && map.addRoute(data);
        });
    }

    function saveManeuvers() {
        // Save maneuver markers to JSON file.
        var data = Util.pointsToJson(map.maneuvers);
        py.call_sync("poor.storage.write_maneuvers", [data]);
    }

    function saveRoute() {
        // Save route polyline to JSON file.
        var data = Util.polylineToJson(map.route);
        py.call_sync("poor.storage.write_route", [data]);
    }

    function setBasemap() {
        // Set the basemap to use and related properties.
        map.firstLabelLayer = py.evaluate("poor.app.basemap.first_label_layer");
        map.format = py.evaluate("poor.app.basemap.format");
        map.urlSuffix = py.evaluate("poor.app.basemap.url_suffix");
        py.evaluate("poor.app.basemap.style_url") ?
            (map.styleUrl  = py.evaluate("poor.app.basemap.style_url")) :
            (map.styleJson = py.evaluate("poor.app.basemap.style_json"));
        attributionButton.logo = py.evaluate("poor.app.basemap.logo");
        styler.apply(py.evaluate("poor.app.basemap.style_gui"))
        map.initIcons();
        map.initLayers();
        map.configureLayers();
        positionMarker.initIcons();
    }

    function setCenter(x, y) {
        // Center on the given coordinates.
        if (!x || !y) return;
        map.center = QtPositioning.coordinate(y, x);
    }

    function setMode() {
        if (app.mode === modes.explore || app.mode === modes.exploreRoute) setModeExplore();
        else if (app.mode === modes.followMe) setModeFollowMe();
        else if (app.mode === modes.navigate) setModeNavigate();
        else console.log("Something is terribly wrong - unknown mode in Map.setMode: " + app.mode);
    }

    function setModeExplore() {
        // map used to explore it
        if (app.conf.mapZoomAutoWhenNavigating) map.autoZoom = false;
        map.autoCenter = false;
        map.autoRotate = false;
        if (map.zoomLevel > 14) map.setZoomLevel(14);
        map.setScale(app.conf.get("map_scale"));
    }

    function setModeFollowMe() {
        // follow me mode
        var scale = app.conf.get("map_scale_navigation_" + (app.conf.mapMatchingWhenFollowing !== "none" ? app.conf.mapMatchingWhenFollowing : "car") );
        var zoom = 15 - (scale > 1 ? Math.log(scale)*Math.LOG2E : 0);
        if (map.zoomLevel < zoom) map.setZoomLevel(zoom);
        map.setScale(scale);
        map.centerOnPosition();
        map.autoCenter = true;
        map.autoRotate = app.conf.autoRotateWhenNavigating;
        if (app.conf.mapZoomAutoWhenNavigating) map.autoZoom = true;
    }

    function setModeNavigate() {
        // map during navigation
        var scale = app.conf.get("map_scale_navigation_" + route.mode);
        var zoom = 15 - (scale > 1 ? Math.log(scale)*Math.LOG2E : 0);
        if (map.zoomLevel < zoom) map.setZoomLevel(zoom);
        map.setScale(scale);
        map.centerOnPosition();
        map.autoCenter = true;
        map.autoRotate = app.conf.autoRotateWhenNavigating;
        if (app.conf.mapZoomAutoWhenNavigating) map.autoZoom = true;
        map.initVoiceNavigation();
    }

    function setScale(scale) {
        // Set the map scaling via its pixel ratio.
        map.pixelRatio = styler.themePixelRatio * 1.5 * scale;
        map.configureLayers();
        positionMarker.configureLayers();
    }

    function setSelectedPoi(coordinate) {
        if (coordinate===undefined)
            map.updateSourcePoints(map.sources.poisSelected, []);
        else
            map.updateSourcePoints(map.sources.poisSelected, [coordinate]);
    }

    function updateManeuvers() {
        // Update maneuver marker on the map.
        var coords = Util.pluck(map.maneuvers, "coordinate");
        var names  = Util.pluck(map.maneuvers, "name");
        map.updateSourcePoints(map.sources.maneuvers, coords, names);
        app.narrativePageSeen = false;
    }

    function updateMargins() {
        // Calculate new margins and set them for the map.
        var header = navigationBlock && navigationBlock.height > 0 ? navigationBlock.height : map.height*0.05;
        var footer = !app.infoPanelOpen && (app.mode === modes.explore || app.mode === modes.exploreRoute) && menuButton ? menuButton.height + menuButton.anchors.bottomMargin : 0;
        footer += !app.infoPanelOpen && (app.mode === modes.navigate || app.mode === modes.followMe) && app.portrait && navigationInfoBlock ? navigationInfoBlock.height : 0;
        footer += !app.infoPanelOpen && (app.mode === modes.navigate || app.mode === modes.followMe) && streetName ? streetName.height : 0
        footer += app.infoPanelOpen && infoPanel ? infoPanel.height : 0
        footer = Math.min(footer, map.height / 2.0);

        // If auto-rotate is on, the user is always heading up
        // on the screen and should see more ahead than behind.
        var marginY = (footer*1.0)/map.height;
        var marginHeight = (map.autoRotate ? 0.2 : 1.0) * (1.0*(map.height - header - footer)) / map.height;
        map.margins = Qt.rect(0.05, marginY, 0.9, marginHeight);
    }

    function updatePois() {
        // Update POI markers on the map.
        var regCoor = [];
        var regName = [];
        var bookmarkedCoor = [];
        var bookmarkedName = [];
        for (var i = 0; i < pois.pois.length; i++) {
            if (pois.pois[i].bookmarked) {
                bookmarkedCoor.push(pois.pois[i].coordinate);
                bookmarkedName.push(pois.pois[i].title);
            } else {
                regCoor.push(pois.pois[i].coordinate);
                regName.push(pois.pois[i].title);
            }
        }
        map.updateSourcePoints(map.sources.pois, regCoor, regName);
        map.updateSourcePoints(map.sources.poisBookmarked, bookmarkedCoor, bookmarkedName);
    }

    function updateRoute() {
        // Update route polyline on the map.
        if (map.route.coordinates)
            map.updateSourceLine(map.sources.route, map.route.coordinates);
        else
            map.updateSourceLine(map.sources.route, []);
    }

}
