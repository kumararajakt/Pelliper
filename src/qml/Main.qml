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

    function openComposer() {
        composerDialog.openCompose(messageController.accountId)
    }

    function isTextInputFocused() {
        const item = activeFocusItem
        return item && (item.toString().indexOf("TextField") >= 0 || item.toString().indexOf("TextArea") >= 0 || item.toString().indexOf("SearchField") >= 0)
    }

    onClosing: (close) => {
        close.accepted = false
        root.hide()
    }

    menuBar: Controls.MenuBar {
        Controls.Menu {
            title: i18n("&File")
            Controls.MenuItem {
                text: i18n("&New Message…")
                icon.name: "mail-message-new"
                visible: accountController.accountCount > 0
                enabled: accountController.accountCount > 0
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
        onSendRequested: (accountId, to, cc, bcc, subject, body, attachments) => {
            const delay = appSettings.undoSendSecs
            if (delay <= 0) {
                messageController.sendMessage(accountId, to, cc, bcc, subject, body, attachments)
                return
            }
            undoSendTimer.pendingPayload = {
                "accountId": accountId,
                "to": to,
                "cc": cc,
                "bcc": bcc,
                "subject": subject,
                "body": body,
                "attachments": attachments
            }
            undoSendTimer.interval = delay * 1000
            undoSendTimer.restart()
            root.showPassiveNotification(
                i18n("Sending in %1s…", delay),
                delay * 1000,
                i18n("Undo"),
                function() {
                    undoSendTimer.stop()
                    undoSendTimer.pendingPayload = null
                    root.showPassiveNotification(i18n("Send cancelled"), "short")
                    composerDialog.open()
                }
            )
        }
    }

    Timer {
        id: undoSendTimer
        property var pendingPayload: null
        onTriggered: {
            if (pendingPayload) {
                const p = pendingPayload
                pendingPayload = null
                messageController.sendMessage(p.accountId, p.to, p.cc, p.bcc, p.subject, p.body, p.attachments)
            }
        }
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
        function onAttachmentSaved(path) {
            root.showPassiveNotification(i18n("Saved attachment to %1", path), "short")
        }
        function onAttachmentError(error) {
            root.showPassiveNotification(i18n("Attachment error: %1", error), "long")
        }
    }

    Shortcut {
        sequences: [StandardKey.New]
        enabled: accountController.accountCount > 0
        onActivated: composerDialog.openCompose(messageController.accountId)
    }
    Shortcut {
        sequence: "c"
        enabled: !root.isTextInputFocused() && accountController.accountCount > 0
        onActivated: composerDialog.openCompose(messageController.accountId)
    }
    Shortcut {
        sequence: "r"
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: composerDialog.openReply(
            messageController.accountId,
            messageController.senderAddress,
            messageController.senderName,
            messageController.subject,
            messageController.dateText,
            messageController.textPlain
        )
    }
    Shortcut {
        sequence: "a"
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: composerDialog.openReplyAll(
            messageController.accountId,
            messageController.senderAddress,
            messageController.ccText,
            messageController.senderName,
            messageController.subject,
            messageController.dateText,
            messageController.textPlain
        )
    }
    Shortcut {
        sequence: "f"
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: composerDialog.openForward(
            messageController.accountId,
            messageController.senderName,
            messageController.toText,
            messageController.subject,
            messageController.dateText,
            messageController.textPlain,
            messageController.attachments
        )
    }
    Shortcut {
        sequence: "s"
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: {
            const nextStar = !messageController.starred
            messageController.toggleStar(messageController.messageId, nextStar)
            threadListModel.updateFlagsOptimistic(messageController.messageId, messageController.unread, nextStar)
        }
    }
    Shortcut {
        sequence: "u"
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: {
            const markRead = messageController.unread
            messageController.toggleRead(messageController.messageId, markRead)
            threadListModel.updateFlagsOptimistic(messageController.messageId, !markRead, messageController.starred)
        }
    }
    Shortcut {
        sequence: "e"
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: {
            const id = messageController.messageId
            messageController.archiveMessage(id)
            threadListModel.removeMessageOptimistic(id)
        }
    }
    Shortcut {
        sequences: ["Delete", "#"]
        enabled: !root.isTextInputFocused() && messageController.messageId > 0
        onActivated: {
            const id = messageController.messageId
            messageController.deleteMessage(id)
            threadListModel.removeMessageOptimistic(id)
        }
    }
    Shortcut {
        sequence: "/"
        enabled: !root.isTextInputFocused()
        onActivated: {
            if (root.pageStack.currentItem && root.pageStack.currentItem.focusSearch) {
                root.pageStack.currentItem.focusSearch()
            }
        }
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
                text: i18n("Qt/Kirigami email client")
                wrapMode: Text.WordWrap
            }
            Controls.Label {
                text: i18n("Daemon status: %1", daemonClient.statusText)
                opacity: 0.75
            }
        }
    }

    property bool showingWelcome: accountController.accountCount === 0

    onShowingWelcomeChanged: {
        pageStack.replace(showingWelcome ? welcomeAddAccountPage : threePanePage)
    }

    Component {
        id: welcomeAddAccountPage
        Kirigami.Page {
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 4
                text: i18n("Welcome to Pelliper")
                icon.name: "mail-client"
                helpfulAction: Kirigami.Action {
                    text: i18n("Add Account")
                    icon.name: "list-add-user"
                    onTriggered: {
                        accountSetupDialog.resetWizard()
                        accountSetupDialog.open()
                    }
                }
            }
        }
    }

    Component {
        id: threePanePage
        Kirigami.Page {
            id: mainPage
            title: i18n("Inbox")
            padding: 0

            function focusSearch() {
                messageListPane.focusSearch()
            }

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
                        messageListPane.activeFolderRole = folderRole
                        threadListModel.search("", folderId, false, folderRole)
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

    pageStack.initialPage: accountController.accountCount === 0 ? welcomeAddAccountPage : threePanePage
}
