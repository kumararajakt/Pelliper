#pragma once

#include <QAbstractListModel>
#include <QSqlDatabase>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct AccountEntry {
    int id;
    QString email;
    QString displayName;
    QString authType;
    bool enabled;
};

class AccountModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        EmailRole,
        DisplayNameRole,
        AuthTypeRole,
        EnabledRole,
    };

    explicit AccountModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    /// Reload accounts from the read-only cache database.
    Q_INVOKABLE void refresh();

    /// Return the first account's email, or empty string if none.
    Q_INVOKABLE QString firstAccountEmail() const;

    /// Return the first account's id, or -1 if none.
    Q_INVOKABLE int firstAccountId() const;

    /// Return a display label (\"Display Name <email>\") for the account, or empty if not found.
    Q_INVOKABLE QString accountLabelForId(int accountId) const;

    /// Return the account id at a given model index, or -1 if out of range.
    Q_INVOKABLE int accountIdAt(int index) const;

Q_SIGNALS:
    void countChanged();

private:
    static QString cacheDbPath();
    QList<AccountEntry> m_accounts;
};
