/*
 * Copyright 2015 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import Ubuntu.Test 1.0

UbuntuTestCase {
    function clickItem(item, button) {
        if (button === undefined) button = Qt.LeftButton
        var center = centerOf(item)
        mouseClick(item, center.x, center.y, button)
    }

    function getListItems(listview, itemName) {
        waitForRendering(listview)
        var items = []
        if (listview) {
            // ensure all the delegates are created
            listview.cacheBuffer = listview.count * 1000

            // In some cases the ListView might add other children to the
            // contentItem, so we filter the list of children to include
            // only actual delegates (names for delegates in this case
            // follow the pattern "name_index")
            var children = listview.contentItem.children
            for (var i = 0; i < children.length; i++) {
                if (children[i].objectName.indexOf(itemName) == 0) {
                    items.push(children[i])
                }
            }
        }
        return items
    }
}
