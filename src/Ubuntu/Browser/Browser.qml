/*
 * Copyright 2013 Canonical Ltd.
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

import QtQuick 2.0
import QtWebKit 3.0
import Ubuntu.Browser 0.1
import Ubuntu.Components 0.1
import Ubuntu.HUD 1.0 as HUD

FocusScope {
    id: browser

    property bool chromeless: false
    property string desktopFileHint: ""
    property real qtwebkitdpr
    property bool developerExtrasEnabled: false
    // necessary so that all widgets (including popovers) follow that
    property alias automaticOrientation: orientationHelper.automaticOrientation

    property alias currentWebview: tabsModel.currentWebview
    property string title: currentWebview ? currentWebview.title : ""

    focus: true

    HUD.HUD {
        id: hud
        /*
         * As an unfortunate implementation detail the applicationIdentifier is
         * a bit special property of the HUD. It can only be set once; when it's set to
         * anything else than an empty string (which happens to be the default value)
         * the application gets registered to HUD with the given identifier which can not
         * be changed afterwards.
         *
         * Therefore we need to have the special "<not set>" value to indicate that there was
         * no hint set with the command line parameter and we should register as "webbrowser-app".
         *
         * We need to have a different applicationIdentifier for the browser because of webapps.
         *
         * Webapps with desktop files are executed like this:
         *
         *     $ webbrowser-app --chromeless http://m.amazon.com --desktop_file_hint=/usr/share/applications/amazon-webapp.desktop
         *
         * It is the Shell that adds the --desktop_file_hint command line argument.
         */
        applicationIdentifier: (browser.desktopFileHint == "<not set>") ? "webbrowser-app" : browser.desktopFileHint
        HUD.Context {
            HUD.Action {
                label: i18n.tr("Goto")
                keywords: i18n.tr("Address;URL;www")
                enabled: false // TODO: parametrized action
            }
            HUD.Action {
                label: i18n.tr("Back")
                keywords: i18n.tr("Older Page")
                enabled: currentWebview ? currentWebview.canGoBack : false
                onTriggered: currentWebview.goBack()
            }
            HUD.Action {
                label: i18n.tr("Forward")
                keywords: i18n.tr("Newer Page")
                enabled: currentWebview ? currentWebview.canGoForward : false
                onTriggered: currentWebview.goForward()
            }
            HUD.Action {
                label: i18n.tr("Reload")
                keywords: i18n.tr("Leave Page")
                enabled: currentWebview != null
                onTriggered: currentWebview.reload()
            }
            HUD.Action {
                label: i18n.tr("Bookmark")
                keywords: i18n.tr("Add This Page to Bookmarks")
                enabled: false // TODO: implement bookmarks
            }
            HUD.Action {
                label: i18n.tr("New Tab")
                keywords: i18n.tr("Open a New Tab")
                enabled: false // TODO: implement tabs
            }
        }
    }

    OrientationHelper {
        id: orientationHelper

        Item {
            id: webviewContainer
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: osk.top
            }
        }

        ErrorSheet {
            id: error
            anchors.fill: webviewContainer
            visible: false
            url: currentWebview ? currentWebview.url : ""
            onRefreshClicked: currentWebview.reload()
        }

        Item {
            id: tabsList

            anchors {
                left: parent.left
                right: parent.right
                bottom: osk.top
            }
            height: units.gu(30)

            visible: false

            Rectangle {
                anchors.fill: parent
                color: "darkgray"
                opacity: 0.9

                Item {
                    anchors {
                        fill: parent
                        margins: units.gu(1)
                    }

                    PageDelegate {
                        id: newTabDelegate
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: units.gu(20)
                        Label {
                            anchors.centerIn: parent
                            fontSize: "x-large"
                            text: i18n.tr("+")
                        }
                        onClicked: browser.newTab("", true)
                    }

                    ListView {
                        anchors {
                            left: newTabDelegate.right
                            leftMargin: units.gu(1)
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                        }

                        orientation: ListView.Horizontal
                        spacing: units.gu(1)
                        clip: true

                        model: tabsModel
                        currentIndex: tabsModel.currentIndex

                        delegate: PageDelegate {
                            width: units.gu(20)
                            height: parent.height
                            title: model.title
                            url: model.url
                            onClicked: tabsModel.currentIndex = index
                        }
                    }
                }
            }
        }

        Loader {
            id: panel

            property Item chrome: item ? item.contents[0] : null

            sourceComponent: browser.chromeless ? undefined : panelComponent

            anchors {
                left: parent.left
                right: parent.right
                bottom: (item && item.opened) ? osk.top : parent.bottom
            }

            Component {
                id: panelComponent

                Panel {
                    anchors {
                        left: parent ? parent.left : undefined
                        right: parent ? parent.right : undefined
                        bottom: parent ? parent.bottom : undefined
                    }
                    height: units.gu(8)

                    opened: true

                    Chrome {
                        anchors.fill: parent

                        loading: currentWebview ? currentWebview.loading || (currentWebview.loadProgress == 0) : false
                        loadProgress: currentWebview ? currentWebview.loadProgress : 0

                        canGoBack: currentWebview ? currentWebview.canGoBack : false
                        onGoBackClicked: currentWebview.goBack()

                        canGoForward: currentWebview ? currentWebview.canGoForward : false
                        onGoForwardClicked: currentWebview.goForward()

                        onUrlValidated: currentWebview.url = url

                        property bool stopped: false
                        onLoadingChanged: {
                            if (loading) {
                                if (panel.item) {
                                    panel.item.opened = true
                                }
                            } else if (stopped) {
                                stopped = false
                            } else if (!addressBar.activeFocus) {
                                if (panel.item) {
                                    panel.item.opened = false
                                }
                                if (currentWebview) {
                                    currentWebview.forceActiveFocus()
                                }
                            }
                        }

                        onRequestReload: currentWebview.reload()
                        onRequestStop: {
                            stopped = true
                            currentWebview.stop()
                        }

                        onToggleTabsClicked: tabsList.visible = !tabsList.visible
                    }
                }
            }
        }

        KeyboardRectangle {
            id: osk
        }
    }

    TabsModel {
        id: tabsModel
    }

    Component {
        id: webviewComponent

        UbuntuWebView {
            id: webview

            anchors.fill: parent

            visible: tabsModel.currentWebview === webview

            devicePixelRatio: browser.qtwebkitdpr

            experimental.preferences.developerExtrasEnabled: browser.developerExtrasEnabled

            onUrlChanged: {
                if (!browser.chromeless && visible) {
                    panel.chrome.url = url
                }
            }

            onLoadingChanged: {
                if (visible) {
                    error.visible = (loadRequest.status === WebView.LoadFailedStatus)
                }
                if (loadRequest.status === WebView.LoadSucceededStatus) {
                    historyModel.add(webview.url, webview.title, webview.icon)
                }
            }
        }
    }

    function newTab(url, setCurrent) {
        var webview = webviewComponent.createObject(webviewContainer, {"url": url})
        var index = tabsModel.add(webview)
        if (setCurrent) {
            tabsModel.currentIndex = index
            if (!browser.chromeless) {
                panel.chrome.url = url
                if (!url) {
                    panel.chrome.addressBar.forceActiveFocus()
                }
            }
        }
    }

    function closeTab(index) {
        var webview = tabsModel.remove(index)
        if (webview) {
            webview.destroy()
        }
    }

    Component.onCompleted: {
        Theme.loadTheme(Qt.resolvedUrl("webbrowser-app.qmltheme"))
        i18n.domain = "webbrowser-app"
    }
}
