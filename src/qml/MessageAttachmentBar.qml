import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import app.pelliper as Pelliper

/// Footer bar showing the current message's attachments, with open / save-as
/// actions driven by Pelliper.DaemonClient.
Controls.ToolBar {
    id: attachmentBar

    required property var attachments

    property string saveFileSrc: ""

    visible: attachments.length > 0

    contentItem: ListView {
        id: attachmentList
        orientation: Qt.Horizontal
        spacing: Kirigami.Units.smallSpacing
        clip: true
        leftMargin: Kirigami.Units.smallSpacing
        rightMargin: Kirigami.Units.smallSpacing
        model: attachmentBar.attachments

        delegate: Controls.Button {
            id: attachmentButton
            width: Math.max(implicitWidth, Kirigami.Units.gridUnit * 8)
            height: attachmentList.height

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: attachmentBar.attachmentIcon(modelData.content_type)
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

            Controls.ToolTip.text: modelData.name + " (" + attachmentBar.formatFileSize(modelData.size) + ")"
            Controls.ToolTip.visible: hovered

            onClicked: attachmentBar.openMenu(index, attachmentButton)
        }
    }

    Controls.Menu {
        id: attachmentMenu
        property int attachmentIndex: -1

        Controls.MenuItem {
            text: qsTr("Open")
            icon.name: "document-open"
            onTriggered: {
                var a = attachmentBar.attachments[attachmentMenu.attachmentIndex]
                if (a) Qt.openUrlExternally("file://" + a.file_path)
            }
        }
        Controls.MenuItem {
            text: qsTr("Save As…")
            icon.name: "document-save"
            onTriggered: {
                var a = attachmentBar.attachments[attachmentMenu.attachmentIndex]
                if (!a) return
                attachmentBar.saveFileSrc = a.file_path
                saveDialog.selectedFile = ""
                saveDialog.visible = true
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Save Attachment")
        fileMode: FileDialog.SaveFile
        currentFile: attachmentBar.saveFileSrc ? "file://" + attachmentBar.saveFileSrc : ""

        onAccepted: {
            var dest = saveDialog.selectedFile.toString()
            if (dest.indexOf("file://") === 0) {
                dest = dest.substring(7)
            }
            if (dest.length > 0 && attachmentBar.saveFileSrc.length > 0) {
                Pelliper.DaemonClient.copyFile(attachmentBar.saveFileSrc, dest)
            }
        }
    }

    function openMenu(index, item) {
        attachmentMenu.attachmentIndex = index
        attachmentMenu.popup(item, 0, item.height)
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
}