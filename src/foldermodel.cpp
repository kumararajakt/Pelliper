#include "foldermodel.h"

#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>

static const QString DB_CONN = QStringLiteral("pelliper_folders_readonly");

FolderModel::FolderModel(QObject *parent)
    : QAbstractListModel(parent)
{
    refresh();
}

QString FolderModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

QString FolderModel::displayNameFromPath(const QString &path)
{
    // Extract the last component of the path and prettify it
    QString name = path;
    if (name.endsWith(QLatin1Char('/')))
        name.chop(1);

    int lastSlash = name.lastIndexOf(QLatin1Char('/'));
    if (lastSlash >= 0)
        name = name.mid(lastSlash + 1);

    // Common IMAP folder name translations
    static const QMap<QString, QString> prettyNames = {
        { QStringLiteral("INBOX"),          QStringLiteral("Inbox") },
        { QStringLiteral("Sent"),           QStringLiteral("Sent") },
        { QStringLiteral("Sent Messages"),  QStringLiteral("Sent") },
        { QStringLiteral("Drafts"),         QStringLiteral("Drafts") },
        { QStringLiteral("Trash"),          QStringLiteral("Trash") },
        { QStringLiteral("Junk"),           QStringLiteral("Spam") },
        { QStringLiteral("Junk E-mail"),    QStringLiteral("Spam") },
        { QStringLiteral("Spam"),           QStringLiteral("Spam") },
        { QStringLiteral("Archive"),        QStringLiteral("Archive") },
        { QStringLiteral("Archives"),       QStringLiteral("Archive") },
        { QStringLiteral("Starred"),        QStringLiteral("Starred") },
        { QStringLiteral("Important"),      QStringLiteral("Important") },
    };

    return prettyNames.value(name, name);
}

QString FolderModel::iconNameFromPath(const QString &path)
{
    QString name = path;
    if (name.endsWith(QLatin1Char('/')))
        name.chop(1);

    int lastSlash = name.lastIndexOf(QLatin1Char('/'));
    if (lastSlash >= 0)
        name = name.mid(lastSlash + 1);

    static const QMap<QString, QString> icons = {
        { QStringLiteral("INBOX"),          QStringLiteral("inbox") },
        { QStringLiteral("Sent"),           QStringLiteral("mail-sent") },
        { QStringLiteral("Sent Messages"),  QStringLiteral("mail-sent") },
        { QStringLiteral("Drafts"),         QStringLiteral("document-edit") },
        { QStringLiteral("Trash"),          QStringLiteral("user-trash") },
        { QStringLiteral("Junk"),           QStringLiteral("mail-receive") },
        { QStringLiteral("Junk E-mail"),    QStringLiteral("mail-receive") },
        { QStringLiteral("Spam"),           QStringLiteral("mail-receive") },
        { QStringLiteral("Archive"),        QStringLiteral("archive") },
        { QStringLiteral("Archives"),       QStringLiteral("archive") },
        { QStringLiteral("Starred"),        QStringLiteral("starred") },
        { QStringLiteral("Important"),      QStringLiteral("mail-important") },
    };

    return icons.value(name, QStringLiteral("folder-mail"));
}

void FolderModel::refresh()
{
    beginResetModel();
    m_folders.clear();

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        endResetModel();
        return;
    }

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "FolderModel: failed to open cache.db:" << db.lastError().text();
            endResetModel();
            return;
        }

        QSqlQuery query(db);
        if (query.exec(QStringLiteral(
                "SELECT account_id, path, unread_count FROM folders ORDER BY path"))) {
            while (query.next()) {
                FolderEntry entry;
                entry.accountId = query.value(0).toInt();
                entry.path = query.value(1).toString();
                entry.unreadCount = query.value(2).toInt();
                entry.displayName = displayNameFromPath(entry.path);
                entry.iconName = iconNameFromPath(entry.path);
                m_folders.append(entry);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    endResetModel();
    Q_EMIT countChanged();
}

void FolderModel::refreshForAccount(int accountId)
{
    beginResetModel();
    m_folders.clear();

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        endResetModel();
        return;
    }

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "FolderModel: failed to open cache.db:" << db.lastError().text();
            endResetModel();
            return;
        }

        QSqlQuery query(db);
        query.prepare(QStringLiteral(
            "SELECT account_id, path, unread_count FROM folders "
            "WHERE account_id = ? ORDER BY path"));
        query.addBindValue(accountId);

        if (query.exec()) {
            while (query.next()) {
                FolderEntry entry;
                entry.accountId = query.value(0).toInt();
                entry.path = query.value(1).toString();
                entry.unreadCount = query.value(2).toInt();
                entry.displayName = displayNameFromPath(entry.path);
                entry.iconName = iconNameFromPath(entry.path);
                m_folders.append(entry);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    endResetModel();
    Q_EMIT countChanged();
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_folders.size();
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_folders.size())
        return {};

    const auto &entry = m_folders.at(index.row());
    switch (role) {
    case AccountIdRole:    return entry.accountId;
    case PathRole:         return entry.path;
    case UnreadCountRole:  return entry.unreadCount;
    case DisplayNameRole:  return entry.displayName;
    case IconNameRole:     return entry.iconName;
    }
    return {};
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        { AccountIdRole,   "accountId" },
        { PathRole,        "path" },
        { UnreadCountRole, "unreadCount" },
        { DisplayNameRole, "displayName" },
        { IconNameRole,    "iconName" },
    };
}

int FolderModel::count() const
{
    return m_folders.size();
}
