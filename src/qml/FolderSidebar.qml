import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ListView {
    id: folderList

    model: Pelliper.FolderModel

    header: ColumnLayout {
        width: folderList.width

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing

            Controls.Label {
                text: qsTr("Folders")
                font.pointSize: 14
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            Controls.ToolButton {
                icon.name: "view-refresh"
                onClicked: Pelliper.FolderModel.refresh()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.largeSpacing * 4)
        visible: folderList.count === 0
        text: qsTr("No Folders Found")
    }

    delegate: Controls.ItemDelegate {
        id: folderDelegate
        required property int accountId
        required property string path
        required property int unreadCount
        required property string displayName
        required property string iconName
        required property int index

        width: folderList.width
        highlighted: folderList.currentIndex === index

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: folderDelegate.iconName
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }

            Controls.Label {
                text: folderDelegate.displayName
                Layout.fillWidth: true
                font.weight: folderDelegate.unreadCount > 0 ? Font.Bold : Font.Normal
            }

            Controls.Label {
                text: folderDelegate.unreadCount > 0 ? folderDelegate.unreadCount : ""
                color: Kirigami.Theme.highlightColor
                font.pointSize: 10
            }
        }

        onClicked: folderList.currentIndex = index
    }
}
