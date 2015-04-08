/*
 * Copyright 2013-2015 Canonical Ltd.
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
import QtQuick.Window 2.0
import com.canonical.Oxide 1.5 as Oxide
import Ubuntu.Components 1.1
import webbrowserapp.private 0.1
import webbrowsercommon.private 0.1
import "../actions" as Actions
import ".."
import "../UrlUtils.js" as UrlUtils

BrowserView {
    id: browser

    property bool restoreSession: true

    currentWebview: tabsModel.currentTab ? tabsModel.currentTab.webview : null

    property var historyModel: (historyModelLoader.status == Loader.Ready) ? historyModelLoader.item : null
    property var bookmarksModel: (bookmarksModelLoader.status == Loader.Ready) ? bookmarksModelLoader.item : null

    property url homepage
    property string searchEngine
    property string allowOpenInBackgroundTab

    // XXX: we might want to tweak this value depending
    // on the form factor and/or the available memory
    readonly property int maxLiveWebviews: 2

    // Restore only the n most recent tabs at startup,
    // to limit the overhead of instantiating too many
    // tab objects (see http://pad.lv/1376433).
    readonly property int maxTabsToRestore: 10

    actions: [
        Actions.GoTo {
            onTriggered: currentWebview.url = value
        },
        Actions.Back {
            enabled: currentWebview ? currentWebview.canGoBack : false
            onTriggered: currentWebview.goBack()
        },
        Actions.Forward {
            enabled: currentWebview ? currentWebview.canGoForward : false
            onTriggered: currentWebview.goForward()
        },
        Actions.Reload {
            enabled: currentWebview
            onTriggered: currentWebview.reload()
        },
        Actions.Bookmark {
            enabled: currentWebview && browser.bookmarksModel
            onTriggered: browser.bookmarksModel.add(currentWebview.url, currentWebview.title, currentWebview.icon)
        },
        Actions.NewTab {
            onTriggered: browser.openUrlInNewTab("", true)
        },
        Actions.ClearHistory {
            enabled: browser.historyModel
            onTriggered: browser.historyModel.clearAll()
        }
    ]

    Item {
        anchors.fill: parent

        TabChrome {
            id: invisibleTabChrome
            visible: false
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
        }

        Rectangle {
            // Background for the recent view
            anchors.fill: invisibleTabChrome
            visible: recentView.visible
            color: "#312f2c"
        }

        FocusScope {
            id: tabContainer
            anchors {
                left: parent.left
                right: parent.right
                top: recentView.visible ? invisibleTabChrome.bottom : parent.top
            }
            height: parent.height - osk.height - (recentView.visible ? invisibleTabChrome.height : 0)
        }

        Loader {
            anchors {
                fill: tabContainer
                topMargin: (chrome.state == "shown") ? chrome.height : 0
            }
            sourceComponent: ErrorSheet {
                visible: currentWebview ? currentWebview.lastLoadFailed : false
                url: currentWebview ? currentWebview.url : ""
                onRefreshClicked: currentWebview.reload()
            }
            asynchronous: true
        }

        Loader {
            anchors {
                fill: tabContainer
                topMargin: (chrome.state == "shown") ? chrome.height : 0
            }
            sourceComponent: InvalidCertificateErrorSheet {
                visible: currentWebview && currentWebview.certificateError != null
                certificateError: currentWebview ? currentWebview.certificateError : null
                onAllowed: {
                    // Automatically allow future requests involving this
                    // certificate for the duration of the session.
                    internal.allowCertificateError(currentWebview.certificateError)
                    currentWebview.resetCertificateError()
                }
                onDenied: {
                    currentWebview.resetCertificateError()
                }
            }
            asynchronous: true
        }

        SearchEngine {
            id: searchEngine
            filename: browser.searchEngine
        }

        Chrome {
            id: chrome

            visible: !recentView.visible

            webview: browser.currentWebview
            searchUrl: searchEngine.urlTemplate

            y: webview ? webview.locationBarController.offset : 0

            function isCurrentUrlBookmarked() {
                return ((webview && browser.bookmarksModel) ? browser.bookmarksModel.contains(webview.url) : false)
            }
            bookmarked: isCurrentUrlBookmarked()
            onBookmarkedChanged: {
                if (bookmarked && !isCurrentUrlBookmarked()) {
                    browser.bookmarksModel.add(webview.url, webview.title, webview.icon)
                } else if (!bookmarked && isCurrentUrlBookmarked()) {
                    browser.bookmarksModel.remove(webview.url)
                }
            }
            onWebviewChanged: bookmarked = isCurrentUrlBookmarked()
            Connections {
                target: chrome.webview
                onUrlChanged: chrome.bookmarked = chrome.isCurrentUrlBookmarked()
            }
            Connections {
                target: browser.bookmarksModel
                onAdded: if (!chrome.bookmarked && (url === chrome.webview.url)) chrome.bookmarked = true
                onRemoved: if (chrome.bookmarked && (url === chrome.webview.url)) chrome.bookmarked = false
            }

            anchors {
                left: parent.left
                right: parent.right
            }
            height: units.gu(6)

            drawerActions: [
                Action {
                    objectName: "share"
                    text: i18n.tr("Share")
                    iconName: "share"
                    enabled: (formFactor == "mobile") && browser.currentWebview && browser.currentWebview.url.toString()
                    onTriggered: {
                        var component = Qt.createComponent("../Share.qml")
                        if (component.status == Component.Ready) {
                            var share = component.createObject(browser)
                            share.onDone.connect(share.destroy)
                            share.shareLink(browser.currentWebview.url, browser.currentWebview.title)
                        }
                    }
                },
                Action {
                    objectName: "history"
                    text: i18n.tr("History")
                    iconName: "history"
                    enabled: browser.historyModel
                    onTriggered: historyViewComponent.createObject(historyViewContainer)
                },
                Action {
                    objectName: "tabs"
                    text: i18n.tr("Open tabs")
                    iconName: "browser-tabs"
                    enabled: formFactor != "mobile"
                    onTriggered: {
                        recentView.state = "shown"
                        recentToolbar.state = "shown"
                    }
                },
                Action {
                    objectName: "newtab"
                    text: i18n.tr("New tab")
                    iconName: "tab-new"
                    enabled: formFactor != "mobile"
                    onTriggered: browser.openUrlInNewTab("", true)
                }
            ]
        }

        Suggestions {
            opacity: ((chrome.state == "shown") && chrome.activeFocus && (count > 0) && !chrome.drawerOpen) ? 1.0 : 0.0
            Behavior on opacity {
                UbuntuNumberAnimation {}
            }
            enabled: opacity > 0
            anchors {
                top: chrome.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: chrome.width - units.gu(5)
            height: enabled ? Math.min(contentHeight, tabContainer.height - units.gu(2)) : 0
            model: HistoryMatchesModel {
                sourceModel: browser.historyModel
                query: chrome.text
            }
            onSelected: {
                browser.currentWebview.url = url
                browser.currentWebview.forceActiveFocus()
                chrome.requestedUrl = url
            }
        }
    }

    FocusScope {
        id: recentView

        anchors.fill: parent
        opacity: (bottomEdgeHandle.dragging || tabslist.animating || (state == "shown")) ? 1 : 0
        Behavior on opacity { UbuntuNumberAnimation {} }
        visible: opacity > 0

        states: State {
            name: "shown"
        }

        TabsList {
            id: tabslist
            anchors.fill: parent
            model: tabsModel
            readonly property real delegateMinHeight: units.gu(20)
            delegateHeight: {
                if (recentView.state == "shown") {
                    return Math.max(height / 3, delegateMinHeight)
                } else if (bottomEdgeHandle.stage == 0) {
                    return height
                } else if (bottomEdgeHandle.stage == 1) {
                    return (1 - 1.8 * bottomEdgeHandle.dragFraction) * height
                } else if (bottomEdgeHandle.stage >= 2) {
                    return Math.max(height / 3, delegateMinHeight)
                } else {
                    return delegateMinHeight
                }
            }
            onTabSelected: {
                var tab = tabsModel.get(index)
                if (tab) {
                    tab.load()
                    tab.forceActiveFocus()
                    tabslist.model.setCurrent(index)
                }
                recentView.reset()
            }
            onTabClosed: {
                var tab = tabsModel.remove(index)
                if (tab) {
                    tab.close()
                }
                if (tabsModel.count === 0) {
                    browser.openUrlInNewTab("", true)
                    recentView.reset()
                }
            }
        }

        Toolbar {
            id: recentToolbar
            objectName: "recentToolbar"

            anchors {
                left: parent.left
                right: parent.right
            }
            height: units.gu(7)
            state: "hidden"

            Button {
                objectName: "doneButton"
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                strokeColor: UbuntuColors.darkGrey

                text: i18n.tr("Done")

                onClicked: {
                    recentView.reset()
                    tabsModel.currentTab.load()
                }
            }

            ToolbarAction {
                objectName: "newTabButton"
                anchors {
                    right: parent.right
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
                height: parent.height - units.gu(2)

                text: i18n.tr("New Tab")

                iconName: "add"

                onClicked: {
                    recentView.reset()
                    browser.openUrlInNewTab("", true)
                }
            }
        }

        function reset() {
            state = ""
            recentToolbar.state = "hidden"
            tabslist.reset()
        }
    }

    BottomEdgeHandle {
        id: bottomEdgeHandle

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: units.gu(2)

        enabled: (formFactor == "mobile") && (recentView.state == "") &&
                 (Screen.orientation == Screen.primaryOrientation) &&
                 browser.currentWebview && !browser.currentWebview.fullscreen

        onDraggingChanged: {
            if (!dragging) {
                if (stage == 1) {
                    if (tabsModel.count > 1) {
                        tabslist.selectAndAnimateTab(1)
                    } else {
                        recentView.state = "shown"
                        recentToolbar.state = "shown"
                    }
                } else if (stage == 2) {
                    recentView.state = "shown"
                    recentToolbar.state = "shown"
                } else if (stage >= 3) {
                    recentView.state = "shown"
                    recentToolbar.state = "shown"
                }
            }
        }
    }

    Image {
        objectName: "bottomEdgeHint"
        source: (formFactor == "mobile") ? "assets/bottom_edge_hint.png" : ""
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: (chrome.state == "shown") ? 0 : -height
            Behavior on bottomMargin {
                UbuntuNumberAnimation {}
            }
        }
        visible: bottomEdgeHandle.enabled
        opacity: 1 - recentView.opacity
        Behavior on opacity {
            UbuntuNumberAnimation {}
        }
    }

    Item {
        id: historyViewContainer

        visible: children.length > 0
        anchors.fill: parent

        Component {
            id: historyViewComponent

            HistoryView {
                anchors.fill: parent
                visible: historyViewContainer.children.length == 1

                Timer {
                    // Set the model asynchronously to ensure
                    // the view is displayed as early as possible.
                    running: true
                    interval: 1
                    onTriggered: historyModel = browser.historyModel
                }

                onSeeMoreEntriesClicked: {
                    var view = expandedHistoryViewComponent.createObject(historyViewContainer, {model: model})
                    view.onHistoryEntryClicked.connect(destroy)
                }
                onHistoryDomainRemoved: browser.historyModel.removeEntriesByDomain(domain)
                onDone: destroy()
            }
        }

        Component {
            id: expandedHistoryViewComponent

            ExpandedHistoryView {
                anchors.fill: parent

                onHistoryEntryClicked: {
                    browser.openUrlInNewTab(url, true)
                    done()
                }
                onHistoryEntryRemoved: browser.historyModel.removeEntryByUrl(url)
                onDone: destroy()
            }
        }
    }

    TabsModel {
        id: tabsModel

        // Ensure that at most n webviews are instantiated at all times,
        // to reduce memory consumption (see http://pad.lv/1376418).
        onCurrentTabChanged: {
            if (count > browser.maxLiveWebviews) {
                get(browser.maxLiveWebviews).unload()
            }
        }
    }

    Loader {
        id: historyModelLoader
        source: "HistoryModel.qml"
        asynchronous: true
    }

    Loader {
        id: bookmarksModelLoader
        source: "BookmarksModel.qml"
        asynchronous: true
    }

    Component {
        id: tabComponent

        BrowserTab {
            anchors.fill: parent
            visible: tabsModel.currentTab === this

            webviewComponent: WebViewImpl {
                id: webviewimpl

                property BrowserTab tab

                currentWebview: browser.currentWebview

                anchors.fill: parent
                focus: true

                enabled: visible && !bottomEdgeHandle.dragging && !recentView.visible

                ChromeController {
                    id: chromeController
                    webview: webviewimpl
                    forceHide: recentView.visible
                }

                locationBarController {
                    height: webviewimpl.visible ? chrome.height : 0
                    mode: chromeController.mode
                }

                //experimental.preferences.developerExtrasEnabled: developerExtrasEnabled
                preferences.localStorageEnabled: true
                preferences.appCacheEnabled: true

                contextualActions: ActionList {
                    Actions.OpenLinkInNewTab {
                        enabled: contextualData.href.toString()
                        onTriggered: browser.openUrlInNewTab(contextualData.href, true)
                    }
                    Actions.OpenLinkInNewBackgroundTab {
                        enabled: contextualData.href.toString() && ((browser.allowOpenInBackgroundTab === "true") ||
                                 ((browser.allowOpenInBackgroundTab === "default") && (formFactor === "desktop")))
                        onTriggered: browser.openUrlInNewTab(contextualData.href, false)
                    }
                    Actions.BookmarkLink {
                        enabled: contextualData.href.toString() && browser.bookmarksModel
                        onTriggered: browser.bookmarksModel.add(contextualData.href, contextualData.title, "")
                    }
                    Actions.CopyLink {
                        enabled: contextualData.href.toString()
                        onTriggered: Clipboard.push([contextualData.href])
                    }
                    Actions.OpenImageInNewTab {
                        enabled: contextualData.img.toString()
                        onTriggered: browser.openUrlInNewTab(contextualData.img, true)
                    }
                    Actions.CopyImage {
                        enabled: contextualData.img.toString()
                        onTriggered: Clipboard.push([contextualData.img])
                    }
                    Actions.SaveImage {
                        enabled: contextualData.img.toString() && downloadLoader.status == Loader.Ready
                        onTriggered: downloadLoader.item.downloadPicture(contextualData.img)
                    }
                }

                onNewViewRequested: {
                    var tab = tabComponent.createObject(tabContainer, {"request": request})
                    var setCurrent = (request.disposition == Oxide.NewViewRequest.DispositionNewForegroundTab)
                    internal.addTab(tab, setCurrent)
                }

                onCloseRequested: prepareToClose()
                onPrepareToCloseResponse: {
                    if (proceed) {
                        if (tab) {
                            for (var i = 0; i < tabsModel.count; ++i) {
                                if (tabsModel.get(i) === tab) {
                                    tabsModel.remove(i)
                                    break
                                }
                            }
                            tab.close()
                        }
                        if (tabsModel.count === 0) {
                            browser.openUrlInNewTab("", true, true)
                        }
                    }
                }

                onLoadEvent: {
                    if ((event.type == Oxide.LoadEvent.TypeSucceeded) && browser.historyModel) {
                        browser.historyModel.add(event.url, title, icon)
                    }
                }

                onGeolocationPermissionRequested: requestGeolocationPermission(request)

                property var certificateError
                function resetCertificateError() {
                    certificateError = null
                }
                onCertificateError: {
                    if (!error.isMainFrame || error.isSubresource) {
                        // Not a main frame document error, just block the content
                        // (it’s not overridable anyway).
                        return
                    }
                    if (internal.isCertificateErrorAllowed(error)) {
                        error.allow()
                    } else {
                        certificateError = error
                        error.onCancelled.connect(webviewimpl.resetCertificateError)
                    }
                }

                Loader {
                    id: newTabViewLoader
                    anchors.fill: parent

                    // Avoid loading the new tab view if the webview is about to load
                    // content. Since WebView.restoreState is not a notifyable property,
                    // this can’t be achieved with a simple property binding.
                    Component.onCompleted: {
                        if (!parent.url.toString() && !parent.restoreState) {
                            sourceComponent = newTabViewComponent
                        }
                    }
                    Connections {
                        target: newTabViewLoader.parent
                        onUrlChanged: newTabViewLoader.sourceComponent = null
                    }

                    Component {
                        id: newTabViewComponent

                        NewTabView {
                            anchors {
                                fill: parent
                                topMargin: (chrome.state == "shown") ? chrome.height : 0
                            }

                            historyModel: browser.historyModel
                            bookmarksModel: browser.bookmarksModel
                            onBookmarkClicked: {
                                chrome.requestedUrl = url
                                currentWebview.url = url
                                currentWebview.forceActiveFocus()
                            }
                            onBookmarkRemoved: browser.bookmarksModel.remove(url)
                            onHistoryEntryClicked: {
                                chrome.requestedUrl = url
                                currentWebview.url = url
                                currentWebview.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: downloadLoader
        source: formFactor == "desktop" ? "" : "../Downloader.qml"
        asynchronous: true
    }

    QtObject {
        id: internal

        function addTab(tab, setCurrent) {
            var index = tabsModel.add(tab)
            if (setCurrent) {
                tabsModel.setCurrent(index)
                chrome.requestedUrl = tab.initialUrl
            }
        }

        function focusAddressBar() {
            chrome.forceActiveFocus()
            Qt.inputMethod.show() // work around http://pad.lv/1316057
        }

        // Invalid certificates the user has explicitly allowed for this session
        property var allowedCertificateErrors: []

        function allowCertificateError(error) {
            var host = UrlUtils.extractHost(error.url)
            var code = error.certError
            var fingerprint = error.certificate.fingerprintSHA1
            allowedCertificateErrors.push([host, code, fingerprint])
        }

        function isCertificateErrorAllowed(error) {
            var host = UrlUtils.extractHost(error.url)
            var code = error.certError
            var fingerprint = error.certificate.fingerprintSHA1
            for (var i in allowedCertificateErrors) {
                var allowed = allowedCertificateErrors[i]
                if ((host == allowed[0]) &&
                    (code == allowed[1]) &&
                    (fingerprint == allowed[2])) {
                    return true
                }
            }
            return false
        }
    }

    function openUrlInNewTab(url, setCurrent, load) {
        load = typeof load !== 'undefined' ? load : true
        var tab = tabComponent.createObject(tabContainer, {"initialUrl": url})
        internal.addTab(tab, setCurrent)
        if (load) {
            tabsModel.currentTab.load()
        }
        if (!url.toString() && (formFactor == "desktop")) {
            internal.focusAddressBar()
        }
    }

    SessionStorage {
        id: session

        dataFile: dataLocation + "/session.json"

        function save() {
            if (!locked) {
                return
            }
            var tabs = []
            for (var i = 0; i < tabsModel.count; ++i) {
                var tab = tabsModel.get(i)
                tabs.push(serializeTabState(tab))
            }
            store(JSON.stringify({tabs: tabs}))
        }

        function restore() {
            if (!locked) {
                return
            }
            var state = null
            try {
                state = JSON.parse(retrieve())
            } catch (e) {
                return
            }
            if (state) {
                var tabs = state.tabs
                if (tabs) {
                    for (var i = 0; i < Math.min(tabs.length, browser.maxTabsToRestore); ++i) {
                        var tab = createTabFromState(tabs[i])
                        internal.addTab(tab, i == 0)
                    }
                }
            }
        }

        // Those two functions are used to save/restore the current state of a tab.
        function serializeTabState(tab) {
            var state = {}
            state.uniqueId = tab.uniqueId
            state.url = tab.url.toString()
            state.title = tab.title
            state.preview = tab.preview.toString()
            state.savedState = tab.webview ? tab.webview.currentState : tab.restoreState
            return state
        }

        function createTabFromState(state) {
            var properties = {'initialUrl': state.url, 'initialTitle': state.title}
            if ('uniqueId' in state) {
                properties["uniqueId"] = state.uniqueId
            }
            if ('preview' in state) {
                properties["preview"] = state.preview
            }
            if ('savedState' in state) {
                properties['restoreState'] = state.savedState
                properties['restoreType'] = Oxide.WebView.RestoreLastSessionExitedCleanly
            }
            return tabComponent.createObject(tabContainer, properties)
        }
    }
    Connections {
        target: Qt.application
        onStateChanged: {
            if (Qt.application.state != Qt.ApplicationActive) {
                session.save()
            }
        }
        onAboutToQuit: session.save()
    }

    // Delay instantiation of the first webview by 1 msec to allow initial
    // rendering to happen. Clumsy workaround for http://pad.lv/1359911.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (browser.restoreSession) {
                session.restore()
            }
            // Sanity check
            console.assert(tabsModel.count <= browser.maxTabsToRestore,
                           "WARNING: too many tabs were restored")
            for (var i in browser.initialUrls) {
                browser.openUrlInNewTab(browser.initialUrls[i], true, false)
            }
            if (tabsModel.count == 0) {
                browser.openUrlInNewTab(browser.homepage, true, false)
            }
            tabsModel.currentTab.load()
            if (!tabsModel.currentTab.url.toString() && !tabsModel.currentTab.restoreState && (formFactor == "desktop")) {
                internal.focusAddressBar()
            }
        }
    }
}
