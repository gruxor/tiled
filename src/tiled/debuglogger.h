#ifndef DEBUGLOGGER_H
#define DEBUGLOGGER_H

#include <QString>
#include <QMutex>
#include <QFile>
#include <QTextStream>

class DebugLogger
{
public:
    static void install(const QString &logFileName = QStringLiteral("debug.log"));
    static void uninstall();
    static void log(const QString &message);
    static bool isInstalled() { return sInstalled; }

private:
    static void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg);

    static QFile sLogFile;
    static QTextStream sLogStream;
    static QMutex sMutex;
    static bool sInstalled;
    static QtMessageHandler sPreviousHandler;
};

#endif // DEBUGLOGGER_H
