#pragma once

#include <QObject>
#include <QSettings>
#include <QString>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString folderMode READ folderMode WRITE setFolderMode NOTIFY folderModeChanged)
    Q_PROPERTY(bool showBodyPreview READ showBodyPreview WRITE setShowBodyPreview NOTIFY showBodyPreviewChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString folderMode() const;
    void setFolderMode(const QString &mode);

    bool showBodyPreview() const;
    void setShowBodyPreview(bool show);

signals:
    void folderModeChanged();
    void showBodyPreviewChanged();

private:
    QSettings m_settings;
};
