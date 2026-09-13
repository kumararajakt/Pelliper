import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ColumnLayout {

    signal messageSelected(int accountId, string folderPath, int uid, string subject, string sender, real date, bool isRead, bool isStarred)

    property bool threaded: true

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing

        Controls.Label {
            text: Pelliper.MessageModel.folderPath ? Pelliper.MessageModel.folderPath : qsTr("Select a folder")
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
            visible: {
                var model = threaded ? Pelliper.ThreadModel : Pelliper.MessageModel
                return model.count > 0
            }
        }

        Kirigami.Icon {
            source: "view-sort"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16

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

    // Threaded view
    ListView {
        id: threadList
        Layout.fillHeight: true
        Layout.fillWidth: true
        visible: threaded

        model: Pelliper.ThreadModel

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

            contentItem: ColumnLayout {
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

            onClicked: {
                threadList.currentIndex = index
                messageSelected(threadDelegate.accountId, threadDelegate.folderPath, threadDelegate.uid, threadDelegate.subject, threadDelegate.sender, threadDelegate.date, threadDelegate.isRead, threadDelegate.isStarred)
            }
        }
    }

    // Flat view
    ListView {
        id: messageList
        Layout.fillHeight: true
        Layout.fillWidth: true
        visible: !threaded

        model: Pelliper.MessageModel

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

            contentItem: ColumnLayout {
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

            onClicked: {
                messageList.currentIndex = index
                messageSelected(msgDelegate.accountId, msgDelegate.folderPath, msgDelegate.uid, msgDelegate.subject, msgDelegate.sender, msgDelegate.date, msgDelegate.isRead, msgDelegate.isStarred)
            }
        }
    }
}
