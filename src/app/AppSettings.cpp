#include "AppSettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
}

QString AppSettings::folderMode() const
{
    return m_settings.value(QStringLiteral("ui/folderMode"), QStringLiteral("unified")).toString();
}

void AppSettings::setFolderMode(const QString &mode)
{
    const QString normalized = (mode == QStringLiteral("all")) ? QStringLiteral("all") : QStringLiteral("unified");
    if (folderMode() == normalized) {
        return;
    }
    m_settings.setValue(QStringLiteral("ui/folderMode"), normalized);
    emit folderModeChanged();
}

bool AppSettings::showBodyPreview() const
{
    return m_settings.value(QStringLiteral("ui/showBodyPreview"), true).toBool();
}

void AppSettings::setShowBodyPreview(bool show)
{
    if (showBodyPreview() == show) {
        return;
    }
    m_settings.setValue(QStringLiteral("ui/showBodyPreview"), show);
    emit showBodyPreviewChanged();
}
