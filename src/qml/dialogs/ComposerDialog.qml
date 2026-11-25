import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: composer
    title: i18n("New Message")
    width: 660
    height: 540
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.NoButton

    property double accountId: 1
    property var attachmentsList: []
    property bool showCcBcc: false

    function openCompose(accId) {
        accountId = accId > 0 ? accId : 1
        title = i18n("New Message")
        toField.text = ""
        ccField.text = ""
        bccField.text = ""
        showCcBcc = false
        subjectField.text = ""
        bodyArea.text = ""
        attachmentsList = []
        open()
        toField.forceActiveFocus()
    }

    function openReply(accId, senderAddr, senderName, subj, dateStr, origBody) {
        accountId = accId > 0 ? accId : 1
        title = i18n("Reply")
        toField.text = senderAddr
        ccField.text = ""
        bccField.text = ""
        showCcBcc = false
        subjectField.text = subj.toLowerCase().startsWith("re:") ? subj : ("Re: " + subj)
        bodyArea.text = "\n\nOn " + dateStr + ", " + senderName + " wrote:\n> " + origBody.replace(/\n/g, "\n> ")
        attachmentsList = []
        open()
        bodyArea.cursorPosition = 0
        bodyArea.forceActiveFocus()
    }

    function openReplyAll(accId, senderAddr, ccStr, senderName, subj, dateStr, origBody) {
        openReply(accId, senderAddr, senderName, subj, dateStr, origBody)
        title = i18n("Reply All")
        if (ccStr.length > 0) {
            ccField.text = ccStr
            showCcBcc = true
        }
    }

    function openForward(accId, senderName, toStr, subj, dateStr, origBody, origAttachments) {
        accountId = accId > 0 ? accId : 1
        title = i18n("Forward")
        toField.text = ""
        ccField.text = ""
        bccField.text = ""
        showCcBcc = false
        subjectField.text = subj.toLowerCase().startsWith("fwd:") ? subj : ("Fwd: " + subj)
        bodyArea.text = "\n\n---------- Forwarded message ---------\n"
            + "From: " + senderName + "\n"
            + "Date: " + dateStr + "\n"
            + "Subject: " + subj + "\n"
            + "To: " + toStr + "\n\n"
            + origBody
        attachmentsList = origAttachments || []
        open()
        toField.forceActiveFocus()
    }

    FileDialog {
        id: filePicker
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            const next = composer.attachmentsList.slice()
            for (let i = 0; i < selectedFiles.length; ++i) {
                const path = selectedFiles[i].toString().replace("file://", "")
                const name = path.split("/").pop()
                next.push({ "filename": name, "local_path": path })
            }
            composer.attachmentsList = next
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("To:"); Layout.preferredWidth: 58 }
            Controls.TextField {
                id: toField
                Layout.fillWidth: true
                placeholderText: i18n("recipient@example.com")
            }
            Controls.Button {
                flat: true
                text: composer.showCcBcc ? i18n("Hide Cc/Bcc") : i18n("Cc/Bcc")
                onClicked: composer.showCcBcc = !composer.showCcBcc
            }
        }

        RowLayout {
            visible: composer.showCcBcc
            Layout.fillWidth: true
            Controls.Label { text: i18n("Cc:"); Layout.preferredWidth: 58 }
            Controls.TextField { id: ccField; Layout.fillWidth: true }
        }

        RowLayout {
            visible: composer.showCcBcc
            Layout.fillWidth: true
            Controls.Label { text: i18n("Bcc:"); Layout.preferredWidth: 58 }
            Controls.TextField { id: bccField; Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("Subject:"); Layout.preferredWidth: 58 }
            Controls.TextField {
                id: subjectField
                Layout.fillWidth: true
                placeholderText: i18n("Subject")
            }
        }

        Flow {
            visible: composer.attachmentsList.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: composer.attachmentsList
                delegate: Kirigami.Chip {
                    text: modelData.filename || i18n("Attachment")
                    onRemoved: {
                        const next = composer.attachmentsList.slice()
                        next.splice(index, 1)
                        composer.attachmentsList = next
                    }
                }
            }
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 240
            Controls.TextArea {
                id: bodyArea
                wrapMode: TextEdit.Wrap
                placeholderText: i18n("Write your message…")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Controls.Button {
                icon.name: "mail-attachment"
                text: i18n("Attach…")
                onClicked: filePicker.open()
            }
            Item { Layout.fillWidth: true }
            Controls.Button {
                text: i18n("Discard")
                onClicked: composer.close()
            }
            Controls.Button {
                highlighted: true
                icon.name: "mail-send"
                text: i18n("Send")
                enabled: toField.text.trim().length > 0
                onClicked: {
                    messageController.sendMessage(
                        composer.accountId,
                        toField.text.trim(),
                        ccField.text.trim(),
                        bccField.text.trim(),
                        subjectField.text,
                        bodyArea.text,
                        composer.attachmentsList
                    )
                    composer.close()
                }
            }
        }
    }
}
