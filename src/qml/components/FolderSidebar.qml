import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: sidebar
    color: Kirigami.Theme.alternateBackgroundColor

    property qint64 selectedFolderId: 0
    signal folderSelected(var folderId, string folderName, string folderRole)

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
