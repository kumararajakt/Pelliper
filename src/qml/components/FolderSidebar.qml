import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: sidebar
    color: Kirigami.Theme.alternateBackgroundColor

    property double selectedFolderId: 0
    property string selectedFolderRole: "inbox"
    property double dialogTargetId: 0
    property string dialogMode: "" // "create" | "rename"
    signal folderSelected(var folderId, string folderName, string folderRole)

    Connections {
        target: folderModel
        function onModelReset() {
            if (folderModel.rowCount() > 0 && sidebar.selectedFolderId === 0) {
                for (let i = 0; i < folderModel.rowCount(); ++i) {
                    const idx = folderModel.index(i, 0)
                    const isHeader = folderModel.data(idx, 263) // IsHeaderRole
                    const role = folderModel.data(idx, 260) // RoleTypeRole
                    if (!isHeader && role === "inbox") {
                        const fid = folderModel.data(idx, 257) // IdRole
                        const fname = folderModel.data(idx, 259) // NameRole
                        sidebar.selectedFolderId = fid
                        sidebar.selectedFolderRole = role
                        sidebar.folderSelected(fid, fname, role)
                        break
                    }
                }
            }
        }
    }

    Kirigami.Dialog {
        id: folderNameDialog
        title: sidebar.dialogMode === "rename" ? i18n("Rename Folder") : i18n("New Folder")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        onAccepted: {
            if (sidebar.dialogMode === "rename") {
                folderModel.renameFolder(sidebar.dialogTargetId, folderNameInput.text)
            } else {
                folderModel.createFolder(sidebar.dialogTargetId, folderNameInput.text)
            }
        }
        Controls.TextField {
            id: folderNameInput
            width: 280
            placeholderText: i18n("Folder name (e.g. Work/Receipts)")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: folderList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: folderModel

            delegate: Controls.ItemDelegate {
                width: folderList.width
                highlighted: !model.isHeader && ((model.folderId > 0 && model.folderId === sidebar.selectedFolderId) || (model.isUnified && model.folderRole === sidebar.selectedFolderRole && sidebar.selectedFolderId === 0))

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Item {
                        visible: !model.isHeader && model.depth > 0
                        Layout.preferredWidth: model.depth * Kirigami.Units.largeSpacing
                    }
                    Controls.ToolButton {
                        visible: model.hasChildren
                        implicitWidth: Kirigami.Units.iconSizes.small + 4
                        implicitHeight: Kirigami.Units.iconSizes.small + 4
                        padding: 0
                        icon.name: model.expanded ? "arrow-down" : "arrow-right"
                        onClicked: folderModel.toggleCollapsed(model.collapseKey)
                    }
                    Kirigami.Icon {
                        visible: !model.isHeader
                        source: model.iconName
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    Controls.Label {
                        Layout.fillWidth: true
                        text: model.name
                        font.bold: model.isHeader || model.unreadCount > 0
                        opacity: model.isHeader ? 0.75 : 1.0
                        elide: Text.ElideRight
                    }
                    Controls.Label {
                        visible: !model.isHeader && model.unreadCount > 0
                        text: model.unreadCount
                        font.bold: true
                        color: Kirigami.Theme.highlightColor
                    }
                }

                onClicked: {
                    if (model.isHeader) {
                        if (model.hasChildren) {
                            folderModel.toggleCollapsed(model.collapseKey)
                        }
                        return
                    }
                    sidebar.selectedFolderId = model.folderId
                    sidebar.selectedFolderRole = model.folderRole
                    sidebar.folderSelected(model.folderId, model.name, model.folderRole)
                }

                Controls.Menu {
                    id: folderContextMenu
                    Controls.MenuItem {
                        text: i18n("Mark Folder as Read")
                        enabled: model.folderId > 0
                        onTriggered: folderModel.markFolderRead(model.folderId)
                    }
                    Controls.MenuSeparator {}
                    Controls.MenuItem {
                        text: i18n("New Folder…")
                        enabled: model.accountId > 0
                        onTriggered: {
                            sidebar.dialogMode = "create"
                            sidebar.dialogTargetId = model.accountId
                            folderNameInput.text = ""
                            folderNameDialog.open()
                        }
                    }
                    Controls.MenuItem {
                        text: i18n("Rename Folder…")
                        enabled: model.folderId > 0 && model.folderRole === "custom"
                        onTriggered: {
                            sidebar.dialogMode = "rename"
                            sidebar.dialogTargetId = model.folderId
                            folderNameInput.text = model.name
                            folderNameDialog.open()
                        }
                    }
                    Controls.MenuItem {
                        text: i18n("Delete Folder")
                        enabled: model.folderId > 0 && model.folderRole === "custom"
                        onTriggered: folderModel.deleteFolder(model.folderId)
                    }
                    Controls.MenuItem {
                        visible: model.folderRole === "trash" || model.folderRole === "spam"
                        text: model.folderRole === "trash" ? i18n("Empty Trash") : i18n("Empty Spam")
                        enabled: model.folderId > 0
                        onTriggered: folderModel.emptyFolder(model.folderId)
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: if (!model.isHeader && model.folderId > 0) folderContextMenu.popup()
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            Controls.Label {
                Layout.fillWidth: true
                text: daemonClient.statusText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
        }
    }
}
