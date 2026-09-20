#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#include <KLocalization>
#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <KIconTheme>

namespace {
void loadEnvFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }
    while (!file.atEnd()) {
        QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
            continue;
        }
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0) {
            continue;
        }
        const QString key = line.left(eq).trimmed();
        QString value = line.mid(eq + 1).trimmed();
        if (value.size() >= 2 && value.startsWith(QLatin1Char('"')) && value.endsWith(QLatin1Char('"'))) {
            value = value.mid(1, value.size() - 2);
        }
        const QByteArray keyBytes = key.toUtf8();
        if (!keyBytes.isEmpty() && qEnvironmentVariableIsEmpty(keyBytes.constData())) {
            qputenv(keyBytes.constData(), value.toUtf8());
        }
    }
}

void loadEnvFile()
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/pelliper");
    const QString envFile = dataDir + QStringLiteral("/.env");
    if (QFileInfo::exists(envFile)) {
        loadEnvFile(envFile);
    } else {
        loadEnvFile(QStringLiteral(".env"));
    }
}
}

int main(int argc, char *argv[])
{
    KIconTheme::initTheme();
    QtWebEngineQuick::initialize();
    QApplication app(argc, argv);
    loadEnvFile();
    KLocalizedString::setApplicationDomain("pelliper");
    QApplication::setOrganizationName(QStringLiteral("KDE"));
    QApplication::setOrganizationDomain(QStringLiteral("kde.org"));
    QApplication::setApplicationName(QStringLiteral("Pelliper"));
    QApplication::setDesktopFileName(QStringLiteral("pelliper"));

    QApplication::setStyle(QStringLiteral("breeze"));
    QApplication::setQuitOnLastWindowClosed(false);
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    engine.loadFromModule("app.pelliper", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
