import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {

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
            }
        }

        MessageListView {
            Controls.SplitView.preferredWidth: Kirigami.Units.gridUnit * 30
            Controls.SplitView.minimumWidth: Kirigami.Units.gridUnit * 20
        }

        MessageView {
            Controls.SplitView.fillWidth: true
            Controls.SplitView.minimumWidth: Kirigami.Units.gridUnit * 25
        }
    }
}
