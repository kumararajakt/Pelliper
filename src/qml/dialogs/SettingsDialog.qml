import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: settingsDialog
    title: i18n("Settings")
    width: 560
    height: 520
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Close

    Controls.ScrollView {
        ColumnLayout {
            width: settingsDialog.width - Kirigami.Units.largeSpacing * 4
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                text: i18n("General")
                level: 3
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true
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

                Controls.ComboBox {
                    Kirigami.FormData.label: i18n("Undo Send Delay:")
                    model: [i18n("Off (0s)"), i18n("5 seconds"), i18n("10 seconds")]
                    currentIndex: appSettings.undoSendSecs === 10 ? 2 : (appSettings.undoSendSecs === 0 ? 0 : 1)
                    onActivated: appSettings.undoSendSecs = (currentIndex === 2 ? 10 : (currentIndex === 0 ? 0 : 5))
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Kirigami.Heading {
                text: i18n("Accounts")
                level: 3
            }

            Controls.Label {
                visible: accountController.accountCount === 0
                text: i18n("No accounts configured yet.")
                opacity: 0.7
            }

            Repeater {
                model: accountController.accounts
                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            Controls.Label {
                                Layout.fillWidth: true
                                text: modelData.email
                                font.bold: true
                            }
                            Controls.Switch {
                                id: enabledSwitch
                                text: i18n("Enabled")
                                checked: modelData.enabled
                            }
                        }

                        Kirigami.FormLayout {
                            Layout.fillWidth: true
                            Controls.TextField {
                                id: nameInput
                                Kirigami.FormData.label: i18n("Display Name:")
                                text: modelData.display_name
                            }
                            Controls.SpinBox {
                                id: intervalSpin
                                Kirigami.FormData.label: i18n("Sync Interval (s):")
                                from: 60
                                to: 3600
                                stepSize: 60
                                value: modelData.sync_interval_secs
                            }
                            Controls.TextArea {
                                id: sigInput
                                Kirigami.FormData.label: i18n("Signature:")
                                Layout.fillWidth: true
                                implicitHeight: 64
                                text: modelData.signature || ""
                                placeholderText: i18n("Optional email signature…")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Controls.Button {
                                text: i18n("Remove Cache")
                                icon.name: "edit-clear-history"
                                onClicked: accountController.clearAccountCache(modelData.id)
                            }
                            Controls.Button {
                                text: i18n("Remove Account")
                                icon.name: "edit-delete"
                                onClicked: accountController.removeAccount(modelData.id)
                            }
                            Item { Layout.fillWidth: true }
                            Controls.Button {
                                highlighted: true
                                text: i18n("Save")
                                onClicked: accountController.updateAccount(
                                    modelData.id,
                                    nameInput.text.trim(),
                                    intervalSpin.value,
                                    sigInput.text,
                                    enabledSwitch.checked
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
