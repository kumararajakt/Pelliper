#pragma once

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>
#include <QStringList>

/**
 * Renders one of the JSON address columns in `message_headers` for display.
 *
 * The daemon stores each address header as a JSON array of `{name, email}`
 * objects, e.g. `[{"name":"Alice","email":"alice@example.com"}]`, or the empty
 * array `[]` when the header was absent. Structured rather than a flat
 * `"Alice <alice@example.com>"` string so recipients stay addressable — a group
 * entry has a name but no address, and a consumer may want one without the
 * other. The UI is such a consumer, so it renders the JSON back to text on read
 * rather than the cache carrying a second, display-only copy of the same data.
 *
 * The output is the same `Name <addr-spec>` shape the daemon used to write
 * directly: the personal name, the address in angle brackets, or whichever one
 * is present. That shape is load-bearing in QML — `extractEmail()` in
 * `MessageListView.qml` pulls the address back out with `/<([^>]+)>/` for the
 * avatar and the reply-to address, so do not "simplify" it to a bare name.
 *
 * Multiple addresses are joined with `", "`, e.g. a To: header with three
 * recipients. Pass the column you want; `messageId` and friends are unaffected.
 */
inline QString addressDisplayString(const QString &json)
{
    const QJsonArray entries = QJsonDocument::fromJson(json.toUtf8()).array();
    QStringList parts;
    parts.reserve(entries.size());
    for (const QJsonValue &value : entries) {
        const QJsonObject entry = value.toObject();
        const QString name = entry.value(QLatin1String("name")).toString().trimmed();
        const QString email = entry.value(QLatin1String("email")).toString().trimmed();
        if (!name.isEmpty() && !email.isEmpty()) {
            parts << QStringLiteral("%1 <%2>").arg(name, email);
        } else if (!email.isEmpty()) {
            parts << email;
        } else if (!name.isEmpty()) {
            // A group entry: RFC3501 gives it a name and a NIL host, so there
            // is no addr-spec to show.
            parts << name;
        }
    }
    return parts.join(QStringLiteral(", "));
}
