import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: viewPane

    property double messageId: 0
    property string senderName: ""
    property string subject: ""
    property string bodyText: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        visible: viewPane.messageId > 0
        spacing: Kirigami.Units.mediumSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            text: viewPane.subject.length > 0 ? viewPane.subject : i18n("(No Subject)")
            level: 2
            wrapMode: Text.WordWrap
        }

        Controls.Label {
            Layout.fillWidth: true
            text: i18n("From: %1", viewPane.senderName)
            opacity: 0.8
        }

        Kirigami.Separator { Layout.fillWidth: true }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Controls.TextArea {
                readOnly: true
                wrapMode: TextEdit.Wrap
                text: viewPane.bodyText.length > 0 ? viewPane.bodyText : i18n("Loading message body…")
                background: null
            }
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        visible: viewPane.messageId <= 0
        width: parent.width - Kirigami.Units.largeSpacing * 2
        text: i18n("Select a conversation to read")
        icon.name: "mail-read"
    }
}
