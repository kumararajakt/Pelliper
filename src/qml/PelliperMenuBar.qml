import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami

Platform.MenuBar {
    id: menuBar

    signal folderViewModeChanged(int mode)

    property int folderMode: 0

    Platform.Menu {
        title: qsTr("&View")

        Platform.Menu {
            title: qsTr("Folder Modes")

            Platform.MenuItem {
                text: qsTr("All Folders")
                checkable: true
                checked: menuBar.folderMode === 0
                onTriggered: {
                    menuBar.folderMode = 0
                    menuBar.folderViewModeChanged(0)
                }
            }
            Platform.MenuItem {
                text: qsTr("Unified Folders")
                checkable: true
                checked: menuBar.folderMode === 1
                onTriggered: {
                    menuBar.folderMode = 1
                    menuBar.folderViewModeChanged(1)
                }
            }
        }
    }

    Platform.Menu {
        title: qsTr("&Help")

        Platform.MenuItem {
            text: qsTr("About Pelliper")
            onTriggered: aboutDialog.open()
        }
    }

    Controls.Dialog {
        id: aboutDialog
        title: qsTr("About Pelliper")
        parent: Controls.Overlay.overlay
        modal: true
        anchors.centerIn: parent
        standardButtons: Controls.Dialog.Close
        width: 350

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: "mail-message-new"
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignHCenter
            }

            Controls.Label {
                text: "Pelliper"
                font.pointSize: 18
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Controls.Label {
                text: qsTr("A KDE email client")
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            Controls.Label {
                text: "© 2026 Pelliper contributors"
                font.pointSize: 10
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
