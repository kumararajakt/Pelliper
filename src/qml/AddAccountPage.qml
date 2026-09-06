import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.pelliper as Pelliper

Kirigami.Page {
    id: root
    title: "Add Account"

    property int currentPage: 0
    property string errorMessage: ""

    function isValidEmail(email) {
        var re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    }

    Connections {
        target: Pelliper.Autodiscover
        function onDiscovered(imapHost, imapPort, imapSecurity, smtpHost, smtpPort, smtpSecurity) {
            imapHostField.text = imapHost;
            imapPortField.text = imapPort;
            imapSecurityField.text = imapSecurity;
            smtpHostField.text = smtpHost;
            smtpPortField.text = smtpPort;
            smtpSecurityField.text = smtpSecurity;
            root.currentPage = 2;
        }
        function onFailed() {
            root.currentPage = 1;
        }
    }

    Connections {
        target: Pelliper.OAuth2
        function onAuthenticated(accessToken, refreshToken, email, displayName) {
            root.errorMessage = "";
            var name = displayNameField.text.trim();
            if (name.length === 0) name = email;
            Pelliper.DaemonClient.addAccount(
                email, name,
                imapHostField.text, parseInt(imapPortField.text) || 993,
                smtpHostField.text, parseInt(smtpPortField.text) || 587,
                "oauth", accessToken, refreshToken
            );
        }
        function onFailed(message) {
            root.errorMessage = message;
        }
    }

    Connections {
        target: Pelliper.DaemonClient
        function onAccountAdded(email) {
            root.errorMessage = "";
            applicationWindow().pageStack.layers.pop();
        }
        function onAccountFailed(email, error) {
            root.errorMessage = error;
        }
    }

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
                }

                Controls.BusyIndicator {
                    running: Pelliper.Autodiscover.discovering
                    visible: Pelliper.Autodiscover.discovering
                    Layout.alignment: Qt.AlignHCenter
                }

                Controls.Label {
                    text: root.errorMessage
                    visible: root.errorMessage.length > 0
                    color: Kirigami.Theme.negativeTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
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
                    id: imapHostField
                    placeholderText: "IMAP Host"
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Controls.TextField {
                        id: imapPortField
                        placeholderText: "IMAP Port"
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhDigitsOnly
                    }

                    Controls.TextField {
                        id: imapSecurityField
                        placeholderText: "Security"
                        Layout.fillWidth: true
                        readOnly: true
                    }
                }

                Controls.TextField {
                    id: smtpHostField
                    placeholderText: "SMTP Host"
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Controls.TextField {
                        id: smtpPortField
                        placeholderText: "SMTP Port"
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhDigitsOnly
                    }

                    Controls.TextField {
                        id: smtpSecurityField
                        placeholderText: "Security"
                        Layout.fillWidth: true
                        readOnly: true
                    }
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

                // Show OAuth option if provider is detected
                ColumnLayout {
                    visible: Pelliper.OAuth2.hasProvider
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: "Sign in with %1".arg(Pelliper.OAuth2.hasProvider ? "your provider" : "")
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }

                    Controls.Button {
                        text: "Sign in with %1".arg(Pelliper.OAuth2.hasProvider ? "Google" : "Provider")
                        icon.name: "preferences-system-network-share"
                        Layout.fillWidth: true
                        highlighted: true
                        onClicked: {
                            root.errorMessage = "";
                            Pelliper.OAuth2.detectProvider(emailField.text.trim());
                            Pelliper.OAuth2.startAuth();
                        }
                    }
                }

                Controls.Label {
                    visible: !Pelliper.OAuth2.hasProvider
                    text: "OAuth is required for this provider. Password login is not supported."
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Controls.BusyIndicator {
                    running: Pelliper.OAuth2.authenticating
                    visible: Pelliper.OAuth2.authenticating
                    Layout.alignment: Qt.AlignHCenter
                }

                Controls.Label {
                    text: Pelliper.OAuth2.status
                    visible: Pelliper.OAuth2.status.length > 0 && !Pelliper.OAuth2.authenticating
                    color: Pelliper.OAuth2.status.includes("successful") ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                Controls.Label {
                    text: root.errorMessage
                    visible: root.errorMessage.length > 0
                    color: Kirigami.Theme.negativeTextColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
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
                enabled: !Pelliper.Autodiscover.discovering && !Pelliper.OAuth2.authenticating && !Pelliper.DaemonClient.busy
                onClicked: {
                    if (root.currentPage === 0) {
                        root.errorMessage = "";
                        var email = emailField.text.trim();
                        if (email.length === 0) {
                            root.errorMessage = "Please enter an email address.";
                            return;
                        }
                        if (!root.isValidEmail(email)) {
                            root.errorMessage = "Please enter a valid email address.";
                            return;
                        }
                        Pelliper.OAuth2.detectProvider(email);
                        Pelliper.Autodiscover.discover(email);
                    } else if (root.currentPage === 2) {
                        // Password-based accounts (non-OAuth)
                        if (!Pelliper.OAuth2.hasProvider) {
                            root.errorMessage = "Password login is not yet supported. Only OAuth providers (Gmail, Outlook) are available.";
                        }
                    }
                }
            }
        }
    }
}
