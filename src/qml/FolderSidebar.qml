import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtCore
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper

Controls.ScrollView {
    id: sidebarRoot

    property int savedAccountId: Number(settings.value("lastAccountId", -1))
    property string savedFolderPath: settings.value("lastFolderPath", "")
    property bool unifiedMode: false

    signal folderSelected(int accountId, string folderPath)

    Settings {
        id: settings
        category: "folder"
    }

    function saveSelection(accountId, folderPath) {
        settings.setValue("lastAccountId", accountId)
        settings.setValue("lastFolderPath", folderPath)
    }

    function restoreSelection() {
        if (savedAccountId >= 0 && savedFolderPath !== "") {
            folderSelected(savedAccountId, savedFolderPath)
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.largeSpacing * 4)
        visible: Pelliper.FolderModel.count === 0
        text: qsTr("No Folders Found")
        explanation: qsTr("Add an account and sync to see your folders here.")
    }

    TreeView {
        id: treeView
        anchors.fill: parent
        model: Pelliper.FolderModel

        // Let the tree view fill available width
        clip: true

        // Selection
        selectionBehavior: Controls.SelectionView.SelectCurrentRow

        // Delegate for each tree row
        delegate: FolderSidebarDelegate {
            onFolderSelected: function (accountId, folderPath) {
                sidebarRoot.folderSelected(accountId, folderPath)
            }
            onSaveSelection: function (accountId, folderPath) {
                sidebarRoot.saveSelection(accountId, folderPath)
            }
        }
    }

    Connections {
        target: Pelliper.FolderModel
        function onNeedsExpansion(paths) {
            Qt.callLater(function() {
                var roles = Pelliper.FolderModel.roleNames
                var pathRole = 0, acidRole = 0, headerRole = 0
                for (var key in roles) {
                    if (roles[key] === "path") pathRole = Number(key)
                    if (roles[key] === "accountId") acidRole = Number(key)
                    if (roles[key] === "isAccountHeader") headerRole = Number(key)
                }
                for (var i = 0; i < treeView.rows; i++) {
                    var idx = Pelliper.FolderModel.index(i, 0)
                    var isHeader = Pelliper.FolderModel.data(idx, headerRole)
                    var expandKey
                    if (isHeader) {
                        expandKey = "account:" + Pelliper.FolderModel.data(idx, acidRole)
                    } else {
                        expandKey = Pelliper.FolderModel.data(idx, pathRole)
                    }
                    if (paths.indexOf(expandKey) >= 0)
                        treeView.expand(i)
                }
            })
        }
    }

    Component.onCompleted: {
        if (Pelliper.FolderModel.count > 0) {
            treeView.expand(0)
            // Track the first account as expanded
            var roles = Pelliper.FolderModel.roleNames
            var acidRole = 0
            for (var key in roles) {
                if (roles[key] === "accountId") {
                    acidRole = Number(key)
                    break
                }
            }
            var idx = Pelliper.FolderModel.index(0, 0)
            var acid = Pelliper.FolderModel.data(idx, acidRole)
            Pelliper.FolderModel.setPathExpanded("account:" + acid, true)
        }
    }
}
