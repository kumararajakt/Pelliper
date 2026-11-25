import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: i18n("Pelliper")
    width: 1200
    height: 760
    minimumWidth: 720
    minimumHeight: 480

    menuBar: Controls.MenuBar {
        Controls.Menu {
            title: i18n("&File")
            Controls.MenuItem {
                text: i18n("&New Message…")
                icon.name: "mail-message-new"
                onTriggered: composerDialog.openCompose(messageController.accountId)
            }
            Controls.MenuItem {
                text: i18n("&Add Account…")
                icon.name: "list-add-user"
                onTriggered: {
                    accountSetupDialog.resetWizard()
                    accountSetupDialog.open()
                }
            }
            Controls.MenuItem {
                text: i18n("&Settings…")
                icon.name: "configure"
                onTriggered: settingsDialog.open()
            }
            Controls.MenuSeparator {}
            Controls.MenuItem {
                text: i18n("&Quit")
                icon.name: "application-exit"
                onTriggered: Qt.quit()
            }
        }

        Controls.Menu {
            title: i18n("&View")
            Controls.Menu {
                title: i18n("&Folder Modes")
                Controls.ActionGroup {
                    id: folderModeGroup
                }
                Controls.MenuItem {
                    text: i18n("&Unified")
                    checkable: true
                    checked: appSettings.folderMode === "unified"
                    Controls.ActionGroup.group: folderModeGroup
                    onTriggered: {
                        appSettings.folderMode = "unified"
                        folderModel.folderMode = "unified"
                    }
                }
                Controls.MenuItem {
                    text: i18n("&All Folders")
                    checkable: true
                    checked: appSettings.folderMode === "all"
                    Controls.ActionGroup.group: folderModeGroup
                    onTriggered: {
                        appSettings.folderMode = "all"
                        folderModel.folderMode = "all"
                    }
                }
            }
        }

        Controls.Menu {
            title: i18n("&Help")
            Controls.MenuItem {
                text: i18n("&About Pelliper")
                icon.name: "help-about"
                onTriggered: aboutDialog.open()
            }
        }
    }

    AccountSetupDialog {
        id: accountSetupDialog
    }

    ComposerDialog {
        id: composerDialog
    }

    Connections {
        target: messageController
        function onOutboxStatus(status, error) {
            if (status === "queued") {
                root.showPassiveNotification(i18n("Sending message…"), "short")
            } else if (status === "sent") {
                root.showPassiveNotification(i18n("Message sent"), "short")
            } else if (status === "failed" || status === "retrying") {
                root.showPassiveNotification(i18n("Send issue: %1", error), "long")
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.New]
        onActivated: composerDialog.openCompose(messageController.accountId)
    }

    Shortcut {
        sequences: [StandardKey.Preferences]
        onActivated: settingsDialog.open()
    }
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
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
                    messageViewPane.allowRemoteImages = false
                    messageController.openMessage(accountId, messageId)
                }
            }

            Kirigami.Separator { Layout.fillHeight: true }

            MessageViewPane {
                id: messageViewPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                onReplyRequested: composerDialog.openReply(
                    messageController.accountId,
                    messageController.senderAddress,
                    messageController.senderName,
                    messageController.subject,
                    messageController.dateText,
                    messageController.textPlain
                )
                onReplyAllRequested: composerDialog.openReplyAll(
                    messageController.accountId,
                    messageController.senderAddress,
                    messageController.ccText,
                    messageController.senderName,
                    messageController.subject,
                    messageController.dateText,
                    messageController.textPlain
                )
                onForwardRequested: composerDialog.openForward(
                    messageController.accountId,
                    messageController.senderName,
                    messageController.toText,
                    messageController.subject,
                    messageController.dateText,
                    messageController.textPlain,
                    messageController.attachments
                )
            }
        }
    }
}
