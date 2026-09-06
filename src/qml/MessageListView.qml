import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ColumnLayout {

    // Header showing current folder
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
            text: Pelliper.MessageModel.count > 0 ? Pelliper.MessageModel.count.toString() : ""
            color: Kirigami.Theme.disabledTextColor
            visible: Pelliper.MessageModel.count > 0
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    ListView {
        id: messageList
        Layout.fillHeight: true
        Layout.fillWidth: true

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

                    Kirigami.Icon {
                        source: "starred-symbolic"
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        visible: msgDelegate.isStarred
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
            }
        }
    }
}
