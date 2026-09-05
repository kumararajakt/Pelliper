import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: 0

    property int selectedIndex: 0

    // Pane 1: Sidebar
    Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: 280
        color: Kirigami.Theme.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                Controls.Label {
                    text: "Pelliper"
                    font.pointSize: 14
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                Controls.ToolButton {
                    icon.name: "list-add"
                    onClicked: {
                        // TODO: add account
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            ListView {
                id: folderList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                model: ListModel {
                    ListElement { name: "All Inboxes"; iconName: "inbox"; unread: 0 }
                    ListElement { name: "Inbox"; iconName: "inbox"; unread: 5 }
                    ListElement { name: "Sent"; iconName: "mail-sent"; unread: 0 }
                    ListElement { name: "Drafts"; iconName: "document-edit"; unread: 0 }
                    ListElement { name: "Archive"; iconName: "archive"; unread: 0 }
                    ListElement { name: "Trash"; iconName: "user-trash"; unread: 0 }
                    ListElement { name: "Spam"; iconName: "mail-receive"; unread: 0 }
                    ListElement { name: "Starred"; iconName: "starred"; unread: 2 }
                }

                delegate: Controls.ItemDelegate {
                    required property string name
                    required property string iconName
                    required property int unread
                    required property int index
                    width: folderList.width

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: iconName
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                        }

                        Controls.Label {
                            text: name
                            Layout.fillWidth: true
                            font.weight: unread > 0 ? Font.Bold : Font.Normal
                        }

                        Controls.Label {
                            text: unread > 0 ? unread : ""
                            color: Kirigami.Theme.highlightColor
                            font.pointSize: 10
                        }
                    }

                    onClicked: root.selectedIndex = index
                }
            }
        }
    }

    // Pane 2: Message List
    Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: 350
        color: Kirigami.Theme.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                Controls.TextField {
                    placeholderText: "Search..."
                    Layout.fillWidth: true
                }

                Controls.ToolButton {
                    icon.name: "mail-message-new"
                    onClicked: {
                        // TODO: compose
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            ListView {
                id: messageList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                model: ListModel {
                    ListElement { sender: "Alice"; subject: "Meeting tomorrow"; date: "10:30"; unread: true }
                    ListElement { sender: "Bob"; subject: "Project update"; date: "Yesterday"; unread: true }
                    ListElement { sender: "Charlie"; subject: "Re: Design review"; date: "Sep 3"; unread: false }
                }

                delegate: Controls.ItemDelegate {
                    required property string sender
                    required property string subject
                    required property string date
                    required property bool unread
                    width: messageList.width

                    contentItem: ColumnLayout {
                        spacing: 2

                        RowLayout {
                            Controls.Label {
                                text: sender
                                font.weight: unread ? Font.Bold : Font.Normal
                                Layout.fillWidth: true
                            }
                            Controls.Label {
                                text: date
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: 10
                            }
                        }

                        Controls.Label {
                            text: subject
                            elide: Text.ElideRight
                            color: unread ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                        }
                    }
                }
            }
        }
    }

    // Pane 3: Reader
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Kirigami.Theme.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                Controls.Label {
                    text: "Select a message"
                    font.pointSize: 14
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                Controls.ToolButton { icon.name: "mail-reply-sender" }
                Controls.ToolButton { icon.name: "mail-forward" }
                Controls.ToolButton { icon.name: "archive" }
                Controls.ToolButton { icon.name: "user-trash" }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Controls.Label {
                text: "No message selected"
                anchors.centerIn: parent
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}
