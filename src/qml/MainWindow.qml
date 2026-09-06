import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {

    property int selectedAccountId: -1
    property string selectedFolderPath: ""
    property int selectedUid: -1

    Controls.SplitView {
        id: splitView
        anchors.fill: parent
        handle: Kirigami.Separator {}

        FolderSidebar {
            id: sidebar
            Controls.SplitView.preferredWidth: Kirigami.Units.gridUnit * 12

            onFolderSelected: function(accountId, folderPath) {
                Pelliper.MessageModel.accountId = accountId
                Pelliper.MessageModel.folderPath = folderPath
                Pelliper.DaemonClient.setIdleFolder(accountId, folderPath)
            }

            Component.onCompleted: {
                // Auto-select saved folder or INBOX after model loads
                if (Pelliper.FolderModel.count > 0) {
                    if (sidebar.savedAccountId >= 0 && sidebar.savedFolderPath !== "") {
                        sidebar.restoreSelection()
                    } else {
                        // Default to INBOX
                        var roles = Pelliper.FolderModel.roleNames
                        var pathRole = 0, acidRole = 0
                        for (var key in roles) {
                            if (roles[key] === "path") pathRole = Number(key)
                            if (roles[key] === "accountId") acidRole = Number(key)
                        }
                        for (var i = 0; i < Pelliper.FolderModel.count; i++) {
                            var idx = Pelliper.FolderModel.index(i, 0)
                            var path = Pelliper.FolderModel.data(idx, pathRole)
                            if (path === "INBOX") {
                                var acid = Pelliper.FolderModel.data(idx, acidRole)
                                sidebar.currentIndex = i
                                sidebar.folderSelected(acid, path)
                                sidebar.saveSelection(acid, path)
                                break
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

            onMessageSelected: function(accountId, folderPath, uid, subject, sender, date) {
                selectedAccountId = accountId
                selectedFolderPath = folderPath
                selectedUid = uid

                messageView.subject = subject || ""
                messageView.sender = sender || ""
                messageView.messageDate = date || 0

                // Reset body and fetch
                messageView.bodyHtml = ""
                messageView.currentUid = uid
                Pelliper.DaemonClient.loadBody(accountId, folderPath, uid)
            }
        }

        MessageView {
            id: messageView
            Controls.SplitView.fillWidth: true
            Controls.SplitView.minimumWidth: Kirigami.Units.gridUnit * 25
        }
    }
}
