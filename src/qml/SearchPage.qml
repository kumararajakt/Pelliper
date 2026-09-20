import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper

Kirigami.Page {
    id: root
    title: qsTr("Search")

    signal openMessage(int accountId, string folderPath, int uid, string subject, string sender, real date)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: qsTr("Search messages...")
            focus: true
            onTextChanged: searchTimer.restart()
        }

        Timer {
            id: searchTimer
            interval: 250
            onTriggered: Pelliper.SearchModel.search(searchField.text)
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: Pelliper.SearchModel

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - (Kirigami.Units.largeSpacing * 4)
                visible: resultList.count === 0 && searchField.text.trim().length >= 2
                text: qsTr("No Results")
                explanation: qsTr("Nothing matches your search. Try a different query.")
            }

            delegate: Controls.ItemDelegate {
                id: resultItem
                required property int accountId
                required property string folderPath
                required property int uid
                required property string subject
                required property string sender
                required property real date
                required property string preview
                required property bool isRead
                required property int index

                width: resultList.width

                contentItem: ColumnLayout {
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Controls.Label {
                            text: resultItem.subject || qsTr("(no subject)")
                            font.weight: resultItem.isRead ? Font.Normal : Font.Bold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Controls.Label {
                            text: {
                                if (resultItem.date <= 0) return ""
                                var d = new Date(resultItem.date * 1000)
                                return Qt.formatDateTime(d, "MMM d, yyyy HH:mm")
                            }
                            font.pointSize: 10
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    Controls.Label {
                        text: resultItem.sender
                            + (resultItem.folderPath.length > 0 ? "  •  " + resultItem.folderPath : "")
                        font.pointSize: 10
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Controls.Label {
                        text: resultItem.preview
                        font.pointSize: 10
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: resultItem.preview.length > 0
                        Layout.fillWidth: true
                    }
                }

                onClicked: {
                    root.openMessage(
                        resultItem.accountId, resultItem.folderPath, resultItem.uid,
                        resultItem.subject, resultItem.sender, resultItem.date)
                }
            }
        }
    }

    Component.onDestruction: {
        Pelliper.SearchModel.clear()
    }
}