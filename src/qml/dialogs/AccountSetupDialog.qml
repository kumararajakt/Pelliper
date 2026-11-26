import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: wizard
    title: i18n("Add Email Account")
    width: 480
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.NoButton

    property int step: 1 // 1=Identity, 2=ManualServer, 3=Auth, 4=Verifying
    property bool autoconfigFound: false
    property string authType: "password"
    property string oauthProvider: ""
    property string oauthUrl: ""

    function resetWizard() {
        step = 1
        autoconfigFound = false
        nameField.text = ""
        emailField.text = ""
        passwordField.text = ""
        imapHostField.text = ""
        imapPortField.text = "993"
        smtpHostField.text = ""
        smtpPortField.text = "465"
        authType = "password"
        oauthProvider = ""
        oauthUrl = ""
        errorBanner.visible = false
    }

    Connections {
        target: accountController
        function onAutoconfigCompleted(found, config) {
            wizard.autoconfigFound = found
            if (found) {
                imapHostField.text = config.imap_host || ""
                imapPortField.text = String(config.imap_port || 993)
                smtpHostField.text = config.smtp_host || ""
                smtpPortField.text = String(config.smtp_port || 465)
                wizard.authType = config.auth_type || "password"
                wizard.oauthProvider = config.oauth_provider || ""
                wizard.step = 3
                if (wizard.authType === "oauth2") {
                    accountController.startOAuth(wizard.oauthProvider, emailField.text)
                }
            } else {
                wizard.step = 2
            }
        }
        function onOauthUrlReady(authUrl) {
            wizard.oauthUrl = authUrl
            Qt.openUrlExternally(authUrl)
        }
        function onOauthCompleted(success, accessToken, refreshToken, expiresAt, error) {
            if (!success) {
                errorBanner.text = error
                errorBanner.visible = true
                return
            }
            wizard.step = 4
            accountController.testAndAddAccount({
                "email": emailField.text.trim(),
                "display_name": nameField.text.trim(),
                "imap_host": imapHostField.text.trim(),
                "imap_port": parseInt(imapPortField.text) || 993,
                "imap_tls": "tls",
                "smtp_host": smtpHostField.text.trim(),
                "smtp_port": parseInt(smtpPortField.text) || 465,
                "smtp_tls": "tls",
                "auth_type": "oauth2",
                "oauth_provider": wizard.oauthProvider.length > 0 ? wizard.oauthProvider : "google",
                "access_token": accessToken,
                "refresh_token": refreshToken,
                "expires_at": expiresAt
            })
        }
        function onAccountAdded(account) {
            folderModel.refresh()
            wizard.close()
        }
        function onAccountVerifyFailed(error) {
            errorBanner.text = error
            errorBanner.visible = true
            wizard.step = 3
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            id: errorBanner
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            visible: false
        }

        // Step 1: Display Name & Email
        Kirigami.FormLayout {
            visible: wizard.step === 1 && !accountController.busy
            Layout.fillWidth: true

            Controls.TextField {
                id: nameField
                Kirigami.FormData.label: i18n("Display Name:")
                placeholderText: i18n("Alex Rivera")
            }
            Controls.TextField {
                id: emailField
                Kirigami.FormData.label: i18n("Email Address:")
                placeholderText: i18n("alex@example.com")
            }
        }

        // Silent Autoconfig or Verification Spinner
        ColumnLayout {
            visible: accountController.busy || wizard.step === 4
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            Controls.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: parent.visible
            }
            Controls.Label {
                Layout.alignment: Qt.AlignHCenter
                text: wizard.step === 4
                    ? i18n("Verifying IMAP and SMTP connection…")
                    : i18n("Looking up server settings via Mozilla Autoconfig…")
            }
        }

        // Step 2: Manual Server Settings (only if Autoconfig did not find settings)
        Kirigami.FormLayout {
            visible: wizard.step === 2 && !accountController.busy
            Layout.fillWidth: true

            Controls.Label {
                text: i18n("Automatic configuration was not found. Enter your server details:")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Controls.TextField {
                id: imapHostField
                Kirigami.FormData.label: i18n("IMAP Host:")
                placeholderText: "imap.example.com"
            }
            Controls.TextField {
                id: imapPortField
                Kirigami.FormData.label: i18n("IMAP Port:")
                text: "993"
            }
            Controls.TextField {
                id: smtpHostField
                Kirigami.FormData.label: i18n("SMTP Host:")
                placeholderText: "smtp.example.com"
            }
            Controls.TextField {
                id: smtpPortField
                Kirigami.FormData.label: i18n("SMTP Port:")
                text: "465"
            }
            Controls.ComboBox {
                id: authCombo
                Kirigami.FormData.label: i18n("Auth Method:")
                model: ["Password", "OAuth2"]
                onCurrentIndexChanged: wizard.authType = (currentIndex === 1 ? "oauth2" : "password")
            }
        }

        // Step 3: Authentication (Password or OAuth2)
        ColumnLayout {
            visible: wizard.step === 3 && !accountController.busy
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: wizard.authType === "oauth2"
                    ? i18n("Sign in with OAuth2 in your browser, or copy the link below:")
                    : i18n("Enter your password or app password for %1:", emailField.text)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Controls.TextField {
                id: passwordField
                visible: wizard.authType !== "oauth2"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: i18n("Password / App Password")
            }

            RowLayout {
                visible: wizard.authType === "oauth2"
                Layout.fillWidth: true
                Controls.TextField {
                    id: oauthUrlField
                    Layout.fillWidth: true
                    readOnly: true
                    text: wizard.oauthUrl
                    placeholderText: i18n("Generating OAuth2 link…")
                }
                Controls.Button {
                    text: i18n("Copy Link")
                    enabled: wizard.oauthUrl.length > 0
                    onClicked: {
                        oauthUrlField.selectAll()
                        oauthUrlField.copy()
                    }
                }
            }

            Controls.Button {
                visible: wizard.autoconfigFound
                flat: true
                text: i18n("Edit server settings")
                onClicked: wizard.step = 2
            }
        }

        // Wizard Footer Buttons
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            Controls.Button {
                text: i18n("Cancel")
                onClicked: wizard.close()
            }

            Controls.Button {
                visible: wizard.step === 2 || wizard.step === 3
                enabled: !accountController.busy
                text: i18n("Back")
                onClicked: wizard.step = (wizard.step === 3 && wizard.autoconfigFound) ? 1 : (wizard.step - 1)
            }

            Controls.Button {
                highlighted: true
                enabled: !accountController.busy && (wizard.step !== 1 || (nameField.text.trim().length > 0 && emailField.text.indexOf("@") > 0))
                text: wizard.step === 3 ? i18n("Connect") : i18n("Continue")
                onClicked: {
                    errorBanner.visible = false
                    if (wizard.step === 1) {
                        accountController.lookupAutoconfig(emailField.text)
                    } else if (wizard.step === 2) {
                        wizard.step = 3
                        if (wizard.authType === "oauth2") {
                            accountController.startOAuth(wizard.oauthProvider, emailField.text)
                        }
                    } else if (wizard.step === 3) {
                        wizard.step = 4
                        accountController.testAndAddAccount({
                            "email": emailField.text.trim(),
                            "display_name": nameField.text.trim(),
                            "imap_host": imapHostField.text.trim(),
                            "imap_port": parseInt(imapPortField.text) || 993,
                            "imap_tls": "tls",
                            "smtp_host": smtpHostField.text.trim(),
                            "smtp_port": parseInt(smtpPortField.text) || 465,
                            "smtp_tls": "tls",
                            "auth_type": wizard.authType,
                            "oauth_provider": wizard.oauthProvider.length > 0 ? wizard.oauthProvider : null,
                            "password": passwordField.text
                        })
                    }
                }
            }
        }
    }
}
