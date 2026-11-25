#pragma once

#include <QObject>
#include <QSettings>
#include <QString>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString folderMode READ folderMode WRITE setFolderMode NOTIFY folderModeChanged)
    Q_PROPERTY(bool showBodyPreview READ showBodyPreview WRITE setShowBodyPreview NOTIFY showBodyPreviewChanged)
    Q_PROPERTY(int undoSendSecs READ undoSendSecs WRITE setUndoSendSecs NOTIFY undoSendSecsChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString folderMode() const;
    void setFolderMode(const QString &mode);

    bool showBodyPreview() const;
    void setShowBodyPreview(bool show);

    int undoSendSecs() const;
    void setUndoSendSecs(int secs);

Q_SIGNALS:
    void folderModeChanged();
    void showBodyPreviewChanged();
    void undoSendSecsChanged();

private:
    QSettings m_settings;
};
