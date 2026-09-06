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

    actions: [
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
                    Pelliper.MessageModel.accountId = accountId;
                    Pelliper.MessageModel.folderPath = folderPath;
                    Pelliper.ThreadModel.accountId = accountId;
                    Pelliper.ThreadModel.folderPath = folderPath;
                    Pelliper.DaemonClient.setIdleFolder(accountId, folderPath);
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

            onMessageSelected: function (accountId, folderPath, uid, subject, sender, date) {
                selectedAccountId = accountId;
                selectedFolderPath = folderPath;
                selectedUid = uid;

                messageView.subject = subject || "";
                messageView.sender = sender || "";
                messageView.messageDate = date || 0;

                messageView.bodyHtml = "";
                messageView.currentUid = uid;
                Pelliper.DaemonClient.loadBody(accountId, folderPath, uid);
            }
        }

        MessageView {
            id: messageView
            Controls.SplitView.fillWidth: true
            Controls.SplitView.minimumWidth: Kirigami.Units.gridUnit * 25
        }
    }
}
