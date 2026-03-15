#include "languagemanager.h"
#include <QCoreApplication>

LanguageManager::LanguageManager(QObject *parent)
    : QObject(parent)
{
    // Default: German. Translator is installed before any QML loads,
    // so no retranslate() call is needed for the initial language.
    m_language = QStringLiteral("de");
    m_translator.load(QStringLiteral(":/translations/checklist_de.qm"));
    QCoreApplication::installTranslator(&m_translator);
}

void LanguageManager::setLanguage(const QString &lang)
{
    if (m_language == lang) return;

    QCoreApplication::removeTranslator(&m_translator);
    m_language = lang;

    if (lang != QStringLiteral("en")) {
        m_translator.load(
            QStringLiteral(":/translations/checklist_") + lang + QStringLiteral(".qm"));
        QCoreApplication::installTranslator(&m_translator);
    }

    emit languageChanged();
}
