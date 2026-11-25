import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: i18n("Pelliper")
    width: 1200
    height: 760
    minimumWidth: 720
    minimumHeight: 480

    property string folderMode: "unified" // "unified" | "all"
    property bool showBodyPreview: true

    Platform.MenuBar {
        Platform.Menu {
            title: i18n("&File")
            Platform.MenuItem {
                text: i18n("&New Message…")
                shortcut: StandardKey.New
                onTriggered: console.log("Compose triggered")
            }
            Platform.MenuItem {
                text: i18n("&Add Account…")
                onTriggered: console.log("Add Account wizard triggered")
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: i18n("&Quit")
                shortcut: StandardKey.Quit
                onTriggered: Qt.quit()
            }
        }

        Platform.Menu {
            title: i18n("&View")
            Platform.Menu {
                title: i18n("&Folder Modes")
                Platform.MenuItemGroup {
                    id: folderModeGroup
                }
                Platform.MenuItem {
                    text: i18n("&Unified")
                    checkable: true
                    checked: root.folderMode === "unified"
                    group: folderModeGroup
                    onTriggered: root.folderMode = "unified"
                }
                Platform.MenuItem {
                    text: i18n("&All Folders")
                    checkable: true
                    checked: root.folderMode === "all"
                    group: folderModeGroup
                    onTriggered: root.folderMode = "all"
                }
            }
        }

        Platform.Menu {
            title: i18n("&Help")
            Platform.MenuItem {
                text: i18n("&About Pelliper")
                onTriggered: aboutDialog.open()
            }
        }
    }

    Kirigami.Dialog {
        id: aboutDialog
        title: i18n("About Pelliper")
        standardButtons: Kirigami.Dialog.Close
        padding: Kirigami.Units.largeSpacing

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                text: i18n("Pelliper 0.1.0")
                level: 2
            }
            Controls.Label {
                text: i18n("Independent Qt/Kirigami email client backed by pelliper-daemon.")
                wrapMode: Text.WordWrap
            }
            Controls.Label {
                text: i18n("Daemon status: %1", daemonClient.statusText)
                opacity: 0.75
            }
        }
    }

    pageStack.initialPage: Kirigami.Page {
        title: i18n("Inbox")
        padding: 0

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Column 1: Folder Sidebar
            Rectangle {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                color: Kirigami.Theme.alternateBackgroundColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: root.folderMode === "unified" ? i18n("Unified Folders") : i18n("All Accounts")
                        font.bold: true
                    }

                    Controls.Label {
                        text: i18n("No accounts configured yet.\nUse File → Add Account…")
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    Controls.Label {
                        text: daemonClient.statusText
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                }
            }

            Kirigami.Separator { Layout.fillHeight: true }

            // Column 2: Message List + Top Search Bar
            ColumnLayout {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                spacing: 0

                Controls.ToolBar {
                    Layout.fillWidth: true
                    Kirigami.SearchField {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        placeholderText: i18n("Search (from:, in:, is:, has:)…")
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        text: i18n("No Messages")
                        explanation: i18n("Add an email account to start syncing with pelliper-daemon.")
                        icon.name: "mail-receive"
                    }
                }
            }

            Kirigami.Separator { Layout.fillHeight: true }

            // Column 3: Reading Pane
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    text: i18n("Select a conversation to read")
                    icon.name: "mail-read"
                }
            }
        }
    }
}
