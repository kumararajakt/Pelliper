#include "accountmodel.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>

static const QString DB_CONNECTION_NAME = QStringLiteral("pelliper_cache_readonly");

AccountModel::AccountModel(QObject *parent)
    : QAbstractListModel(parent)
{
    refresh();
}

QString AccountModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

void AccountModel::refresh()
{
    beginResetModel();
    m_accounts.clear();

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        endResetModel();
        return;
    }

    // Use a named connection so we can cleanly remove it later
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONNECTION_NAME);
        db.setDatabaseName(dbPath);

        // Open read-only: set connect options before opening
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        if (!db.open()) {
            qWarning() << "AccountModel: failed to open cache.db read-only:" << db.lastError().text();
            endResetModel();
            return;
        }

        QSqlQuery query(db);
        if (query.exec(QStringLiteral("SELECT id, email, display_name, auth_type, enabled FROM accounts"))) {
            while (query.next()) {
                AccountEntry entry;
                entry.id = query.value(0).toInt();
                entry.email = query.value(1).toString();
                entry.displayName = query.value(2).toString();
                entry.authType = query.value(3).toString();
                entry.enabled = query.value(4).toBool();
                m_accounts.append(entry);
            }
        }

        db.close();
    }
    // Remove the connection so we can re-create it on next refresh
    QSqlDatabase::removeDatabase(DB_CONNECTION_NAME);

    endResetModel();
    Q_EMIT countChanged();
}

int AccountModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_accounts.size();
}

QVariant AccountModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_accounts.size())
        return {};

    const auto &entry = m_accounts.at(index.row());
    switch (role) {
    case IdRole:        return entry.id;
    case EmailRole:     return entry.email;
    case DisplayNameRole: return entry.displayName;
    case AuthTypeRole:  return entry.authType;
    case EnabledRole:   return entry.enabled;
    }
    return {};
}

QHash<int, QByteArray> AccountModel::roleNames() const
{
    return {
        { IdRole,         "id" },
        { EmailRole,      "email" },
        { DisplayNameRole,"displayName" },
        { AuthTypeRole,   "authType" },
        { EnabledRole,    "enabled" },
    };
}

int AccountModel::count() const
{
    return m_accounts.size();
}

QString AccountModel::firstAccountEmail() const
{
    return m_accounts.isEmpty() ? QString() : m_accounts.first().email;
}
