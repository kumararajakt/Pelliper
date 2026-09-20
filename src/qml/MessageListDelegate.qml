import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper

/// Delegate for the flat (unthreaded) message list.
/// `listView` is the owning ListView; `listRoot` is the MessageListView root
/// that owns selection state (selectionMode / isSelected / toggleSelection /
/// extractEmail) and the messageSelected / replyRequested / forwardRequested
/// signals.
Controls.ItemDelegate {
    id: delegate

    required property ListView listView
    required property QtObject listRoot

    // Model roles
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

    width: listView.width
    background: Rectangle {
        color: listRoot.isSelected(delegate.accountId, delegate.folderPath, delegate.uid)
            ? Kirigami.Theme.highlightColor
            : "transparent"
        opacity: listRoot.isSelected(delegate.accountId, delegate.folderPath, delegate.uid) ? 0.15 : 1
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        // Checkbox (selection mode)
        Controls.CheckBox {
            visible: listRoot.selectionMode
            checked: listRoot.isSelected(delegate.accountId, delegate.folderPath, delegate.uid)
            onClicked: listRoot.toggleSelection(delegate.accountId, delegate.folderPath, delegate.uid)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Subject and star row
            RowLayout {
                Layout.fillWidth: true

                Controls.Label {
                    text: delegate.subject || qsTr("(no subject)")
                    font.weight: delegate.isRead ? Font.Normal : Font.Bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Star toggle
                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    visible: !listRoot.selectionMode

                    Kirigami.Icon {
                        anchors.fill: parent
                        source: delegate.isStarred ? "starred-symbolic" : "non-starred-symbolic"
                        color: delegate.isStarred ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            delegate.isStarred = !delegate.isStarred
                            Pelliper.DaemonClient.setMessageStarred(
                                delegate.accountId,
                                delegate.folderPath,
                                delegate.uid,
                                delegate.isStarred
                            )
                        }
                    }
                }

                Kirigami.Icon {
                    source: "mail-attachment"
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    visible: delegate.hasAttachments
                }
            }

            // Sender and date row
            RowLayout {
                Layout.fillWidth: true

                Image {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: listRoot.extractEmail(delegate.sender).length > 0
                        ? Pelliper.DaemonClient.gravatarUrl(listRoot.extractEmail(delegate.sender), 40)
                        : ""
                    visible: source.length > 0
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: null
                }

                Controls.Label {
                    text: delegate.sender
                    font.pointSize: 10
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Controls.Label {
                    text: {
                        if (delegate.date <= 0) return ""
                        var d = new Date(delegate.date * 1000)
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
                text: delegate.preview
                font.pointSize: 10
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: delegate.preview.length > 0
                Layout.fillWidth: true
            }
        }
    }

    onClicked: {
        if (listRoot.selectionMode) {
            listRoot.toggleSelection(delegate.accountId, delegate.folderPath, delegate.uid)
        } else {
            listView.currentIndex = index
            listRoot.messageSelected(delegate.accountId, delegate.folderPath, delegate.uid, delegate.subject, delegate.sender, delegate.date, delegate.isRead, delegate.isStarred)
        }
    }

    Controls.Menu {
        id: msgContextMenu

        Controls.MenuItem {
            text: qsTr("Reply")
            icon.name: "mail-reply-sender"
            onTriggered: listRoot.replyRequested(delegate.accountId, delegate.folderPath, delegate.uid, delegate.subject, delegate.sender, delegate.date, delegate.isRead, delegate.isStarred)
        }
        Controls.MenuItem {
            text: qsTr("Forward")
            icon.name: "mail-forward"
            onTriggered: listRoot.forwardRequested(delegate.accountId, delegate.folderPath, delegate.uid, delegate.subject, delegate.sender, delegate.date, delegate.isRead, delegate.isStarred)
        }

        Controls.MenuSeparator {}

        Controls.MenuItem {
            text: delegate.isRead ? qsTr("Mark as Unread") : qsTr("Mark as Read")
            icon.name: delegate.isRead ? "mail-unread" : "mail-read"
            onTriggered: {
                delegate.isRead = !delegate.isRead
                Pelliper.DaemonClient.setMessageRead(delegate.accountId, delegate.folderPath, delegate.uid, delegate.isRead)
            }
        }
        Controls.MenuItem {
            text: delegate.isStarred ? qsTr("Unstar") : qsTr("Star")
            icon.name: delegate.isStarred ? "non-starred-symbolic" : "starred-symbolic"
            onTriggered: {
                delegate.isStarred = !delegate.isStarred
                Pelliper.DaemonClient.setMessageStarred(delegate.accountId, delegate.folderPath, delegate.uid, delegate.isStarred)
            }
        }

        Controls.MenuSeparator {}

        Controls.MenuItem {
            text: qsTr("Move to Trash")
            icon.name: "user-trash"
            onTriggered: Pelliper.DaemonClient.deleteMessage(delegate.accountId, delegate.folderPath, delegate.uid)
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