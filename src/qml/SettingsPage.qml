import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: settingsPage

    title: qsTr("Settings")

    signal addAccountRequested()
    signal emptyStateRequested()

    Settings {
        id: settings
        category: "compose"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            text: qsTr("Accounts")
            level: 2
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Pelliper.AccountModel

            delegate: Kirigami.Card {
                id: accountCard
                required property int id
                required property string email
                required property string displayName
                required property string authType
                required property bool enabled
                required property int index

                Layout.fillWidth: true
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: "user"
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Controls.Label {
                            text: accountCard.displayName || accountCard.email
                            font.pointSize: 13
                            font.weight: Font.Medium
                        }

                        Controls.Label {
                            text: accountCard.email
                            font.pointSize: 11
                            color: Kirigami.Theme.disabledTextColor
                        }

                        Controls.Label {
                            text: accountCard.authType === "oauth" ? "OAuth2" : "Password"
                            font.pointSize: 10
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    Controls.ToolButton {
                        icon.name: "user-trash"
                        onClicked: removeConfirmDialog.open(accountCard.id, accountCard.email)
                    }
                }

                onClicked: accountSettingsDialog.open(accountCard.id, accountCard.email, accountCard.displayName, accountCard.authType)
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Controls.Button {
            text: qsTr("Add Account")
            icon.name: "list-add-user"
            Layout.alignment: Qt.AlignLeft
            onClicked: settingsPage.addAccountRequested()
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            text: qsTr("Compose")
            level: 2
            Layout.fillWidth: true
        }

        Controls.Label {
            text: qsTr("Signature")
            font.pointSize: 11
        }

        Controls.TextArea {
            id: sigField
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            text: settings.value("signature", "")
            placeholderText: qsTr("Your email signature (appended to new messages)")
            wrapMode: Text.Wrap
        }

        Controls.Button {
            text: qsTr("Save Signature")
            icon.name: "document-save"
            Layout.alignment: Qt.AlignLeft
            onClicked: {
                settings.setValue("signature", sigField.text)
                applicationWindow().showPassiveNotification(qsTr("Signature saved"))
            }
        }
    }

    Controls.Dialog {
        id: removeConfirmDialog
        title: qsTr("Remove Account")
        modal: true
        parent: Controls.Overlay.overlay
        anchors.centerIn: parent
        standardButtons: Controls.Dialog.Cancel

        property int targetId: -1
        property string targetEmail: ""

        function open(id, email) {
            targetId = id
            targetEmail = email
            open()
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Controls.Label {
                text: qsTr("Remove %1 and all its data? This cannot be undone.").arg(removeConfirmDialog.targetEmail)
                wrapMode: Text.WordWrap
                Layout.preferredWidth: 300
            }

            Controls.Button {
                text: qsTr("Remove")
                icon.name: "user-trash"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    Pelliper.DaemonClient.removeAccount(removeConfirmDialog.targetId)
                    removeConfirmDialog.close()
                }
            }
        }
    }

    Controls.Dialog {
        id: accountSettingsDialog
        title: qsTr("Account Settings")
        modal: true
        parent: Controls.Overlay.overlay
        anchors.centerIn: parent
        width: 400
        standardButtons: Controls.Dialog.Close

        property int targetId: -1
        property string targetEmail: ""
        property string targetDisplayName: ""
        property string targetAuthType: ""

        function open(id, email, displayName, authType) {
            targetId = id
            targetEmail = email
            targetDisplayName = displayName
            targetAuthType = authType
            displayNameField.text = displayName
            open()
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Controls.Label {
                text: qsTr("Email")
                font.pointSize: 11
                color: Kirigami.Theme.disabledTextColor
            }
            Controls.Label {
                text: accountSettingsDialog.targetEmail
                font.pointSize: 13
                font.weight: Font.Medium
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Controls.Label {
                text: qsTr("Display Name")
                font.pointSize: 11
                color: Kirigami.Theme.disabledTextColor
            }
            Controls.TextField {
                id: displayNameField
                Layout.fillWidth: true
                placeholderText: qsTr("Your name")
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Controls.Label {
                text: qsTr("Authentication")
                font.pointSize: 11
                color: Kirigami.Theme.disabledTextColor
            }
            Controls.Label {
                text: accountSettingsDialog.targetAuthType === "oauth" ? "OAuth2 (Google/Microsoft)" : "Password"
                font.pointSize: 13
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Controls.Button {
                text: qsTr("Remove Account")
                icon.name: "user-trash"
                Layout.alignment: Qt.AlignLeft
                onClicked: {
                    accountSettingsDialog.close()
                    removeConfirmDialog.open(accountSettingsDialog.targetId, accountSettingsDialog.targetEmail)
                }
            }
        }
    }

    Connections {
        target: Pelliper.DaemonClient
        function onAccountRemoved(accountId) {
            Pelliper.AccountModel.refresh()
            Pelliper.FolderModel.refresh()
            Pelliper.MessageModel.refresh()

            if (Pelliper.AccountModel.count === 0) {
                settingsPage.emptyStateRequested()
            }
        }
    }
}
