import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ColumnLayout {

    signal messageSelected(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)
    signal replyRequested(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)
    signal forwardRequested(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)

    property bool threaded: true
    property bool selectionMode: false
    property var selectedItems: ({})

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
            Component.onCompleted: {
                var model = threaded ? Pelliper.ThreadModel : Pelliper.MessageModel
                visible = model.count > 0
            }
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

        delegate: Controls.ItemDelegate {
            id: threadDelegate
            required property int accountId
            required property string folderPath
            required property int uid
            required property string subject
            required property string sender
            required property real date
            required property bool isRead
            required property bool isStarred
            required property bool hasAttachments
            required property string preview
            required property int replyCount
            required property int unreadCount
            required property int index

            width: threadList.width
            background: Rectangle {
                color: messageRoot.isSelected(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid)
                    ? Kirigami.Theme.highlightColor
                    : "transparent"
                opacity: messageRoot.isSelected(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid) ? 0.15 : 1
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                // Checkbox (selection mode)
                Controls.CheckBox {
                    visible: messageRoot.selectionMode
                    checked: messageRoot.isSelected(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid)
                    onClicked: messageRoot.toggleSelection(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // Subject and indicators row
                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Label {
                            text: threadDelegate.subject || qsTr("(no subject)")
                            font.weight: threadDelegate.isRead ? Font.Normal : Font.Bold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Reply count badge
                        Rectangle {
                            visible: threadDelegate.replyCount > 0
                            Layout.preferredWidth: replyCountLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                            Layout.preferredHeight: 18
                            radius: 9
                            color: Kirigami.Theme.disabledTextColor

                            Controls.Label {
                                id: replyCountLabel
                                anchors.centerIn: parent
                                text: threadDelegate.replyCount.toString()
                                font.pointSize: 8
                                font.weight: Font.Bold
                                color: Kirigami.Theme.backgroundColor
                            }
                        }

                        // Star toggle
                        Item {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            visible: !messageRoot.selectionMode

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: threadDelegate.isStarred ? "starred-symbolic" : "non-starred-symbolic"
                                color: threadDelegate.isStarred ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    threadDelegate.isStarred = !threadDelegate.isStarred
                                    Pelliper.DaemonClient.setMessageStarred(
                                        threadDelegate.accountId,
                                        threadDelegate.folderPath,
                                        threadDelegate.uid,
                                        threadDelegate.isStarred
                                    )
                                }
                            }
                        }

                        Kirigami.Icon {
                            source: "mail-attachment"
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            visible: threadDelegate.hasAttachments
                        }
                    }

                    // Sender and date row
                    RowLayout {
                        Layout.fillWidth: true

                        Image {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            source: messageRoot.extractEmail(threadDelegate.sender).length > 0
                                ? Pelliper.DaemonClient.gravatarUrl(messageRoot.extractEmail(threadDelegate.sender), 40)
                                : ""
                            visible: source.length > 0
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: null
                        }

                        Controls.Label {
                            text: threadDelegate.sender
                            font.pointSize: 10
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Controls.Label {
                            text: {
                                if (threadDelegate.date <= 0) return ""
                                var d = new Date(threadDelegate.date * 1000)
                                var now = new Date()
                                if (d.toDateString() === now.toDateString()) {
                                    return Qt.formatTime(d, "HH:mm")
                                }
                                return Qt.formatDate(d, "MMM d")
                            }
                            font.pointSize: 10
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    // Preview text
                    Controls.Label {
                        text: threadDelegate.preview
                        font.pointSize: 10
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: threadDelegate.preview.length > 0
                        Layout.fillWidth: true
                    }
                }
            }

            onClicked: {
                if (messageRoot.selectionMode) {
                    messageRoot.toggleSelection(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid)
                } else {
                    threadList.currentIndex = index
                    messageSelected(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid, threadDelegate.subject, threadDelegate.sender, threadDelegate.date, threadDelegate.isRead, threadDelegate.isStarred)
                }
            }

            Controls.Menu {
                id: threadContextMenu

                Controls.MenuItem {
                    text: qsTr("Reply")
                    icon.name: "mail-reply-sender"
                    onTriggered: replyRequested(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid, threadDelegate.subject, threadDelegate.sender, threadDelegate.date, threadDelegate.isRead, threadDelegate.isStarred)
                }
                Controls.MenuItem {
                    text: qsTr("Forward")
                    icon.name: "mail-forward"
                    onTriggered: forwardRequested(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid, threadDelegate.subject, threadDelegate.sender, threadDelegate.date, threadDelegate.isRead, threadDelegate.isStarred)
                }

                Controls.MenuSeparator {}

                Controls.MenuItem {
                    text: threadDelegate.isRead ? qsTr("Mark as Unread") : qsTr("Mark as Read")
                    icon.name: threadDelegate.isRead ? "mail-unread" : "mail-read"
                    onTriggered: {
                        threadDelegate.isRead = !threadDelegate.isRead
                        Pelliper.DaemonClient.setMessageRead(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid, threadDelegate.isRead)
                    }
                }
                Controls.MenuItem {
                    text: threadDelegate.isStarred ? qsTr("Unstar") : qsTr("Star")
                    icon.name: threadDelegate.isStarred ? "non-starred-symbolic" : "starred-symbolic"
                    onTriggered: {
                        threadDelegate.isStarred = !threadDelegate.isStarred
                        Pelliper.DaemonClient.setMessageStarred(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid, threadDelegate.isStarred)
                    }
                }

                Controls.MenuSeparator {}

                Controls.MenuItem {
                    text: qsTr("Move to Trash")
                    icon.name: "user-trash"
                    onTriggered: Pelliper.DaemonClient.deleteMessage(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    threadContextMenu.popup(mouse.x, mouse.y)
                }
            }
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

        delegate: Controls.ItemDelegate {
            id: msgDelegate
            required property int accountId
            required property string folderPath
            required property int uid
            required property string subject
            required property string sender
            required property real date
            required property bool isRead
            required property bool isStarred
            required property bool hasAttachments
            required property string preview
            required property int index

            width: messageList.width
            background: Rectangle {
                color: messageRoot.isSelected(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid)
                    ? Kirigami.Theme.highlightColor
                    : "transparent"
                opacity: messageRoot.isSelected(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid) ? 0.15 : 1
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                // Checkbox (selection mode)
                Controls.CheckBox {
                    visible: messageRoot.selectionMode
                    checked: messageRoot.isSelected(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid)
                    onClicked: messageRoot.toggleSelection(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // Subject and star row
                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Label {
                            text: msgDelegate.subject || qsTr("(no subject)")
                            font.weight: msgDelegate.isRead ? Font.Normal : Font.Bold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Star toggle
                        Item {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            visible: !messageRoot.selectionMode

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: msgDelegate.isStarred ? "starred-symbolic" : "non-starred-symbolic"
                                color: msgDelegate.isStarred ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    msgDelegate.isStarred = !msgDelegate.isStarred
                                    Pelliper.DaemonClient.setMessageStarred(
                                        msgDelegate.accountId,
                                        msgDelegate.folderPath,
                                        msgDelegate.uid,
                                        msgDelegate.isStarred
                                    )
                                }
                            }
                        }

                        Kirigami.Icon {
                            source: "mail-attachment"
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            visible: msgDelegate.hasAttachments
                        }
                    }

                    // Sender and date row
                    RowLayout {
                        Layout.fillWidth: true

                        Image {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            source: messageRoot.extractEmail(msgDelegate.sender).length > 0
                                ? Pelliper.DaemonClient.gravatarUrl(messageRoot.extractEmail(msgDelegate.sender), 40)
                                : ""
                            visible: source.length > 0
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: null
                        }

                        Controls.Label {
                            text: msgDelegate.sender
                            font.pointSize: 10
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Controls.Label {
                            text: {
                                if (msgDelegate.date <= 0) return ""
                                var d = new Date(msgDelegate.date * 1000)
                                var now = new Date()
                                if (d.toDateString() === now.toDateString()) {
                                    return Qt.formatTime(d, "HH:mm")
                                }
                                return Qt.formatDate(d, "MMM d")
                            }
                            font.pointSize: 10
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    // Preview text
                    Controls.Label {
                        text: msgDelegate.preview
                        font.pointSize: 10
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: msgDelegate.preview.length > 0
                        Layout.fillWidth: true
                    }
                }
            }

            onClicked: {
                if (messageRoot.selectionMode) {
                    messageRoot.toggleSelection(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid)
                } else {
                    messageList.currentIndex = index
                    messageSelected(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid, msgDelegate.subject, msgDelegate.sender, msgDelegate.date, msgDelegate.isRead, msgDelegate.isStarred)
                }
            }

            Controls.Menu {
                id: msgContextMenu

                Controls.MenuItem {
                    text: qsTr("Reply")
                    icon.name: "mail-reply-sender"
                    onTriggered: replyRequested(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid, msgDelegate.subject, msgDelegate.sender, msgDelegate.date, msgDelegate.isRead, msgDelegate.isStarred)
                }
                Controls.MenuItem {
                    text: qsTr("Forward")
                    icon.name: "mail-forward"
                    onTriggered: forwardRequested(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid, msgDelegate.subject, msgDelegate.sender, msgDelegate.date, msgDelegate.isRead, msgDelegate.isStarred)
                }

                Controls.MenuSeparator {}

                Controls.MenuItem {
                    text: msgDelegate.isRead ? qsTr("Mark as Unread") : qsTr("Mark as Read")
                    icon.name: msgDelegate.isRead ? "mail-unread" : "mail-read"
                    onTriggered: {
                        msgDelegate.isRead = !msgDelegate.isRead
                        Pelliper.DaemonClient.setMessageRead(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid, msgDelegate.isRead)
                    }
                }
                Controls.MenuItem {
                    text: msgDelegate.isStarred ? qsTr("Unstar") : qsTr("Star")
                    icon.name: msgDelegate.isStarred ? "non-starred-symbolic" : "starred-symbolic"
                    onTriggered: {
                        msgDelegate.isStarred = !msgDelegate.isStarred
                        Pelliper.DaemonClient.setMessageStarred(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid, msgDelegate.isStarred)
                    }
                }

                Controls.MenuSeparator {}

                Controls.MenuItem {
                    text: qsTr("Move to Trash")
                    icon.name: "user-trash"
                    onTriggered: Pelliper.DaemonClient.deleteMessage(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    msgContextMenu.popup(mouse.x, mouse.y)
                }
            }
        }
    }
}
