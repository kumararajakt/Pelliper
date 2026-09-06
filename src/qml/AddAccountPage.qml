import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root
    title: "Add Account"

    property int currentPage: 0
    property string imapHost: ""
    property int imapPort: 0
    property string smtpHost: ""
    property int smtpPort: 0
    property bool discovering: false





    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: 3
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: index === root.currentPage ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                }
            }
        }

        StackLayout {
            currentIndex: root.currentPage
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Page 1: Account Info
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                Controls.Label {
                    text: "Account Information"
                    font.pointSize: 16
                    font.weight: Font.Bold
                }

                Controls.TextField {
                    id: displayNameField
                    placeholderText: "Display Name"
                    Layout.fillWidth: true
                }

                Controls.TextField {
                    id: emailField
                    placeholderText: "Email Address"
                    Layout.fillWidth: true
                    onEditingFinished: {
                        if (text.includes("@")) {
                            console.log(Pelliper.hasAccounts)
                            // root.autodiscover(text)
                        }
                    }
                }

                Controls.Label {
                    text: "Provider will be auto-detected from your email domain"
                    color: Kirigami.Theme.disabledTextColor
                }

                Controls.BusyIndicator {
                    running: root.discovering
                    visible: root.discovering
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Page 2: Server Settings
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                Controls.Label {
                    text: "Server Settings"
                    font.pointSize: 16
                    font.weight: Font.Bold
                }

                Controls.TextField {
                    placeholderText: "IMAP Host"
                    text: root.imapHost
                    Layout.fillWidth: true
                }

                Controls.TextField {
                    placeholderText: "IMAP Port"
                    text: root.imapPort > 0 ? root.imapPort : ""
                    Layout.fillWidth: true
                    inputMethodHints: Qt.ImhDigitsOnly
                }

                Controls.TextField {
                    placeholderText: "SMTP Host"
                    text: root.smtpHost
                    Layout.fillWidth: true
                }

                Controls.TextField {
                    placeholderText: "SMTP Port"
                    text: root.smtpPort > 0 ? root.smtpPort : ""
                    Layout.fillWidth: true
                    inputMethodHints: Qt.ImhDigitsOnly
                }
            }

            // Page 3: Authentication
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                Controls.Label {
                    text: "Authentication"
                    font.pointSize: 16
                    font.weight: Font.Bold
                }

                Controls.TextField {
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    Layout.fillWidth: true
                }

                Controls.Button {
                    text: "Test Connection"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: {
                        // TODO: test connection
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Controls.Button {
                text: "Back"
                visible: root.currentPage > 0
                onClicked: root.currentPage--
            }

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: root.currentPage < 2 ? "Next" : "Save"
                highlighted: true
                onClicked: {
                    if (root.currentPage === 0) {
                        console.log(Pelliper.hasAccounts)
                    }
                    if (root.currentPage < 2) {
                        root.currentPage++
                    } else {
                        // TODO: save account
                    }
                }
            }
        }
    }
}
