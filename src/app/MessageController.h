#pragma once

#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>

class DaemonClient;

class MessageController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qint64 messageId READ messageId NOTIFY messageChanged)
    Q_PROPERTY(qint64 accountId READ accountId NOTIFY messageChanged)
    Q_PROPERTY(QString subject READ subject NOTIFY messageChanged)
    Q_PROPERTY(QString senderName READ senderName NOTIFY messageChanged)
    Q_PROPERTY(QString senderAddress READ senderAddress NOTIFY messageChanged)
    Q_PROPERTY(QString toText READ toText NOTIFY messageChanged)
    Q_PROPERTY(QString ccText READ ccText NOTIFY messageChanged)
    Q_PROPERTY(QString dateText READ dateText NOTIFY messageChanged)
    Q_PROPERTY(QString textPlain READ textPlain NOTIFY messageChanged)
    Q_PROPERTY(QString textHtml READ textHtml NOTIFY messageChanged)
    Q_PROPERTY(bool bodySynced READ bodySynced NOTIFY messageChanged)
    Q_PROPERTY(bool unread READ unread NOTIFY messageChanged)
    Q_PROPERTY(bool starred READ starred NOTIFY messageChanged)
    Q_PROPERTY(QVariantList attachments READ attachments NOTIFY messageChanged)
    Q_PROPERTY(QVariantList threadMessages READ threadMessages NOTIFY messageChanged)

public:
    explicit MessageController(DaemonClient *client, QObject *parent = nullptr);

    qint64 messageId() const { return m_messageId; }
    qint64 accountId() const { return m_accountId; }
    QString subject() const { return m_subject; }
    QString senderName() const { return m_senderName; }
    QString senderAddress() const { return m_senderAddress; }
    QString toText() const { return m_toText; }
    QString ccText() const { return m_ccText; }
    QString dateText() const { return m_dateText; }
    QString textPlain() const { return m_textPlain; }
    QString textHtml() const { return m_textHtml; }
    bool bodySynced() const { return m_bodySynced; }
    bool unread() const { return m_unread; }
    bool starred() const { return m_starred; }
    QVariantList attachments() const { return m_attachments; }
    QVariantList threadMessages() const { return m_threadMessages; }

    Q_INVOKABLE void openMessage(qint64 accountId, qint64 messageId);
    Q_INVOKABLE void toggleRead(qint64 messageId, bool markRead);
    Q_INVOKABLE void toggleStar(qint64 messageId, bool star);
    Q_INVOKABLE void archiveMessage(qint64 messageId);
    Q_INVOKABLE void deleteMessage(qint64 messageId);
    Q_INVOKABLE void sendMessage(qint64 accountId,
                                 const QString &to,
                                 const QString &cc,
                                 const QString &bcc,
                                 const QString &subject,
                                 const QString &body,
                                 const QVariantList &attachments);
    Q_INVOKABLE void openAttachment(qint64 attachmentId);
    Q_INVOKABLE void saveAttachmentAs(qint64 attachmentId, const QUrl &destFileUrl);
    Q_INVOKABLE void saveAllAttachments(const QUrl &destDirUrl);
    Q_INVOKABLE void saveDraft(qint64 draftId,
                               qint64 accountId,
                               const QString &to,
                               const QString &cc,
                               const QString &bcc,
                               const QString &subject,
                               const QString &body);
    Q_INVOKABLE void discardDraft(qint64 draftId);
    Q_INVOKABLE void fetchRawSource(qint64 messageId);
    Q_INVOKABLE void saveEml(const QUrl &destFileUrl, const QString &rawText);

Q_SIGNALS:
    void messageChanged();
    void messageRemoved(qint64 messageId);
    void outboxStatus(const QString &status, const QString &error);
    void attachmentSaved(const QString &path);
    void attachmentError(const QString &error);
    void draftSaved(qint64 draftId);
    void rawSourceReady(const QString &rawText);

private Q_SLOTS:
    void onResponse(int id, const QJsonObject &result, const QJsonObject &error);
    void onNotification(const QString &method, const QJsonObject &params);

private:
    static QString formatAddressList(const QString &jsonStr);
    static void extractFirstAddress(const QString &jsonStr, QString &nameOut, QString &addrOut);

    DaemonClient *m_client = nullptr;
    int m_getReqId = -1;
    int m_draftSaveReqId = -1;
    int m_rawReqId = -1;
    QHash<int, QString> m_pendingAttAction; // reqId -> "open" | destFilePath

    qint64 m_messageId = 0;
    qint64 m_accountId = 0;
    QString m_subject;
    QString m_senderName;
    QString m_senderAddress;
    QString m_toText;
    QString m_ccText;
    QString m_dateText;
    QString m_textPlain;
    QString m_textHtml;
    bool m_bodySynced = false;
    bool m_unread = false;
    bool m_starred = false;
    QVariantList m_attachments;
    QVariantList m_threadMessages;
};
