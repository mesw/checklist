#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFontDatabase>

#include "checklistmanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Checklist"));
    app.setApplicationVersion(QStringLiteral("1.0"));

    // ── Emoji font ────────────────────────────────────────────────────────
    // Loaded on all platforms; critical for WASM which has no system fonts.
    // The font covers emoji codepoints as a fallback — Latin text is
    // unaffected because Qt always prefers the primary font for those.
#ifdef HAS_EMOJI_FONT
    const int id = QFontDatabase::addApplicationFont(
        QStringLiteral(":/fonts/NotoEmoji-Regular.ttf"));
    if (id == -1)
        qWarning("Failed to load NotoEmoji-Regular.ttf from resources");
#endif

    QQmlApplicationEngine engine;

    ChecklistManager manager;
    engine.rootContext()->setContextProperty(
        QStringLiteral("checklistManager"), &manager);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app,    []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("ChecklistApp"),
                          QStringLiteral("Main"));

    return app.exec();
}
