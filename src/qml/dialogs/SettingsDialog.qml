import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: settingsDialog
    title: i18n("Settings")
    width: 440
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Close

    Kirigami.FormLayout {
        Controls.Switch {
            Kirigami.FormData.label: i18n("Message List:")
            text: i18n("Show message body preview (Line 3)")
            checked: appSettings.showBodyPreview
            onToggled: appSettings.showBodyPreview = checked
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Folder Mode:")
            model: [i18n("Unified"), i18n("All Folders")]
            currentIndex: appSettings.folderMode === "all" ? 1 : 0
            onActivated: appSettings.folderMode = (currentIndex === 1 ? "all" : "unified")
        }
    }
}
