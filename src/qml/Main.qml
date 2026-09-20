import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.ApplicationWindow {
    id: root

    width: Kirigami.Units.gridUnit * 90
    height: Kirigami.Units.gridUnit * 55
    visible: true

    title: "Pelliper"

    PelliperMenuBar {
        id: appMenuBar
        onFolderViewModeChanged: function (mode) {
            var page = root.pageStack.currentItem;
            if (page && page.setFolderMode) {
                page.setFolderMode(mode);
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            var page = root.pageStack.currentItem;
            if (page && page.openCompose)
                page.openCompose();
        }
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: {
            var page = root.pageStack.currentItem;
            if (page && page.refreshMessages)
                page.refreshMessages();
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: {
            root.pageStack.layers.push(searchPageComponent);
        }
    }

    Component {
        id: settingsPageComponent
        SettingsPage {}
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
                    onClicked: root.pageStack.layers.push(addAccountComponent)
                }
            }
        }
    }

    Component {
        id: mainWindowComponent
        MainWindow {}
    }

    Component {
        id: addAccountComponent
        AddAccountPage {}
    }

    readonly property var accountModel: Pelliper.AccountModel

    Component.onCompleted: {
        if (Pelliper.AccountModel.count > 0) {
            root.pageStack.push(mainWindowComponent);
        } else {
            root.pageStack.push(emptyStateComponent);
        }
    }

    onClosing: function (close) {
        close.accepted = false;
        root.hide();
    }

    function openMessageFromExternal(accountId, folderPathString, uid, subject, sender, date) {
        if (Pelliper.AccountModel.count <= 0)
            return;
        var currentPage = root.pageStack.currentItem;
        if (!currentPage || typeof currentPage.openMessageInView !== "function") {
            root.pageStack.clear();
            root.pageStack.push(mainWindowComponent);
        }
        if (root.pageStack.layers.depth > 1) {
            root.pageStack.layers.clear();
        }
        root.pageStack.currentItem.openMessageInView(accountId, folderPathString, uid, subject, sender, date);
        root.show();
        root.raise();
        root.requestActivate();
    }

    Connections {
        target: Pelliper.TrayNotifier
        function onOpenMessage(accountId, folderPathString, uid, subject, sender, date) {
            root.openMessageFromExternal(accountId, folderPathString, uid, subject, sender, date);
        }
        function onShowWindow() {
            root.show();
            root.raise();
            root.requestActivate();
        }
    }

    Connections {
        target: Pelliper.DaemonClient
        function onAccountAdded(email) {
            Pelliper.AccountModel.refresh();
            if (Pelliper.AccountModel.count > 0) {
                root.pageStack.clear();
                root.pageStack.push(mainWindowComponent);
            }
        }
    }
}
