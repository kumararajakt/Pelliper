import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root
    title: "Compose"

    property string to: ""
    property string subject: ""
    property string body: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing

        Controls.TextField {
            placeholderText: "To"
            text: root.to
            Layout.fillWidth: true
        }

        Controls.TextField {
            placeholderText: "Subject"
            text: root.subject
            Layout.fillWidth: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Controls.TextArea {
                placeholderText: "Write your message..."
                text: root.body
                wrapMode: Controls.TextArea.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Controls.Button {
                text: "Attach File"
                icon.name: "mail-attachment"
                onClicked: {
                    // TODO: file picker
                }
            }

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: "Discard"
                onClicked: {
                    // TODO: discard
                }
            }

            Controls.Button {
                text: "Send"
                icon.name: "mail-send"
                highlighted: true
                onClicked: {
                    // TODO: send
                }
            }
        }
    }
}
