import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: viewPane

    property bool allowRemoteImages: false
    property bool preferPlainText: false
    property double pendingSaveAttId: 0

    signal replyRequested()
    signal replyAllRequested()
    signal forwardRequested()

    function formatBytes(b) {
        if (!b || b <= 0) return ""
        if (b < 1024) return b + " B"
        if (b < 1048576) return Math.round(b / 1024) + " KB"
        return (b / 1048576).toFixed(1) + " MB"
    }

    FileDialog {
        id: saveFileDialog
        fileMode: FileDialog.SaveFile
        onAccepted: messageController.saveAttachmentAs(viewPane.pendingSaveAttId, selectedFile)
    }

    FolderDialog {
        id: saveAllFolderDialog
        onAccepted: messageController.saveAllAttachments(selectedFolder)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        visible: messageController.messageId > 0
        spacing: Kirigami.Units.smallSpacing

        // Action Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.ToolButton {
                icon.name: "mail-reply-sender"
                text: i18n("Reply")
                onClicked: viewPane.replyRequested()
            }
            Controls.ToolButton {
                icon.name: "mail-reply-all"
                text: i18n("Reply All")
                onClicked: viewPane.replyAllRequested()
            }
            Controls.ToolButton {
                icon.name: "mail-forward"
                text: i18n("Forward")
                onClicked: viewPane.forwardRequested()
            }
            Kirigami.Separator { Layout.fillHeight: true }
            Controls.ToolButton {
                icon.name: messageController.starred ? "starred-symbolic" : "non-starred-symbolic"
                text: messageController.starred ? i18n("Starred") : i18n("Star")
                onClicked: {
                    const nextStar = !messageController.starred
                    messageController.toggleStar(messageController.messageId, nextStar)
                    threadListModel.updateFlagsOptimistic(messageController.messageId, messageController.unread, nextStar)
                }
            }
            Controls.ToolButton {
                icon.name: messageController.unread ? "mail-mark-read" : "mail-mark-unread"
                text: messageController.unread ? i18n("Mark Read") : i18n("Mark Unread")
                onClicked: {
                    const markRead = messageController.unread
                    messageController.toggleRead(messageController.messageId, markRead)
                    threadListModel.updateFlagsOptimistic(messageController.messageId, !markRead, messageController.starred)
                }
            }
            Controls.ToolButton {
                icon.name: "folder-archive"
                text: i18n("Archive")
                onClicked: {
                    const id = messageController.messageId
                    messageController.archiveMessage(id)
                    threadListModel.removeMessageOptimistic(id)
                }
            }
            Controls.ToolButton {
                icon.name: "edit-delete"
                text: i18n("Delete")
                onClicked: {
                    const id = messageController.messageId
                    messageController.deleteMessage(id)
                    threadListModel.removeMessageOptimistic(id)
                }
            }
            Item { Layout.fillWidth: true }
            Controls.ToolButton {
                visible: messageController.textHtml.length > 0 && messageController.textPlain.length > 0
                text: viewPane.preferPlainText ? i18n("HTML") : i18n("Plain Text")
                onClicked: viewPane.preferPlainText = !viewPane.preferPlainText
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        Kirigami.Heading {
            Layout.fillWidth: true
            text: messageController.subject.length > 0 ? messageController.subject : i18n("(No Subject)")
            level: 2
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Controls.Label {
                Layout.fillWidth: true
                text: i18n("From: %1 <%2>", messageController.senderName, messageController.senderAddress)
                font.bold: true
                elide: Text.ElideRight
            }
            Controls.Label {
                text: messageController.dateText
                opacity: 0.7
            }
        }

        Controls.Label {
            visible: messageController.toText.length > 0
            Layout.fillWidth: true
            text: i18n("To: %1", messageController.toText)
            opacity: 0.75
            elide: Text.ElideRight
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !viewPane.allowRemoteImages && messageController.textHtml.indexOf("http") >= 0
            type: Kirigami.MessageType.Information
            text: i18n("Remote images are blocked to protect your privacy.")
            actions: [
                Kirigami.Action {
                    text: i18n("Load Remote Images")
                    onTriggered: viewPane.allowRemoteImages = true
                }
            ]
        }

        Flow {
            visible: messageController.attachments.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: messageController.attachments
                delegate: Kirigami.Chip {
                    closable: false
                    icon.name: "mail-attachment"
                    text: {
                        const sz = viewPane.formatBytes(modelData.size_bytes)
                        return sz.length > 0 ? (modelData.filename + " (" + sz + ")") : modelData.filename
                    }
                    onClicked: messageController.openAttachment(modelData.id)

                    Controls.Menu {
                        id: attMenu
                        Controls.MenuItem {
                            text: i18n("Open")
                            icon.name: "document-open"
                            onTriggered: messageController.openAttachment(modelData.id)
                        }
                        Controls.MenuItem {
                            text: i18n("Save As…")
                            icon.name: "document-save-as"
                            onTriggered: {
                                viewPane.pendingSaveAttId = modelData.id
                                saveFileDialog.currentFile = modelData.filename
                                saveFileDialog.open()
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: attMenu.popup()
                    }
                }
            }
            Controls.ToolButton {
                visible: messageController.attachments.length > 1
                icon.name: "document-save-all"
                text: i18n("Save All")
                onClicked: saveAllFolderDialog.open()
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Controls.TextArea {
                readOnly: true
                wrapMode: TextEdit.Wrap
                textFormat: (!viewPane.preferPlainText && messageController.textHtml.length > 0)
                    ? TextEdit.RichText
                    : TextEdit.PlainText
                text: {
                    if (!messageController.bodySynced && messageController.textPlain.length === 0 && messageController.textHtml.length === 0) {
                        return i18n("Loading message body…")
                    }
                    if (!viewPane.preferPlainText && messageController.textHtml.length > 0) {
                        return messageController.textHtml
                    }
                    return messageController.textPlain
                }
                background: null
            }
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        visible: messageController.messageId <= 0
        width: parent.width - Kirigami.Units.largeSpacing * 2
        text: i18n("Select a conversation to read")
        icon.name: "mail-read"
    }
}
