import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

ColumnLayout {

    ListView {
        id: messageList
        Layout.fillHeight: true
        Layout.fillWidth: true


        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)
            visible: messageList.count === 0
            text: qsTr("No Messages Found")
        }

        model: []
    }
}
