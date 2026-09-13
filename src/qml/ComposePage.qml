import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
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
    property string replyFolderPath: ""
    property int replyUid: 0
    property var attachments: []

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
        root.replyFolderPath = ""
        root.replyUid = 0
        root.attachments = []
    }

    function cleanSubject(subject) {
        var s = subject || ""
        s = s.replace(/^\s*(re|fwd|fw|aw|sv|antw|re\[[0-9]+\])\s*:\s*/i, "")
        return s
    }

    function formatDate(epochSeconds) {
        if (!epochSeconds) return ""
        var d = new Date(epochSeconds * 1000)
        return Qt.formatDateTime(d, "ddd MMM d, yyyy 'at' hh:mm")
    }

    function buildQuote(sender, date, bodyHtml) {
        var sb = []
        sb.push("<p>On " + root.formatDate(date) + ", " + escapedSender(sender) + " wrote:</p>")
        sb.push("<blockquote>" + (bodyHtml || "") + "</blockquote>")
        return sb.join("\n")
    }

    function escapedSender(sender) {
        return String(sender).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function openReply(accountId, folderPath, uid, subject, sender, date, bodyHtml) {
        root.accountId = accountId
        root.to = sender || ""
        root.cc = ""
        root.subject = "Re: " + root.cleanSubject(subject)
        root.body = root.buildQuote(sender, date, bodyHtml)
        root.replyFolderPath = folderPath || ""
        root.replyUid = uid
    }

    function openForward(accountId, folderPath, uid, subject, sender, date, bodyHtml) {
        root.accountId = accountId
        root.to = ""
        root.cc = ""
        root.subject = "Fwd: " + root.cleanSubject(subject)
        var sb = []
        sb.push("<div>---------- Forwarded message ----------</div>")
        sb.push("<div>From: " + root.escapedSender(sender) + "</div>")
        if (root.formatDate(date)) sb.push("<div>Date: " + root.formatDate(date) + "</div>")
        sb.push("<div>Subject: " + String(subject).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") + "</div>")
        sb.push("<blockquote>" + (bodyHtml || "") + "</blockquote>")
        root.body = sb.join("\n")
        root.replyFolderPath = folderPath || ""
        root.replyUid = uid
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
            onTextChanged: {
                var parts = text.split(",")
                var last = parts[parts.length - 1].trim()
                if (last.length >= 2) {
                    Pelliper.DaemonClient.searchAddresses(last)
                } else {
                    addrPopup.close()
                }
            }
        }

        Controls.Popup {
            id: addrPopup
            y: toField.y + toField.height
            width: toField.width
            visible: addrModel.count > 0

            ListView {
                anchors.fill: parent
                model: ListModel { id: addrModel }
                delegate: Controls.ItemDelegate {
                    width: addrPopup.width
                    contentItem: RowLayout {
                        Controls.Label {
                            text: model.display
                            font.weight: Font.Bold
                        }
                        Controls.Label {
                            text: model.email
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                    onClicked: {
                        var parts = toField.text.split(",")
                        parts[parts.length - 1] = " " + model.email
                        toField.text = parts.join(",") + ", "
                        addrPopup.close()
                    }
                }
            }
        }

        Connections {
            target: Pelliper.DaemonClient
            function onAddressResults(json) {
                addrModel.clear()
                try {
                    var arr = JSON.parse(json)
                    for (var i = 0; i < arr.length; i++) {
                        addrModel.append({
                            email: arr[i].email,
                            display: arr[i].name.length > 0 ? arr[i].name : arr[i].email
                        })
                    }
                } catch (e) {}
            }
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

        // Attachment list
        Repeater {
            model: root.attachments
            delegate: RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "mail-attachment"
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
                Controls.Label {
                    text: modelData.name
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Controls.Label {
                    text: modelData.sizeLabel
                    color: Kirigami.Theme.disabledTextColor
                }
                Controls.ToolButton {
                    icon.name: "list-remove"
                    onClicked: {
                        var arr = root.attachments.slice()
                        arr.splice(index, 1)
                        root.attachments = arr
                    }
                }
            }
        }

        FileDialog {
            id: attachDialog
            title: qsTr("Attach Files")
            fileMode: FileDialog.OpenFiles
            nameFilters: [qsTr("All Files (*)")]
            onAccepted: {
                var arr = root.attachments.slice()
                for (var i = 0; i < selectedFiles.length; i++) {
                    var url = selectedFiles[i]
                    var path = url.toString()
                    if (path.indexOf("file://") === 0) path = path.substring(7)
                    var name = path.split("/").pop()
                    var size = 0
                    // size is unknown from FileDialog, pass 0
                    arr.push({ path: path, name: name, size: 0, sizeLabel: "" })
                }
                root.attachments = arr
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Controls.Button {
                text: qsTr("Attach File")
                icon.name: "mail-attachment"
                onClicked: attachDialog.open()
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
                    var paths = []
                    for (var i = 0; i < root.attachments.length; i++) {
                        paths.push(root.attachments[i].path)
                    }
                    Pelliper.DaemonClient.sendEmail(
                        root.accountId,
                        toField.text,
                        ccField.text,
                        subjectField.text,
                        bodyField.text,
                        root.replyFolderPath,
                        root.replyUid,
                        JSON.stringify(paths)
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