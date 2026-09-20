pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtCore
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper

Controls.ScrollView {
    id: sidebarRoot

    property int savedAccountId: Number(settings.value("lastAccountId", -1))
    property string savedFolderPath: settings.value("lastFolderPath", "")
    property bool unifiedMode: Number(settings.value("unifiedMode", 0)) === 1
    readonly property bool firstRun: settings.value("expandedKeys", "") === ""

    property var expandedKeys: {
        const raw = settings.value("expandedKeys", "");
        return raw === "" ? null : new Set(JSON.parse(raw));
    }

    signal folderSelected(int accountId, string folderPath)

    Settings {
        id: settings
        category: "folder"
    }

    // Debounced write so rapid expand/collapse doesn't hit disk every time
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: settings.setValue("expandedKeys", JSON.stringify([...sidebarRoot.expandedKeys]))
    }

    function saveSelection(accountId, folderPath) {
        savedAccountId = accountId;
        savedFolderPath = folderPath;
        settings.setValue("lastAccountId", accountId);
        settings.setValue("lastFolderPath", folderPath);
    }

    function saveFolderMode(mode) {
        unifiedMode = (mode === 1);
        settings.setValue("unifiedMode", mode);
    }

    function restoreSelection() {
        if (savedAccountId >= 0 && savedFolderPath !== "") {
            folderSelected(savedAccountId, savedFolderPath);
        }
    }

    function keyAt(row) {
        return treeView.model.stateKey(treeView.index(row, 0));
    }

    property var autoExpanded: new Set()

    function markExpanded(row, isExpanded) {
        if (!expandedKeys)
            expandedKeys = new Set();

        const k = keyAt(row);
        if (isExpanded)
            expandedKeys.add(k);
        else
            expandedKeys.delete(k);
        saveTimer.restart();
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

        clip: true

        selectionBehavior: TreeView.SelectionBehavior.SelectRows

        // Keep the saved set up to date (Qt 6.6+)
        onExpanded: (row, depth) => sidebarRoot.markExpanded(row, true)
        onCollapsed: (row, recursively) => sidebarRoot.markExpanded(row, false)

        delegate: FolderSidebarDelegate {
            // Single source of truth: the model's stateKey handles the
            // unified-mode aggregated rows (role:...) that would otherwise
            // collide. Must match keyAt() in the sidebar root.
            readonly property string stateKey: treeView.model.stateKey(treeView.index(row, 0))

            onFolderSelected: function (accountId, folderPath) {
                sidebarRoot.folderSelected(accountId, folderPath);
            }
            onSaveSelection: function (accountId, folderPath) {
                sidebarRoot.saveSelection(accountId, folderPath);
            }

            Component.onCompleted: {
                if (!hasChildren || expanded)
                    return;

                if (sidebarRoot.firstRun) {
                    // Default behaviour: expand each account header once
                    if (isAccountHeader && !sidebarRoot.autoExpanded.has(stateKey)) {
                        sidebarRoot.autoExpanded.add(stateKey);
                        treeView.expand(row);
                    }
                } else if (sidebarRoot.expandedKeys.has(stateKey)) {
                    treeView.expand(row);
                }
            }
        }
    }
}
