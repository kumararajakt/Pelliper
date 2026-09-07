#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QSqlDatabase>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct SearchEntry {
    int accountId;
    QString folderPath;
    int uid;
    QString subject;
    QString sender;
    qint64 date;
    bool isRead;
    bool isStarred;
    QString preview;
};

/// Full-text search results over the shared cache database (FTS5 index is
/// maintained by the daemon). Filters + sorts client-side read-only.
class SearchModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString query READ query NOTIFY queryChanged)

public:
    enum Roles {
        AccountIdRole = Qt::UserRole + 1,
        FolderPathRole,
        UidRole,
        SubjectRole,
        SenderRole,
        DateRole,
        IsReadRole,
        IsStarredRole,
        PreviewRole,
    };

    explicit SearchModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    QString query() const;

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void clear();

Q_SIGNALS:
    void countChanged();
    void queryChanged();

private:
    Q_SLOT void onFileChanged(const QString &path);

private:
    static QString cacheDbPath();
    static QString ftsMatchQuery(const QString &input);
    void startWatching();
    void runQuery();

    QString m_query;
    QList<SearchEntry> m_results;

    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};