import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper

ColumnLayout {
    id: messageRoot

    signal messageSelected(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)
    signal replyRequested(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)
    signal forwardRequested(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)

    property bool threaded: true
    property bool selectionMode: false
    property var selectedItems: ({})

    Shortcut { sequence: "Escape"; onActivated: {
        if (selectionMode) deselectAll()
    }}
    Shortcut { sequence: "Ctrl+A"; onActivated: {
        selectionMode = true
        selectAll()
    }}

    function extractEmail(sender) {
        var match = sender.match(/<([^>]+)>/)
        if (match) return match[1]
        if (sender.indexOf("@") >= 0) return sender.trim()
        return ""
    }

    function toggleSelection(accountId, folderPath, uid) {
        var key = accountId + ":" + folderPath + ":" + uid
        var copy = JSON.parse(JSON.stringify(selectedItems))
        if (copy[key]) {
            delete copy[key]
        } else {
            copy[key] = {accountId: accountId, folderPath: folderPath, uid: uid}
        }
        selectedItems = copy
        if (Object.keys(selectedItems).length === 0) {
            selectionMode = false
        }
    }

    function selectedCount() {
        return Object.keys(selectedItems).length
    }

    function selectAll() {
        var copy = {}
        var model = threaded ? Pelliper.ThreadModel : Pelliper.MessageModel
        for (var i = 0; i < model.count; i++) {
            var idx = model.index(i, 0)
            var roles = model.roleNames()
            var acidRole = 0, pathRole = 0, uidRole = 0
            for (var k in roles) {
                if (roles[k] === "accountId") acidRole = Number(k)
                if (roles[k] === "folderPath") pathRole = Number(k)
                if (roles[k] === "uid") uidRole = Number(k)
            }
            var a = model.data(idx, acidRole)
            var p = model.data(idx, pathRole)
            var u = model.data(idx, uidRole)
            var key = a + ":" + p + ":" + u
            copy[key] = {accountId: a, folderPath: p, uid: u}
        }
        selectedItems = copy
    }

    function deselectAll() {
        selectedItems = {}
        selectionMode = false
    }

    function performBulkAction(action) {
        for (var key in selectedItems) {
            var item = selectedItems[key]
            if (action === "delete") {
                Pelliper.DaemonClient.deleteMessage(item.accountId, item.folderPath, item.uid)
            } else if (action === "read") {
                Pelliper.DaemonClient.setMessageRead(item.accountId, item.folderPath, item.uid, true)
            } else if (action === "unread") {
                Pelliper.DaemonClient.setMessageRead(item.accountId, item.folderPath, item.uid, false)
            } else if (action === "star") {
                Pelliper.DaemonClient.setMessageStarred(item.accountId, item.folderPath, item.uid, true)
            } else if (action === "unstar") {
                Pelliper.DaemonClient.setMessageStarred(item.accountId, item.folderPath, item.uid, false)
            }
        }
        selectedItems = {}
        selectionMode = false
    }

    function isSelected(accountId, folderPath, uid) {
        var key = accountId + ":" + folderPath + ":" + uid
        return !!selectedItems[key]
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing

        Controls.Label {
            text: {
                if (selectionMode) return qsTr("%1 selected").arg(selectedCount())
                return Pelliper.MessageModel.folderPath ? Pelliper.MessageModel.folderPath : qsTr("Select a folder")
            }
            font.pointSize: 14
            font.weight: Font.Bold
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Controls.Label {
            text: {
                var model = threaded ? Pelliper.ThreadModel : Pelliper.MessageModel
                return model.count > 0 ? model.count.toString() : ""
            }
            color: Kirigami.Theme.disabledTextColor
            visible: !selectionMode
        }

        Controls.ToolButton {
            icon.name: "edit-select-all"
            visible: !selectionMode
            Controls.ToolTip.text: qsTr("Select messages")
            Controls.ToolTip.visible: hovered
            onClicked: {
                selectionMode = true
                selectAll()
            }
        }

        Controls.ToolButton {
            icon.name: "view-sort"
            visible: !selectionMode

            Controls.Menu {
                id: viewMenu
                parent: undefined

                Controls.MenuItem {
                    text: qsTr("Threaded")
                    checkable: true
                    checked: threaded
                    onToggled: threaded = checked
                }
                Controls.MenuItem {
                    text: qsTr("Flat")
                    checkable: true
                    checked: !threaded
                    onToggled: threaded = !checked
                }

                Controls.MenuSeparator {}

                Controls.MenuItem {
                    text: qsTr("Date (newest first)")
                    checkable: true
                    checked: Pelliper.MessageModel.sortRole === "date" && !Pelliper.MessageModel.sortAscending
                    onTriggered: Pelliper.MessageModel.setSort("date", false)
                }
                Controls.MenuItem {
                    text: qsTr("Date (oldest first)")
                    checkable: true
                    checked: Pelliper.MessageModel.sortRole === "date" && Pelliper.MessageModel.sortAscending
                    onTriggered: Pelliper.MessageModel.setSort("date", true)
                }
                Controls.MenuItem {
                    text: qsTr("Sender (A–Z)")
                    checkable: true
                    checked: Pelliper.MessageModel.sortRole === "sender" && Pelliper.MessageModel.sortAscending
                    onTriggered: Pelliper.MessageModel.setSort("sender", true)
                }
                Controls.MenuItem {
                    text: qsTr("Sender (Z–A)")
                    checkable: true
                    checked: Pelliper.MessageModel.sortRole === "sender" && !Pelliper.MessageModel.sortAscending
                    onTriggered: Pelliper.MessageModel.setSort("sender", false)
                }
                Controls.MenuItem {
                    text: qsTr("Subject (A–Z)")
                    checkable: true
                    checked: Pelliper.MessageModel.sortRole === "subject" && Pelliper.MessageModel.sortAscending
                    onTriggered: Pelliper.MessageModel.setSort("subject", true)
                }
                Controls.MenuItem {
                    text: qsTr("Unread first")
                    checkable: true
                    checked: Pelliper.MessageModel.sortRole === "read" && !Pelliper.MessageModel.sortAscending
                    onTriggered: Pelliper.MessageModel.setSort("read", false)
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: viewMenu.popup(mapToGlobal(width / 2, height / 2))
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    // Bulk action bar
    Controls.ToolBar {
        Layout.fillWidth: true
        visible: selectionMode
        height: visible ? 40 : 0

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing

            Controls.ToolButton {
                icon.name: "edit-select-all"
                Controls.ToolTip.text: qsTr("Select All")
                Controls.ToolTip.visible: hovered
                onClicked: selectAll()
            }
            Controls.ToolButton {
                icon.name: "edit-select-none"
                Controls.ToolTip.text: qsTr("Deselect All")
                Controls.ToolTip.visible: hovered
                onClicked: deselectAll()
            }

            Kirigami.Separator { Layout.fillHeight: true }

            Controls.ToolButton {
                icon.name: "mail-read"
                Controls.ToolTip.text: qsTr("Mark Read")
                Controls.ToolTip.visible: hovered
                onClicked: performBulkAction("read")
            }
            Controls.ToolButton {
                icon.name: "mail-unread"
                Controls.ToolTip.text: qsTr("Mark Unread")
                Controls.ToolTip.visible: hovered
                onClicked: performBulkAction("unread")
            }

            Controls.ToolButton {
                icon.name: "starred-symbolic"
                Controls.ToolTip.text: qsTr("Star")
                Controls.ToolTip.visible: hovered
                onClicked: performBulkAction("star")
            }
            Controls.ToolButton {
                icon.name: "non-starred-symbolic"
                Controls.ToolTip.text: qsTr("Unstar")
                Controls.ToolTip.visible: hovered
                onClicked: performBulkAction("unstar")
            }

            Kirigami.Separator { Layout.fillHeight: true }

            Controls.ToolButton {
                icon.name: "user-trash"
                Controls.ToolTip.text: qsTr("Move to Trash")
                Controls.ToolTip.visible: hovered
                onClicked: performBulkAction("delete")
            }

            Item { Layout.fillWidth: true }

            Controls.ToolButton {
                icon.name: "dialog-cancel"
                Controls.ToolTip.text: qsTr("Cancel")
                Controls.ToolTip.visible: hovered
                onClicked: deselectAll()
            }
        }
    }

    // Threaded view
    ListView {
        id: threadList
        Layout.fillHeight: true
        Layout.fillWidth: true
        visible: threaded
        clip: true

        model: Pelliper.ThreadModel

        onAtYEndChanged: {
            if (atYEnd && Pelliper.MessageModel.hasMore) {
                Pelliper.MessageModel.loadMore()
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)
            visible: threadList.count === 0
            text: qsTr("No Messages Found")
            explanation: qsTr("Select a folder to view its messages.")
        }

        delegate: MessageThreadDelegate {
            listView: threadList
            listRoot: messageRoot
        }
    }

    // Flat view
    ListView {
        id: messageList
        Layout.fillHeight: true
        Layout.fillWidth: true
        visible: !threaded
        clip: true

        model: Pelliper.MessageModel

        onAtYEndChanged: {
            if (atYEnd && Pelliper.MessageModel.hasMore) {
                Pelliper.MessageModel.loadMore()
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)
            visible: messageList.count === 0
            text: qsTr("No Messages Found")
            explanation: qsTr("Select a folder to view its messages.")
        }

        delegate: MessageListDelegate {
            listView: messageList
            listRoot: messageRoot
        }
    }
}