#include "CidSchemeHandler.h"

#ifdef HAVE_WEBENGINE

#include <QBuffer>
#include <QFile>
#include <QWebEngineUrlRequestJob>

CidSchemeHandler::CidSchemeHandler(QObject *parent)
    : QWebEngineUrlSchemeHandler(parent)
{
}

void CidSchemeHandler::requestStarted(QWebEngineUrlRequestJob *job)
{
    const QString path = job->requestUrl().path();
    auto *file = new QFile(path, job);
    if (file->open(QIODevice::ReadOnly)) {
        job->reply("application/octet-stream", file);
    } else {
        job->fail(QWebEngineUrlRequestJob::UrlNotFound);
    }
}

RemoteImageInterceptor::RemoteImageInterceptor(QObject *parent)
    : QWebEngineUrlRequestInterceptor(parent)
{
}

void RemoteImageInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    if (m_allowRemote) {
        return;
    }
    const QString scheme = info.requestUrl().scheme();
    if (scheme == QStringLiteral("http") || scheme == QStringLiteral("https")) {
        info.block(true);
    }
}

#endif
