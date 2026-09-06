import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.ApplicationWindow {
    id: root

    width: 1200
    height: 800
    visible: true

    title: "Pelliper"


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
            root.pageStack.push(mainWindowComponent)
        } else {
            root.pageStack.push(emptyStateComponent)
        }
    }

    Connections {
        target: Pelliper.DaemonClient
        function onAccountAdded(email) {
            Pelliper.AccountModel.refresh()
            if (Pelliper.AccountModel.count > 0) {
                root.pageStack.clear()
                root.pageStack.push(mainWindowComponent)
            }
        }
    }
}
