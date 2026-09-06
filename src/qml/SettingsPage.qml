import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: settingsPage

    title: qsTr("Settings")

    signal addAccountRequested()
    signal emptyStateRequested()

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
