#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "checklistmanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Checklist"));
    app.setApplicationVersion(QStringLiteral("1.0"));

    QQmlApplicationEngine engine;

    // Expose the manager as a context property so all QML has access
    ChecklistManager manager;
    engine.rootContext()->setContextProperty(QStringLiteral("checklistManager"), &manager);

    // Fail fast on QML errors
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app,    [](){ QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("ChecklistApp"), QStringLiteral("Main"));

    return app.exec();
}
