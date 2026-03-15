#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QList>
#include <QNetworkAccessManager>

struct ChecklistItem {
    QString text;
    QString emoji;
    QString imagePath;
    int     timerSeconds = -1;
    bool    autoProceed  = false;
    bool    isTitle      = false;
};

class ChecklistManager : public QObject
{
    Q_OBJECT

    // ── File list ─────────────────────────────────────────────────────────
    Q_PROPERTY(QStringList csvFilePaths  READ csvFilePaths  NOTIFY csvFilesChanged)
    Q_PROPERTY(QStringList csvFileNames  READ csvFileNames  NOTIFY csvFilesChanged)
    Q_PROPERTY(QStringList csvFileTitles READ csvFileTitles NOTIFY csvFilesChanged)

    // ── Async state ───────────────────────────────────────────────────────
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

    // ── Loaded list meta ──────────────────────────────────────────────────
    Q_PROPERTY(bool    listLoaded READ listLoaded NOTIFY listLoadedChanged)
    Q_PROPERTY(int     totalItems READ totalItems NOTIFY listLoadedChanged)
    Q_PROPERTY(int     stepCount  READ stepCount  NOTIFY listLoadedChanged)
    Q_PROPERTY(QString listTitle  READ listTitle  NOTIFY listLoadedChanged)

    // ── Current step ──────────────────────────────────────────────────────
    Q_PROPERTY(int     currentIndex       READ currentIndex       NOTIFY currentIndexChanged)
    Q_PROPERTY(int     stepIndex          READ stepIndex          NOTIFY currentIndexChanged)
    Q_PROPERTY(bool    currentIsTitle     READ currentIsTitle     NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentText        READ currentText        NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentEmoji       READ currentEmoji       NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentImageUrl    READ currentImageUrl    NOTIFY currentIndexChanged)
    Q_PROPERTY(int     currentTimerSecs   READ currentTimerSecs   NOTIFY currentIndexChanged)
    Q_PROPERTY(bool    currentAutoProceed READ currentAutoProceed NOTIFY currentIndexChanged)
    Q_PROPERTY(bool    hasNext            READ hasNext            NOTIFY currentIndexChanged)
    Q_PROPERTY(bool    hasPrev            READ hasPrev            NOTIFY currentIndexChanged)

public:
    explicit ChecklistManager(QObject *parent = nullptr);

    QStringList csvFilePaths()  const { return m_csvFilePaths; }
    QStringList csvFileNames()  const { return m_csvFileNames; }
    QStringList csvFileTitles() const { return m_csvFileTitles; }

    bool busy()       const { return m_busy; }
    bool listLoaded() const { return !m_items.isEmpty(); }
    int  totalItems() const { return m_items.size(); }
    int  stepCount()  const;
    QString listTitle() const { return m_listTitle; }

    int     currentIndex()       const { return m_currentIndex; }
    int     stepIndex()          const;
    bool    currentIsTitle()     const;
    QString currentText()        const;
    QString currentEmoji()       const;
    QString currentImageUrl()    const;
    int     currentTimerSecs()   const;
    bool    currentAutoProceed() const;
    bool    hasNext()            const;
    bool    hasPrev()            const;

    Q_INVOKABLE void refreshCsvList();
    Q_INVOKABLE void loadCsv(const QString &filePath);
    Q_INVOKABLE void next();
    Q_INVOKABLE void back();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void exitList();

signals:
    void csvFilesChanged();
    void busyChanged();
    void listLoadedChanged();
    void currentIndexChanged();

private:
    void setBusy(bool b);
    void parseCsvContent(const QString &content, const QString &sourceId);
    void parseMdContent (const QString &content, const QString &sourceId);

    QNetworkAccessManager *m_nam = nullptr;
    QStringList            m_csvFilePaths;
    QStringList            m_csvFileNames;
    QStringList            m_csvFileTitles;
    QList<ChecklistItem>   m_items;
    int                    m_currentIndex = 0;
    QString                m_currentCsvDir;   // native only
    QString                m_wasmBaseUrl;     // WASM only
    QString                m_listTitle;
    bool                   m_busy = false;
};
