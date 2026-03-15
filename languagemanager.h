#pragma once

#include <QObject>
#include <QTranslator>

class LanguageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)

public:
    explicit LanguageManager(QObject *parent = nullptr);

    QString language() const { return m_language; }
    Q_INVOKABLE void setLanguage(const QString &lang);

signals:
    void languageChanged();

private:
    QTranslator m_translator;
    QString     m_language;
};
