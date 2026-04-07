#include "debuglogger.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QMutexLocker>

#include <cstdio>

QFile DebugLogger::sLogFile;
QTextStream DebugLogger::sLogStream;
QMutex DebugLogger::sMutex;
bool DebugLogger::sInstalled = false;
QtMessageHandler DebugLogger::sPreviousHandler = nullptr;

void DebugLogger::install(const QString &logFileName)
{
    if (sInstalled)
        return;

    QString logPath = QCoreApplication::applicationDirPath() + QDir::separator() + logFileName;
    sLogFile.setFileName(logPath);
    if (!sLogFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        fprintf(stderr, "DebugLogger: Could not open log file: %s\n", qPrintable(logPath));
        return;
    }

    sLogStream.setDevice(&sLogFile);
    sInstalled = true;
    sPreviousHandler = qInstallMessageHandler(messageHandler);

    // Write a session header
    log(QStringLiteral("=== TileZed Debug Log Started: %1 ===").arg(QDateTime::currentDateTime().toString(Qt::ISODate)));
}

void DebugLogger::uninstall()
{
    if (!sInstalled)
        return;

    log(QStringLiteral("=== TileZed Debug Log Ended: %1 ===").arg(QDateTime::currentDateTime().toString(Qt::ISODate)));

    qInstallMessageHandler(sPreviousHandler);
    sPreviousHandler = nullptr;
    sInstalled = false;

    sLogStream.flush();
    sLogFile.close();
}

void DebugLogger::log(const QString &message)
{
    if (!sInstalled)
        return;

    QMutexLocker locker(&sMutex);
    sLogStream << message << Qt::endl;
    sLogStream.flush();
}

void DebugLogger::messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    Q_UNUSED(context)

    QString prefix;
    switch (type) {
    case QtDebugMsg:    prefix = QStringLiteral("[DEBUG]"); break;
    case QtInfoMsg:     prefix = QStringLiteral("[INFO]"); break;
    case QtWarningMsg:  prefix = QStringLiteral("[WARN]"); break;
    case QtCriticalMsg: prefix = QStringLiteral("[CRITICAL]"); break;
    case QtFatalMsg:    prefix = QStringLiteral("[FATAL]"); break;
    }

    QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss.zzz"));
    QString fullMessage = QStringLiteral("%1 %2 %3").arg(timestamp, prefix, msg);

    {
        QMutexLocker locker(&sMutex);
        sLogStream << fullMessage << Qt::endl;
        sLogStream.flush();
    }

    // probably dont need this but who knows, someone might catch it? or maybe stderr is being captured anyways idk
    fprintf(stderr, "%s\n", qPrintable(fullMessage));

    // if there was a previous handler, call it too, just in case
    if (sPreviousHandler) {
        sPreviousHandler(type, context, msg);
    }
}
