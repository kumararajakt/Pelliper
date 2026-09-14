import QtQuick
import QtQuick.Controls as Controls

Controls.MenuBar {
    id: menuBar

    signal folderViewModeChanged(int mode)

    property int folderMode: 0

    Controls.Menu {
        title: qsTr("&View")

        Controls.Menu {
            title: qsTr("Folder Modes")
            id: folderModesMenu

            Controls.MenuItem {
                text: qsTr("All Folders")
                checkable: true
                checked: menuBar.folderMode === 0
                onTriggered: {
                    menuBar.folderMode = 0
                    menuBar.folderViewModeChanged(0)
                }
            }
            Controls.MenuItem {
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

    Controls.Menu {
        title: qsTr("&Help")

        Controls.MenuItem {
            text: qsTr("About Pelliper")
            onTriggered: {
                applicationWindow().pageStack.push(aboutPageComponent)
            }
        }
    }
}
