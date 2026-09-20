import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtCore
import org.kde.kirigami as Kirigami

/// Formatting toolbar for the compose body editor.
/// `editor` is the body TextArea whose cursor selection the buttons act on.
RowLayout {
    id: formatBar

    required property QtObject editor

    spacing: Kirigami.Units.smallSpacing

    Settings {
        id: settings
        category: "compose"
    }

    function notify(msg) {
        var w = formatBar
        while (w && typeof w.showPassiveNotification !== "function") {
            w = w.parent
        }
        if (w) w.showPassiveNotification(msg)
    }

    Controls.ToolButton {
        id: boldBtn
        text: "B"
        font.weight: Font.Bold
        checkable: true
        checked: editor.cursorSelection.font.bold
        onToggled: editor.cursorSelection.font.bold = checked
        Controls.ToolTip.text: qsTr("Bold")
        Controls.ToolTip.visible: hovered
    }
    Controls.ToolButton {
        id: italicBtn
        text: "I"
        font.italic: true
        checkable: true
        checked: editor.cursorSelection.font.italic
        onToggled: editor.cursorSelection.font.italic = checked
        Controls.ToolTip.text: qsTr("Italic")
        Controls.ToolTip.visible: hovered
    }
    Controls.ToolButton {
        id: underlineBtn
        text: "U"
        font.underline: true
        checkable: true
        checked: editor.cursorSelection.font.underline
        onToggled: editor.cursorSelection.font.underline = checked
        Controls.ToolTip.text: qsTr("Underline")
        Controls.ToolTip.visible: hovered
    }
    Controls.ToolButton {
        id: strikeoutBtn
        text: "S"
        font.strikeout: true
        checkable: true
        checked: editor.cursorSelection.font.strikeout
        onToggled: editor.cursorSelection.font.strikeout = checked
        Controls.ToolTip.text: qsTr("Strikethrough")
        Controls.ToolTip.visible: hovered
    }

    Item { Layout.fillWidth: true }

    Controls.ToolButton {
        icon.name: "format-indent-more"
        checkable: true
        checked: editor.cursorSelection.alignment === Qt.AlignRight
        onToggled: editor.cursorSelection.alignment = checked
            ? Qt.AlignRight
            : Qt.AlignLeft
        Controls.ToolTip.text: qsTr("Right align")
        Controls.ToolTip.visible: hovered
    }

    Item { Layout.fillWidth: true }

    Controls.ToolButton {
        icon.name: "user-properties"
        Controls.ToolTip.text: qsTr("Insert Signature")
        Controls.ToolTip.visible: hovered
        onClicked: {
            var sig = settings.value("signature", "")
            if (sig.length === 0) {
                formatBar.notify(qsTr("No signature configured. Set it in Settings."))
                return
            }
            var sep = editor.text.length > 0 ? "\n\n-- \n" : "-- \n"
            editor.text = editor.text + sep + sig
        }
    }

    Shortcut {
        sequence: "Ctrl+B"
        enabled: editor.activeFocus
        onActivated: boldBtn.toggle()
    }
    Shortcut {
        sequence: "Ctrl+I"
        enabled: editor.activeFocus
        onActivated: italicBtn.toggle()
    }
    Shortcut {
        sequence: "Ctrl+U"
        enabled: editor.activeFocus
        onActivated: underlineBtn.toggle()
    }
    Shortcut {
        sequence: "Ctrl+S"
        enabled: editor.activeFocus
        onActivated: strikeoutBtn.toggle()
    }
}