#pragma once

#ifdef HAVE_WEBENGINE

#include <QWebEngineUrlRequestInterceptor>
#include <QWebEngineUrlSchemeHandler>

class CidSchemeHandler : public QWebEngineUrlSchemeHandler
{
    Q_OBJECT
public:
    explicit CidSchemeHandler(QObject *parent = nullptr);
    void requestStarted(QWebEngineUrlRequestJob *job) override;
};

class RemoteImageInterceptor : public QWebEngineUrlRequestInterceptor
{
    Q_OBJECT
public:
    explicit RemoteImageInterceptor(QObject *parent = nullptr);
    void setAllowRemote(bool allow) { m_allowRemote = allow; }
    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

private:
    bool m_allowRemote = false;
};

#endif
