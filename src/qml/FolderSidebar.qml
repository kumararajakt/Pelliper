import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ListView {
    id: folderList

    model: Pelliper.FolderModel

    signal folderSelected(int accountId, string folderPath)

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.largeSpacing * 4)
        visible: folderList.count === 0
        text: qsTr("No Folders Found")
        explanation: qsTr("Add an account and sync to see your folders here.")
    }

    delegate: Controls.ItemDelegate {
        id: item
        required property int accountId
        required property string path
        required property int unreadCount
        required property int depth
        required property bool hasChildren
        required property bool isExpanded
        required property bool isAccountHeader
        required property string email
        required property string displayName
        required property string iconName
        required property bool isEssential
        required property int index

        width: folderList.width

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            // Depth spacer (folders only)
            Item {
                Layout.preferredWidth: item.isAccountHeader ? 0 : item.depth * Kirigami.Units.gridUnit * 1.5
                visible: !item.isAccountHeader
            }

            // Spacer for account header
            Item {
                Layout.preferredWidth: item.isAccountHeader ? Kirigami.Units.smallSpacing : 0
                visible: item.isAccountHeader
            }

            // Expand/collapse arrow (account header)
            Kirigami.Icon {
                source: item.isExpanded ? "arrow-down" : "arrow-right"
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                visible: item.isAccountHeader
            }

            // Expand/collapse arrow (folder with children)
            Kirigami.Icon {
                source: item.isExpanded ? "arrow-down" : "arrow-right"
                Layout.preferredWidth: item.hasChildren ? 12 : 0
                Layout.preferredHeight: item.hasChildren ? 12 : 0
                visible: !item.isAccountHeader && item.hasChildren

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pelliper.FolderModel.toggleExpanded(item.index)
                }
            }

            // User icon (account header)
            Kirigami.Icon {
                source: "user"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: item.isAccountHeader
            }

            // Folder icon
            Kirigami.Icon {
                source: item.iconName
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: !item.isAccountHeader
            }

            // Email label (account header)
            Controls.Label {
                text: item.email
                font.pointSize: 13
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: item.isAccountHeader
            }

            // Folder name
            Controls.Label {
                text: item.displayName
                Layout.fillWidth: true
                font.weight: item.unreadCount > 0 ? Font.Bold : Font.Normal
                elide: Text.ElideRight
                visible: !item.isAccountHeader
            }

            // Unread badge
            Controls.Label {
                text: item.unreadCount > 0 ? item.unreadCount.toString() : ""
                color: Kirigami.Theme.highlightColor
                font.pointSize: 10
                visible: !item.isAccountHeader && item.unreadCount > 0
            }
        }

        onClicked: {
            if (item.isAccountHeader) {
                Pelliper.FolderModel.toggleExpanded(item.index)
            } else {
                folderList.currentIndex = index
                folderList.folderSelected(item.accountId, item.path)
            }
        }
    }
}
