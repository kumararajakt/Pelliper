import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: sidebar
    color: Kirigami.Theme.alternateBackgroundColor

    property double selectedFolderId: 0
    property double dialogTargetId: 0
    property string dialogMode: "" // "create" | "rename"
    signal folderSelected(var folderId, string folderName, string folderRole)

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
                enabled: !model.isHeader
                highlighted: !model.isHeader && model.folderId > 0 && model.folderId === sidebar.selectedFolderId

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
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
                        opacity: model.isHeader ? 0.65 : 1.0
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
                    if (!model.isHeader) {
                        sidebar.selectedFolderId = model.folderId
                        sidebar.folderSelected(model.folderId, model.name, model.folderRole)
                    }
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
