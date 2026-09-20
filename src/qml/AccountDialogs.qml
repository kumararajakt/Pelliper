import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

/// Owns the remove-confirmation and per-account settings dialogs used by the
/// Settings page. The page wires `removeRequested` up to the daemon.
Item {
    id: root

    signal removeRequested(int accountId)

    function openRemoveDialog(id, email) {
        removeConfirmDialog.openDialog(id, email)
    }

    function openAccountSettings(id, email, displayName, authType) {
        accountSettingsDialog.openDialog(id, email, displayName, authType)
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

        function openDialog(id, email) {
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
                    root.removeRequested(removeConfirmDialog.targetId)
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

        function openDialog(id, email, displayName, authType) {
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
                    removeConfirmDialog.openDialog(accountSettingsDialog.targetId, accountSettingsDialog.targetEmail)
                }
            }
        }
    }
}