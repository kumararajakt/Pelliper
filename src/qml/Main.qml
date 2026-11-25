import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami

import "components"
import "dialogs"

Kirigami.ApplicationWindow {
    id: root
    title: i18n("Pelliper")
    width: 1200
    height: 760
    minimumWidth: 720
    minimumHeight: 480

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
                onTriggered: {
                    accountSetupDialog.resetWizard()
                    accountSetupDialog.open()
                }
            }
            Platform.MenuItem {
                text: i18n("&Settings…")
                shortcut: StandardKey.Preferences
                onTriggered: settingsDialog.open()
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
                    checked: appSettings.folderMode === "unified"
                    group: folderModeGroup
                    onTriggered: {
                        appSettings.folderMode = "unified"
                        folderModel.folderMode = "unified"
                    }
                }
                Platform.MenuItem {
                    text: i18n("&All Folders")
                    checkable: true
                    checked: appSettings.folderMode === "all"
                    group: folderModeGroup
                    onTriggered: {
                        appSettings.folderMode = "all"
                        folderModel.folderMode = "all"
                    }
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

    AccountSetupDialog {
        id: accountSetupDialog
    }

    SettingsDialog {
        id: settingsDialog
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
        id: mainPage
        title: i18n("Inbox")
        padding: 0

        RowLayout {
            anchors.fill: parent
            spacing: 0

            FolderSidebar {
                id: folderSidebar
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                onFolderSelected: (folderId, folderName, folderRole) => {
                    mainPage.title = folderName
                    messageListPane.activeFolderId = folderId
                    threadListModel.search("", folderId)
                }
            }

            Kirigami.Separator { Layout.fillHeight: true }

            MessageListPane {
                id: messageListPane
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                onMessageSelected: (accountId, messageId, senderName, subject, snippet) => {
                    messageViewPane.messageId = messageId
                    messageViewPane.senderName = senderName
                    messageViewPane.subject = subject
                    messageViewPane.bodyText = snippet
                }
            }

            Kirigami.Separator { Layout.fillHeight: true }

            MessageViewPane {
                id: messageViewPane
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
