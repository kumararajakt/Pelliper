import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: listPane
    spacing: 0

    property double activeFolderId: 0
    property string activeFolderRole: "inbox"
    property double selectedMessageId: 0
    property var selectedIds: []
    property bool selectionMode: selectedIds.length > 0
    signal messageSelected(var accountId, var messageId, string senderName, string subject, string snippet)

    function toggleSelection(msgId) {
        const next = selectedIds.slice()
        const idx = next.indexOf(msgId)
        if (idx >= 0) next.splice(idx, 1)
        else next.push(msgId)
        selectedIds = next
    }

    function clearSelection() {
        selectedIds = []
    }

    function focusSearch() {
        searchField.forceActiveFocus()
    }

    readonly property var searchOperators: [
        { op: "from:", hint: i18n("an email address") },
        { op: "to:", hint: i18n("an email address") },
        { op: "in:", hint: i18n("folder or label") },
        { op: "before:", hint: i18n("date received or range") },
        { op: "since:", hint: i18n("date received or range") },
        { op: "is:", hint: i18n("unread, starred") },
        { op: "has:", hint: i18n("attachment") },
        { op: "subject:", hint: i18n("an email subject") }
    ]

    Timer {
        id: searchDebounce
        interval: 150
        onTriggered: threadListModel.search(searchField.text, listPane.activeFolderId, false, listPane.activeFolderRole)
    }

    Timer {
        id: serverSearchDebounce
        interval: 450
        onTriggered: {
            if (searchField.text.trim().length > 0) {
                threadListModel.search(searchField.text, listPane.activeFolderId, true, listPane.activeFolderRole)
            }
        }
    }

    Timer {
        id: prefetchDebounce
        interval: 200
        onTriggered: {
            if (messageList.count > 0) {
                const firstIdx = Math.max(0, messageList.indexAt(0, messageList.contentY))
                const lastIdx = Math.max(firstIdx, messageList.indexAt(0, messageList.contentY + messageList.height))
                threadListModel.prefetchRange(firstIdx, lastIdx)
            }
        }
    }

    Controls.ToolBar {
        Layout.fillWidth: true
        Kirigami.SearchField {
            id: searchField
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            placeholderText: i18n("Search (from:, in:, is:, has:)…")
            onTextChanged: {
                searchDebounce.restart()
                serverSearchDebounce.restart()
            }
            onActiveFocusChanged: {
                if (activeFocus) {
                    operatorPopup.open()
                }
            }
        }
    }

    Controls.Popup {
        id: operatorPopup
        x: searchField.x
        y: searchField.y + searchField.height + Kirigami.Units.smallSpacing
        width: listPane.width - Kirigami.Units.largeSpacing
        padding: 0
        focus: false
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent

        contentItem: ListView {
            implicitHeight: Math.min(contentHeight, 260)
            model: listPane.searchOperators
            delegate: Controls.ItemDelegate {
                width: ListView.view.width
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: modelData.op
                        color: Kirigami.Theme.linkColor
                        font.bold: true
                    }
                    Controls.Label {
                        Layout.fillWidth: true
                        text: modelData.hint
                        opacity: 0.7
                    }
                }
                onClicked: {
                    const prefix = searchField.text.length > 0 && !searchField.text.endsWith(" ") ? " " : ""
                    searchField.text += prefix + modelData.op + " "
                    searchField.forceActiveFocus()
                    operatorPopup.close()
                }
            }
        }
    }

    Controls.Label {
        visible: threadListModel.searchingServer
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.topMargin: 2
        text: i18n("Searching server…")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.7
    }

    Controls.ToolBar {
        visible: listPane.selectionMode
        Layout.fillWidth: true
        RowLayout {
            anchors.fill: parent
            Controls.Label {
                text: i18np("%1 selected", "%1 selected", listPane.selectedIds.length)
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Controls.ToolButton {
                icon.name: "mail-mark-read"
                Controls.ToolTip.text: i18n("Mark Read")
                onClicked: {
                    for (const id of listPane.selectedIds) {
                        messageController.toggleRead(id, true)
                    }
                    listPane.clearSelection()
                }
            }
            Controls.ToolButton {
                icon.name: "starred-symbolic"
                Controls.ToolTip.text: i18n("Star")
                onClicked: {
                    for (const id of listPane.selectedIds) {
                        messageController.toggleStar(id, true)
                    }
                    listPane.clearSelection()
                }
            }
            Controls.ToolButton {
                icon.name: "folder-archive"
                Controls.ToolTip.text: i18n("Archive")
                onClicked: {
                    for (const id of listPane.selectedIds) {
                        messageController.archiveMessage(id)
                        threadListModel.removeMessageOptimistic(id)
                    }
                    listPane.clearSelection()
                }
            }
            Controls.ToolButton {
                icon.name: "edit-delete"
                Controls.ToolTip.text: i18n("Delete")
                onClicked: {
                    for (const id of listPane.selectedIds) {
                        messageController.deleteMessage(id)
                        threadListModel.removeMessageOptimistic(id)
                    }
                    listPane.clearSelection()
                }
            }
            Controls.ToolButton {
                icon.name: "dialog-cancel"
                onClicked: listPane.clearSelection()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: messageList
            anchors.fill: parent
            clip: true
            model: threadListModel
            onContentYChanged: prefetchDebounce.restart()

            delegate: Controls.ItemDelegate {
                width: messageList.width
                highlighted: listPane.selectedIds.indexOf(model.messageId) >= 0 || model.messageId === listPane.selectedMessageId

                contentItem: ColumnLayout {
                    spacing: 2

                    // Line 1: Sender (bold if unread) + Right-aligned Timestamp
                    RowLayout {
                        Layout.fillWidth: true
                        Controls.Label {
                            Layout.fillWidth: true
                            text: model.senderName
                            font.bold: model.unread
                            elide: Text.ElideRight
                        }
                        Controls.Label {
                            text: model.timestampText
                            opacity: 0.65
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    // Line 2: Subject
                    Controls.Label {
                        Layout.fillWidth: true
                        text: model.subject.length > 0 ? model.subject : i18n("(No Subject)")
                        elide: Text.ElideRight
                    }

                    // Line 3: Body Preview Snippet (toggleable in Settings, fills live once cached)
                    Controls.Label {
                        visible: appSettings.showBodyPreview
                        Layout.fillWidth: true
                        text: model.snippet
                        opacity: 0.65
                        elide: Text.ElideRight
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                    }
                }

                onClicked: {
                    if (listPane.selectionMode) {
                        listPane.toggleSelection(model.messageId)
                        return
                    }
                    listPane.selectedMessageId = model.messageId
                    listPane.messageSelected(model.accountId, model.messageId, model.senderName, model.subject, model.snippet)
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: listPane.toggleSelection(model.messageId)
                }
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            visible: messageList.count === 0
            width: parent.width - Kirigami.Units.largeSpacing * 2
            text: threadListModel.syncing ? i18n("Syncing mail…") : i18n("No Messages")
            explanation: threadListModel.syncing
                ? i18n("Fetching folders and message headers from server…")
                : (accountController.accountCount === 0
                    ? i18n("Use File → Add Account… to start syncing.")
                    : i18n("No messages match this folder or search."))
            icon.name: threadListModel.syncing ? "view-refresh" : "mail-receive"
        }
    }
}
