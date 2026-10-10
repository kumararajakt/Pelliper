import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper
import org.kde.kirigamiaddons.components as KAComponent

Controls.ItemDelegate {
    id: messageListDelegate

    required property ListView listView
    required property QtObject listRoot

    // Model roles
    required property int accountId
    required property string folderPath
    required property int uid
    required property string subject
    required property string sender
    required property real date
    required property bool isRead
    required property bool isStarred
    required property bool hasAttachments
    required property string preview
    required property int replyCount
    required property int unreadCount
    required property int index

    contentItem: RowLayout {
        // Image {
        //     Layout.preferredWidth: 20
        //     Layout.preferredHeight: 20
        //     source: listRoot.extractEmail(messageListDelegate.sender).length > 0 ? Pelliper.DaemonClient.gravatarUrl(listRoot.extractEmail(messageListDelegate.sender), 40) : messageListDelegate.sender
        //     Layout.rightMargin: Kirigami.Units.smallSpacing
        //     fillMode: Image.PreserveAspectCrop
        //     layer.enabled: true
        //     layer.effect: null
        // }

        KAComponent.Avatar {
            source: listRoot.extractEmail(messageListDelegate.sender).length > 0 ? Pelliper.DaemonClient.gravatarUrl(listRoot.extractEmail(messageListDelegate.sender), 40) : messageListDelegate.sender

            Component.onCompleted: {
                console.log('kumar', messageListDelegate.sender, listRoot.extractEmail(messageListDelegate.sender), Pelliper.DaemonClient.gravatarUrl(listRoot.extractEmail(messageListDelegate.sender), 40))
            }
        }

        Controls.Label {
            text: messageListDelegate.sender
            font.pointSize: 10
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Controls.Label {
            text: {
                if (messageListDelegate.date <= 0)
                    return "";
                var d = new Date(messageListDelegate.date * 1000);
                var now = new Date();
                if (d.toDateString() === now.toDateString()) {
                    return Qt.formatTime(d, "HH:mm");
                }
                return Qt.formatDate(d, "MMM d");
            }
            font.pointSize: 10
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
