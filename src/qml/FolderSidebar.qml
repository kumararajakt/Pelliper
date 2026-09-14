import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

ListView {
    id: folderList

    model: Pelliper.FolderModel

    property int savedAccountId: Number(settings.value("lastAccountId", -1))
    property string savedFolderPath: settings.value("lastFolderPath", "")
    property bool unifiedMode: false

    signal folderSelected(int accountId, string folderPath)
    signal composeRequested()

    header: ColumnLayout {
        width: folderList.width
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Controls.ToolButton {
                Layout.fillWidth: true
                text: qsTr("Compose")
                icon.name: "mail-message-new"
                onClicked: folderList.composeRequested()
            }

            Controls.ToolButton {
                icon.name: folderList.unifiedMode ? "view-refresh" : "view-list-icons"
                Controls.ToolTip.text: folderList.unifiedMode ? qsTr("Normal view") : qsTr("Unified inbox")
                Controls.ToolTip.visible: hovered
                onClicked: {
                    folderList.unifiedMode = !folderList.unifiedMode
                    if (folderList.unifiedMode) {
                        folderList.folderSelected(-1, "INBOX")
                    } else {
                        folderList.restoreSelection()
                    }
                }
            }
        }

        // Unified inbox pseudo-entry (only visible in unified mode)
        Controls.ItemDelegate {
            width: folderList.width
            visible: folderList.unifiedMode
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    source: "inbox"
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
                Controls.Label {
                    text: qsTr("All Inboxes")
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }
            }
            onClicked: folderList.folderSelected(-1, "INBOX")
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: folderList.unifiedMode
        }
    }

    Settings {
        id: settings
        category: "folder"
    }

    function saveSelection(accountId, folderPath) {
        settings.setValue("lastAccountId", accountId)
        settings.setValue("lastFolderPath", folderPath)
    }

    function restoreSelection() {
        if (savedAccountId >= 0 && savedFolderPath !== "") {
            folderSelected(savedAccountId, savedFolderPath)
        }
    }

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
        visible: !folderList.unifiedMode || item.path === "INBOX"

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
                folderList.saveSelection(item.accountId, item.path)
            }
        }
    }
}
