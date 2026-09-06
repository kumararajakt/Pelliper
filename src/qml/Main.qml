import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    width: 1200
    height: 800
    visible: true

    title: "Pelliper"

    Component {
        id: emptyStateComponent
        Kirigami.Page {
            title: "Pelliper"
            ColumnLayout {
                anchors.centerIn: parent
                Controls.Button {
                    text: "Add Account"
                    icon.name: "list-add-user"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    onClicked: root.pageStack.layers.push(addAccountComponent)
                }
            }
        }
    }

    Component {
        id: threePaneComponent
        ThreePaneView {}
    }

    Component {
        id: addAccountComponent
        AddAccountPage {}
    }

    Component.onCompleted: {
        // TODO: Check if accounts exist via D-Bus
        root.pageStack.push(emptyStateComponent)
    }
}
