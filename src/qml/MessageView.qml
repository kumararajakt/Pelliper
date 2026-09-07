import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtWebEngine
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: messageView

    property string bodyHtml: ""
    property string subject: ""
    property string sender: ""
    property real messageDate: 0
    property int currentUid: -1
    property int accountId: -1
    property string folderPath: ""
    property bool isRead: false
    property bool isStarred: false

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

                Item { Layout.fillWidth: true }
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
    onCurrentUidChanged: loadBodyToView()

    function clearMessage() {
        currentUid = -1
        bodyHtml = ""
        subject = ""
        sender = ""
        messageDate = 0
        isRead = false
        isStarred = false
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
            }
        }
    }
}
