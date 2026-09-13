import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtWebEngine
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: messageView

    signal replyRequested(int accountId, string folderPath, int uid,
                          string subject, string sender, real date, string bodyHtml)
    signal forwardRequested(int accountId, string folderPath, int uid,
                            string subject, string sender, real date, string bodyHtml)

    property string bodyHtml: ""
    property string subject: ""
    property string sender: ""
    property real messageDate: 0
    property int currentUid: -1
    property int accountId: -1
    property string folderPath: ""
    property bool isRead: false
    property bool isStarred: false
    property var attachments: []
    property string saveFileSrc: ""

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.largeSpacing * 4)
        visible: currentUid < 0
        text: qsTr("No Message Selected")
        explanation: qsTr("Select a message from the list to read it.")
    }

    Controls.BusyIndicator {
        anchors.centerIn: parent
        visible: currentUid >= 0 && bodyHtml === ""
    }

    footer: Controls.ToolBar {
        id: attachmentFooter
        visible: messageView.attachments.length > 0
        width: messageView.width

        contentItem: ListView {
            id: attachmentList
            orientation: Qt.Horizontal
            spacing: Kirigami.Units.smallSpacing
            clip: true
            leftMargin: Kirigami.Units.smallSpacing
            rightMargin: Kirigami.Units.smallSpacing
            model: messageView.attachments

            delegate: Controls.Button {
                id: attachmentButton
                width: Math.max(implicitWidth, Kirigami.Units.gridUnit * 8)
                height: attachmentList.height

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: messageView.attachmentIcon(modelData.content_type)
                        Layout.preferredWidth: Kirigami.Units.iconSizeSmallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizeSmallMedium
                    }

                    Controls.Label {
                        text: modelData.name || qsTr("(unnamed)")
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                    }

                    Kirigami.Icon {
                        source: "pan-down-symbolic"
                        Layout.preferredWidth: Kirigami.Units.iconSizeSmall
                        Layout.preferredHeight: Kirigami.Units.iconSizeSmall
                    }
                }

                Controls.ToolTip.text: modelData.name + " (" + messageView.formatFileSize(modelData.size) + ")"
                Controls.ToolTip.visible: hovered

                onClicked: attachmentFooter.openMenu(index, attachmentButton)
            }
        }
    }

    Controls.Menu {
        id: attachmentMenu
        property int attachmentIndex: -1

        Controls.MenuItem {
            text: qsTr("Open")
            icon.name: "document-open"
            onTriggered: {
                var a = messageView.attachments[attachmentMenu.attachmentIndex]
                if (a) Qt.openUrlExternally("file://" + a.file_path)
            }
        }
        Controls.MenuItem {
            text: qsTr("Save As…")
            icon.name: "document-save"
            onTriggered: {
                var a = messageView.attachments[attachmentMenu.attachmentIndex]
                if (!a) return
                messageView.saveFileSrc = a.file_path
                saveDialog.selectedFile = ""
                saveDialog.visible = true
            }
        }
    }

    function openMenu(index, item) {
        attachmentMenu.attachmentIndex = index
        attachmentMenu.popup(item, 0, item.height)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        visible: currentUid >= 0 && bodyHtml !== ""
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: messageView.subject || qsTr("(no subject)")
                font.pointSize: 16
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Controls.Label {
                    text: messageView.sender
                    font.pointSize: 11
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Controls.Label {
                    text: {
                        if (messageView.messageDate <= 0) return ""
                        var d = new Date(messageView.messageDate * 1000)
                        return Qt.formatDateTime(d, "MMM d, yyyy HH:mm")
                    }
                    font.pointSize: 10
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Controls.ToolButton {
                    icon.name: "mail-reply-sender"
                    Controls.ToolTip.text: qsTr("Reply")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        messageView.replyRequested(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, messageView.subject,
                            messageView.sender, messageView.messageDate,
                            messageView.bodyHtml)
                    }
                }
                Controls.ToolButton {
                    icon.name: "mail-forward"
                    Controls.ToolTip.text: qsTr("Forward")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        messageView.forwardRequested(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, messageView.subject,
                            messageView.sender, messageView.messageDate,
                            messageView.bodyHtml)
                    }
                }
                Controls.ToolButton {
                    icon.name: messageView.isStarred ? "starred-symbolic" : "non-starred-symbolic"
                    Controls.ToolTip.text: messageView.isStarred ? qsTr("Unstar") : qsTr("Star")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        messageView.isStarred = !messageView.isStarred
                        Pelliper.DaemonClient.setMessageStarred(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, messageView.isStarred)
                    }
                }
                Controls.ToolButton {
                    icon.name: messageView.isRead ? "mail-read" : "mail-unread"
                    Controls.ToolTip.text: messageView.isRead ? qsTr("Mark unread") : qsTr("Mark read")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        messageView.isRead = !messageView.isRead
                        Pelliper.DaemonClient.setMessageRead(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, messageView.isRead)
                    }
                }
                Controls.ToolButton {
                    icon.name: "user-trash"
                    Controls.ToolTip.text: qsTr("Move to Trash")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        Pelliper.DaemonClient.moveMessage(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, "")
                        messageView.clearMessage()
                    }
                }
                Controls.ToolButton {
                    icon.name: "folder-download"
                    Controls.ToolTip.text: qsTr("Archive")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        Pelliper.DaemonClient.moveMessage(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, "Archive")
                        messageView.clearMessage()
                    }
                }
                Controls.ToolButton {
                    icon.name: "mail-flag"
                    Controls.ToolTip.text: qsTr("Mark as Spam")
                    Controls.ToolTip.visible: hovered
                    onClicked: {
                        Pelliper.DaemonClient.moveMessage(
                            messageView.accountId, messageView.folderPath,
                            messageView.currentUid, "Junk")
                        messageView.clearMessage()
                    }
                }

                Item { Layout.fillWidth: true }

                Controls.ToolButton {
                    icon.name: "document-print"
                    Controls.ToolTip.text: qsTr("Print")
                    Controls.ToolTip.visible: hovered
                    onClicked: printDialog.open()
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
        }

        WebEngineView {
            id: webView
            Layout.fillWidth: true
            Layout.fillHeight: true

            settings.javascriptEnabled: false
            settings.localContentCanAccessRemoteUrls: false
            settings.localContentCanAccessFileUrls: false
        }
    }

    onBodyHtmlChanged: loadBodyToView()
    onCurrentUidChanged: {
        loadBodyToView()
        requestAttachments()
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Save Attachment")
        fileMode: FileDialog.SaveFile
        currentFile: messageView.saveFileSrc ? "file://" + messageView.saveFileSrc : ""

        onAccepted: {
            var dest = saveDialog.selectedFile.toString()
            if (dest.indexOf("file://") === 0) {
                dest = dest.substring(7)
            }
            if (dest.length > 0 && messageView.saveFileSrc.length > 0) {
                Pelliper.DaemonClient.copyFile(messageView.saveFileSrc, dest)
            }
        }
    }

    Controls.Dialog {
        id: printDialog
        title: qsTr("Print Message")
        parent: ApplicationWindow.overlay
        modal: true
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel

        Controls.Label {
            text: qsTr("Print this message?")
        }

        onAccepted: webView.print()
    }

    function clearMessage() {
        currentUid = -1
        bodyHtml = ""
        subject = ""
        sender = ""
        messageDate = 0
        isRead = false
        isStarred = false
        attachments = []
    }

    function requestAttachments() {
        if (currentUid < 0) return
        Pelliper.DaemonClient.listAttachments(
            messageView.accountId, messageView.folderPath, messageView.currentUid)
    }

    function attachmentIcon(contentType) {
        var t = (contentType || "").toLowerCase()
        if (t.indexOf("image/") === 0) return "image-x-generic"
        if (t.indexOf("video/") === 0) return "video-x-generic"
        if (t.indexOf("audio/") === 0) return "audio-x-generic"
        if (t.indexOf("text/") === 0) return "text-x-generic"
        if (t === "application/pdf") return "application-pdf"
        if (t === "application/zip") return "package-x-generic"
        if (t.indexOf("application/vnd.openxmlformats-officedocument") === 0) return "x-office-document"
        if (t.indexOf("application/") === 0) return "package-x-generic"
        return "unknown"
    }

    function formatFileSize(size) {
        if (!size) return ""
        if (size < 1024) return size + " B"
        if (size < 1024 * 1024) return (size / 1024).toFixed(1) + " KB"
        return (size / (1024 * 1024)).toFixed(1) + " MB"
    }

    function loadBodyToView() {
        if (currentUid < 0 || bodyHtml === "") return
        var fullHtml = "<!DOCTYPE html>"
            + "<html><head><meta charset=\"utf-8\">"
            + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
            + "<style>"
            + "body { font-family: sans-serif; font-size: 14px; margin: 8px; color: " + Kirigami.Theme.textColor + "; }"
            + "a { color: " + Kirigami.Theme.linkColor + "; }"
            + "img { max-width: 100%; height: auto; }"
            + "pre, code { font-family: monospace; background: " + Kirigami.Theme.backgroundColor + "; padding: 2px 4px; border-radius: 3px; }"
            + "blockquote { border-left: 3px solid " + Kirigami.Theme.disabledTextColor + "; margin-left: 0; padding-left: 12px; color: " + Kirigami.Theme.disabledTextColor + "; }"
            + "</style></head><body>"
            + bodyHtml
            + "</body></html>"
        webView.loadHtml(fullHtml)
    }

    Connections {
        target: Pelliper.DaemonClient
        function onBodyLoaded(uid, html) {
            if (uid === messageView.currentUid) {
                messageView.bodyHtml = html
                messageView.requestAttachments()
            }
        }
        function onAttachmentsLoaded(uid, json) {
            if (uid !== messageView.currentUid) return
            try {
                messageView.attachments = JSON.parse(json)
            } catch (e) {
                messageView.attachments = []
            }
        }
    }
}
