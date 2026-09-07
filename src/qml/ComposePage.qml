import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: root
    title: "Compose"

    property int accountId: -1
    property string to: ""
    property string cc: ""
    property string subject: ""
    property string body: ""
    property bool sending: false

    readonly property string accountName: {
        if (root.accountId < 0) return ""
        return Pelliper.AccountModel.accountLabelForId(root.accountId)
    }

    function openTo(accountId, to, subject, body) {
        root.accountId = accountId
        root.to = to || ""
        root.cc = ""
        root.subject = subject || ""
        root.body = body || ""
    }

    Controls.BusyIndicator {
        anchors.centerIn: parent
        visible: root.sending
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        visible: !root.sending

        Controls.Label {
            text: qsTr("From: %1").arg(accountName)
            visible: accountName.length > 0
        }

        Controls.TextField {
            id: toField
            placeholderText: qsTr("To (comma separated)")
            text: root.to
            Layout.fillWidth: true
        }

        Controls.TextField {
            id: ccField
            placeholderText: qsTr("Cc (optional)")
            text: root.cc
            Layout.fillWidth: true
        }

        Controls.TextField {
            id: subjectField
            placeholderText: qsTr("Subject")
            text: root.subject
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.ToolButton {
                id: boldBtn
                text: "B"
                font.weight: Font.Bold
                checkable: true
                checked: bodyField.cursorSelection.font.bold
                onToggled: bodyField.cursorSelection.font.bold = checked
                Controls.ToolTip.text: qsTr("Bold")
                Controls.ToolTip.visible: hovered
            }
            Controls.ToolButton {
                id: italicBtn
                text: "I"
                font.italic: true
                checkable: true
                checked: bodyField.cursorSelection.font.italic
                onToggled: bodyField.cursorSelection.font.italic = checked
                Controls.ToolTip.text: qsTr("Italic")
                Controls.ToolTip.visible: hovered
            }
            Controls.ToolButton {
                id: underlineBtn
                text: "U"
                font.underline: true
                checkable: true
                checked: bodyField.cursorSelection.font.underline
                onToggled: bodyField.cursorSelection.font.underline = checked
                Controls.ToolTip.text: qsTr("Underline")
                Controls.ToolTip.visible: hovered
            }
            Controls.ToolButton {
                id: strikeoutBtn
                text: "S"
                font.strikeout: true
                checkable: true
                checked: bodyField.cursorSelection.font.strikeout
                onToggled: bodyField.cursorSelection.font.strikeout = checked
                Controls.ToolTip.text: qsTr("Strikethrough")
                Controls.ToolTip.visible: hovered
            }

            Item { Layout.fillWidth: true }

            Controls.ToolButton {
                icon.name: "format-indent-more"
                checkable: true
                checked: bodyField.cursorSelection.alignment === Qt.AlignRight
                onToggled: bodyField.cursorSelection.alignment = checked
                    ? Qt.AlignRight
                    : Qt.AlignLeft
                Controls.ToolTip.text: qsTr("Right align")
                Controls.ToolTip.visible: hovered
            }
        }

        Shortcut {
            sequence: "Ctrl+B"
            enabled: bodyField.activeFocus
            onActivated: boldBtn.toggle()
        }
        Shortcut {
            sequence: "Ctrl+I"
            enabled: bodyField.activeFocus
            onActivated: italicBtn.toggle()
        }
        Shortcut {
            sequence: "Ctrl+U"
            enabled: bodyField.activeFocus
            onActivated: underlineBtn.toggle()
        }
        Shortcut {
            sequence: "Ctrl+S"
            enabled: bodyField.activeFocus
            onActivated: strikeoutBtn.toggle()
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Controls.TextArea {
                id: bodyField
                placeholderText: qsTr("Write your message...")
                text: root.body
                wrapMode: Text.Wrap
                textFormat: Qt.AutoText
                selectByMouse: true
                persistentSelection: true
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Controls.Button {
                text: "Attach File"
                icon.name: "mail-attachment"
                enabled: false
                onClicked: {
                    // TODO: file picker
                }
            }

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: "Discard"
                onClicked: applicationWindow().pageStack.layers.pop()
            }

            Controls.Button {
                text: "Send"
                icon.name: "mail-send"
                highlighted: true
                enabled: toField.text.trim().length > 0 && !root.sending
                onClicked: {
                    root.sending = true
                    Pelliper.DaemonClient.sendEmail(
                        root.accountId,
                        toField.text,
                        ccField.text,
                        subjectField.text,
                        bodyField.text
                    )
                }
            }
        }
    }

    Connections {
        target: Pelliper.DaemonClient
        function onEmailSent(error) {
            root.sending = false
            if (error.length === 0) {
                applicationWindow().pageStack.layers.pop()
                applicationWindow().showPassiveNotification(qsTr("Email sent"))
            } else {
                applicationWindow().showPassiveNotification(qsTr("Failed to send: %1").arg(error))
            }
        }
    }
}