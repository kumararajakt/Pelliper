import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: mainPage

    property int selectedAccountId: -1
    property string selectedFolderPath: ""
    property int selectedUid: -1

    function setFolderMode(mode) {
        sidebar.unifiedMode = (mode === 1)
        if (sidebar.unifiedMode) {
            sidebar.folderSelected(-1, "INBOX")
        } else {
            sidebar.restoreSelection()
        }
    }

    Component {
        id: settingsPageComponent
        SettingsPage {
            onAddAccountRequested: {
                applicationWindow().pageStack.pop()
                applicationWindow().pageStack.layers.push(addAccountPageComponent)
            }
            onEmptyStateRequested: {
                applicationWindow().pageStack.clear()
                applicationWindow().pageStack.layers.push(emptyStateComponent)
            }
        }
    }

    Component {
        id: addAccountPageComponent
        AddAccountPage {}
    }

    Component {
        id: emptyStateComponent
        Kirigami.Page {
            title: "Pelliper"
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing
                Controls.Button {
                    text: "Add Account"
                    icon.name: "list-add-user"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: applicationWindow().pageStack.layers.push(addAccountPageComponent)
                }
            }
        }
    }

    Component {
        id: composePageComponent
        ComposePage {}
    }

    function openCompose(accountId, to, subject, body) {
        var page = composePageComponent.createObject(applicationWindow())
        // If no explicit content provided, try restoring a saved draft.
        if (!to && !subject && !body && page.loadDraft()) {
            applicationWindow().showPassiveNotification(qsTr("Draft restored"))
        } else {
            page.openTo(accountId, to, subject, body)
        }
        applicationWindow().pageStack.layers.push(page)
    }

    Component {
        id: searchPageComponent
        SearchPage {
            onOpenMessage: function (accountId, folderPath, uid, subject, sender, date) {
                applicationWindow().pageStack.layers.pop()
                mainPage.openMessageInView(accountId, folderPath, uid, subject, sender, date)
            }
        }
    }

    function openMessageInView(accountId, folderPath, uid, subject, sender, date) {
        mainPage.selectedAccountId = accountId
        mainPage.selectedFolderPath = folderPath
        mainPage.selectedUid = uid

        Pelliper.MessageModel.accountId = accountId
        Pelliper.MessageModel.folderPath = folderPath
        Pelliper.ThreadModel.accountId = accountId
        Pelliper.ThreadModel.folderPath = folderPath
        Pelliper.DaemonClient.setIdleFolder(accountId, folderPath)

        messageView.subject = subject || ""
        messageView.sender = sender || ""
        messageView.messageDate = date || 0
        messageView.accountId = accountId
        messageView.folderPath = folderPath
        messageView.isRead = true
        messageView.isStarred = false
        messageView.bodyHtml = ""
        messageView.currentUid = uid
        Pelliper.DaemonClient.loadBody(accountId, folderPath, uid)
        Pelliper.DaemonClient.setMessageRead(accountId, folderPath, uid, true)
    }

    actions: [
        Kirigami.Action {
            text: qsTr("Compose")
            icon.name: "mail-new"
            onTriggered: {
                var accountId = mainPage.selectedAccountId
                if (accountId < 0) {
                    accountId = Pelliper.AccountModel.firstAccountId()
                }
                var page = composePageComponent.createObject(applicationWindow())
                page.openTo(accountId)
                applicationWindow().pageStack.layers.push(page)
            }
        },
        Kirigami.Action {
            text: qsTr("Search")
            icon.name: "system-search"
            shortcut: "Ctrl+F"
            onTriggered: {
                applicationWindow().pageStack.layers.push(searchPageComponent)
            }
        },
        Kirigami.Action {
            text: qsTr("Settings")
            icon.name: "configure"
            onTriggered: applicationWindow().pageStack.layers.push(settingsPageComponent)
        }
    ]

    Controls.SplitView {
        id: splitView
        anchors.fill: parent
        handle: Kirigami.Separator {}

        ColumnLayout {
            Controls.SplitView.preferredWidth: Kirigami.Units.gridUnit * 12
            spacing: 0

            FolderSidebar {
                id: sidebar
                Layout.fillWidth: true
                Layout.fillHeight: true

                onFolderSelected: function (accountId, folderPath) {
                    var unified = (accountId === -1)
                    Pelliper.MessageModel.unifiedInbox = unified;
                    Pelliper.ThreadModel.unifiedInbox = unified;
                    if (!unified) {
                        Pelliper.MessageModel.accountId = accountId;
                        Pelliper.MessageModel.folderPath = folderPath;
                        Pelliper.ThreadModel.accountId = accountId;
                        Pelliper.ThreadModel.folderPath = folderPath;
                        Pelliper.DaemonClient.setIdleFolder(accountId, folderPath);
                    } else {
                        Pelliper.MessageModel.accountId = -1;
                        Pelliper.MessageModel.folderPath = folderPath;
                        Pelliper.ThreadModel.accountId = -1;
                        Pelliper.ThreadModel.folderPath = folderPath;
                    }
                }

                onComposeRequested: {
                    var accountId = Pelliper.AccountModel.count > 0 ? Pelliper.AccountModel.firstAccountId() : -1
                    root.openCompose(accountId, "", "", "")
                }

                Component.onCompleted: {
                    if (Pelliper.FolderModel.count > 0) {
                        if (sidebar.savedAccountId >= 0 && sidebar.savedFolderPath !== "") {
                            sidebar.restoreSelection();
                        } else {
                            var roles = Pelliper.FolderModel.roleNames;
                            var pathRole = 0, acidRole = 0;
                            for (var key in roles) {
                                if (roles[key] === "path")
                                    pathRole = Number(key);
                                if (roles[key] === "accountId")
                                    acidRole = Number(key);
                            }
                            for (var i = 0; i < Pelliper.FolderModel.count; i++) {
                                var idx = Pelliper.FolderModel.index(i, 0);
                                var path = Pelliper.FolderModel.data(idx, pathRole);
                                if (path === "INBOX") {
                                    var acid = Pelliper.FolderModel.data(idx, acidRole);
                                    sidebar.currentIndex = i;
                                    sidebar.folderSelected(acid, path);
                                    sidebar.saveSelection(acid, path);
                                    Pelliper.ThreadModel.accountId = acid;
                                    Pelliper.ThreadModel.folderPath = path;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        MessageListView {
            id: messageList
            Controls.SplitView.preferredWidth: Kirigami.Units.gridUnit * 30
            Controls.SplitView.minimumWidth: Kirigami.Units.gridUnit * 20

            onMessageSelected: function (accountId, folderPath, uid, subject, sender, date, isRead, isStarred) {
                selectedAccountId = accountId;
                selectedFolderPath = folderPath;
                selectedUid = uid;

                messageView.subject = subject || "";
                messageView.sender = sender || "";
                messageView.messageDate = date || 0;
                messageView.accountId = accountId;
                messageView.folderPath = folderPath;
                messageView.isRead = isRead;
                messageView.isStarred = isStarred;

                messageView.bodyHtml = "";
                messageView.currentUid = uid;
                Pelliper.DaemonClient.loadBody(accountId, folderPath, uid);

                if (!isRead) {
                    messageView.isRead = true;
                    Pelliper.DaemonClient.setMessageRead(accountId, folderPath, uid, true);
                }
            }

            onReplyRequested: function (accountId, folderPath, uid, subject, sender, date, isRead, isStarred) {
                var page = composePageComponent.createObject(applicationWindow())
                page.openReply(accountId, folderPath, uid, subject, sender, date, "")
                applicationWindow().pageStack.layers.push(page)
            }

            onForwardRequested: function (accountId, folderPath, uid, subject, sender, date, isRead, isStarred) {
                var page = composePageComponent.createObject(applicationWindow())
                page.openForward(accountId, folderPath, uid, subject, sender, date, "")
                applicationWindow().pageStack.layers.push(page)
            }
        }

        MessageView {
            id: messageView
            Controls.SplitView.fillWidth: true
            Controls.SplitView.minimumWidth: Kirigami.Units.gridUnit * 25

            onReplyRequested: function (accountId, folderPath, uid, subject, sender, date, bodyHtml) {
                var page = composePageComponent.createObject(applicationWindow())
                page.openReply(accountId, folderPath, uid, subject, sender, date, bodyHtml)
                applicationWindow().pageStack.layers.push(page)
            }

            onForwardRequested: function (accountId, folderPath, uid, subject, sender, date, bodyHtml) {
                var page = composePageComponent.createObject(applicationWindow())
                page.openForward(accountId, folderPath, uid, subject, sender, date, bodyHtml)
                applicationWindow().pageStack.layers.push(page)
            }
        }
    }
}
