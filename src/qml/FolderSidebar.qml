import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ListView {
    id: folderList

    model: Pelliper.FolderModel

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.largeSpacing * 4)
        visible: folderList.count === 0
        text: qsTr("No Folders Found")
        explanation: qsTr("Add an account and sync to see your folders here.")
    }

    delegate: Controls.ItemDelegate {
        id: folderDelegate
        required property int accountId
        required property string path
        required property int unreadCount
        required property int depth
        required property bool hasChildren
        required property bool isExpanded
        required property string displayName
        required property string iconName
        required property bool isEssential
        required property int index

        width: folderList.width
        highlighted: folderList.currentIndex === index

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            // Indentation for nested custom folders
            Item {
                Layout.preferredWidth: folderDelegate.depth * Kirigami.Units.gridUnit * 1.5
            }

            // Expand/collapse arrow for folders with children
            Kirigami.Icon {
                source: folderDelegate.isExpanded ? "arrow-down" : "arrow-right"
                Layout.preferredWidth: folderDelegate.hasChildren ? 12 : 0
                Layout.preferredHeight: folderDelegate.hasChildren ? 12 : 0
                visible: folderDelegate.hasChildren

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pelliper.FolderModel.toggleExpanded(folderDelegate.index)
                }
            }

            // Placeholder when no arrow
            Item {
                visible: !folderDelegate.hasChildren
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
            }

            Kirigami.Icon {
                source: folderDelegate.iconName
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }

            Controls.Label {
                text: folderDelegate.displayName
                Layout.fillWidth: true
                font.weight: folderDelegate.unreadCount > 0 ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }

            Controls.Label {
                text: folderDelegate.unreadCount > 0 ? folderDelegate.unreadCount : ""
                color: Kirigami.Theme.highlightColor
                font.pointSize: 10
                visible: folderDelegate.unreadCount > 0
            }
        }

        onClicked: {
            if (folderDelegate.hasChildren) {
                Pelliper.FolderModel.toggleExpanded(folderDelegate.index)
            }
            folderList.currentIndex = index
        }
    }
}
