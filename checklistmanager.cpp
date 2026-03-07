#include "checklistmanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrl>

#ifdef CHECKLIST_WASM
// The app is served from  https://user.github.io/repo/wasm/checklist.html
// checklists/ lives one level up: https://user.github.io/repo/checklists/
// We strip both the filename AND the "wasm/" directory component.
#include <emscripten/val.h>

static QString wasmBaseUrl()
{
    auto href = emscripten::val::global("window")["location"]["href"].as<std::string>();
    QString s = QString::fromStdString(href);

    // Remove the filename  → …/repo/wasm/
    int slash = s.lastIndexOf(QLatin1Char('/'));
    s = s.left(slash + 1);

    // Remove the wasm/ subdirectory → …/repo/
    // (handles any single-level subdirectory the file sits in)
    if (s.endsWith(QStringLiteral("wasm/"))) {
        s.chop(5);  // length of "wasm/"
    }

    return s;  // always ends with '/'
}
#endif

// ─────────────────────────────────────────────────────────────────────────────

ChecklistManager::ChecklistManager(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
#ifdef CHECKLIST_WASM
    m_wasmBaseUrl = wasmBaseUrl();
    qDebug() << "WASM base URL:" << m_wasmBaseUrl;
#endif
    refreshCsvList();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
void ChecklistManager::setBusy(bool b)
{
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

static bool validIdx(int i, int n) { return n > 0 && i >= 0 && i < n; }

// ---------------------------------------------------------------------------
// CSV parser — shared by both paths
// Format: text ; emoji ; image ; timer ; auto
// ---------------------------------------------------------------------------
void ChecklistManager::parseCsvContent(const QString &content, const QString &sourceId)
{
    m_items.clear();
    m_currentIndex = 0;

    for (const QString &raw : content.split(QLatin1Char('\n'))) {
        const QString line = raw.trimmed();
        if (line.isEmpty()) continue;

        QStringList parts = line.split(QLatin1Char(';'));
        while (parts.size() < 5) parts << QString();

        ChecklistItem item;
        item.text      = parts.at(0).trimmed();
        item.emoji     = parts.at(1).trimmed();
        item.imagePath = parts.at(2).trimmed();

        const QString timerStr = parts.at(3).trimmed();
        if (!timerStr.isEmpty() && timerStr.endsWith(QLatin1Char('s'))) {
            bool ok = false;
            const int secs = QStringView(timerStr).chopped(1).toInt(&ok);
            if (ok && secs > 0) item.timerSeconds = secs;
        }

        const QString autoStr = parts.at(4).trimmed().toLower();
        item.autoProceed = (autoStr == QLatin1String("auto")
                         || autoStr == QLatin1String("1")
                         || autoStr == QLatin1String("true")
                         || autoStr == QLatin1String("yes"));

        m_items << item;
    }

    m_listTitle     = QFileInfo(sourceId).baseName();
    m_currentCsvDir = QFileInfo(sourceId).absolutePath();

    emit listLoadedChanged();
    emit currentIndexChanged();
}

// ---------------------------------------------------------------------------
// refreshCsvList
// ---------------------------------------------------------------------------
void ChecklistManager::refreshCsvList()
{
    m_csvFilePaths.clear();
    m_csvFileNames.clear();
    emit csvFilesChanged();

#ifdef CHECKLIST_WASM
    setBusy(true);
    const QUrl url(m_wasmBaseUrl + QStringLiteral("checklists/index.json"));
    qDebug() << "Fetching index.json from:" << url;
    auto *reply = m_nam->get(QNetworkRequest(url));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setBusy(false);

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "index.json fetch failed:" << reply->errorString();
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isArray()) { qWarning() << "index.json: not a JSON array"; return; }

        for (const QJsonValue &v : doc.array()) {
            const QString name = v.toString().trimmed();
            if (name.isEmpty()) continue;
            m_csvFileNames << name;
            m_csvFilePaths << (m_wasmBaseUrl + QStringLiteral("checklists/") + name + QStringLiteral(".csv"));
        }

        qDebug() << "Found checklists:" << m_csvFileNames;
        emit csvFilesChanged();
    });

#else
    QDir dir(QDir::currentPath());
    const QFileInfoList files =
        dir.entryInfoList({QStringLiteral("*.csv")}, QDir::Files, QDir::Name);
    for (const QFileInfo &fi : files) {
        m_csvFilePaths << fi.absoluteFilePath();
        m_csvFileNames << fi.baseName();
    }
    emit csvFilesChanged();
#endif
}

// ---------------------------------------------------------------------------
// loadCsv
// ---------------------------------------------------------------------------
void ChecklistManager::loadCsv(const QString &filePath)
{
    m_items.clear();
    m_currentIndex = 0;
    emit listLoadedChanged();

#ifdef CHECKLIST_WASM
    setBusy(true);
    qDebug() << "Fetching CSV:" << filePath;
    auto *reply = m_nam->get(QNetworkRequest(QUrl(filePath)));

    connect(reply, &QNetworkReply::finished, this, [this, reply, filePath]() {
        reply->deleteLater();
        setBusy(false);

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "CSV fetch failed:" << reply->errorString();
            return;
        }

        parseCsvContent(QString::fromUtf8(reply->readAll()), filePath);
    });

#else
    QFileInfo fi(filePath);
    m_currentCsvDir = fi.absolutePath();
    m_listTitle     = fi.baseName();

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit listLoadedChanged();
        emit currentIndexChanged();
        return;
    }

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    parseCsvContent(in.readAll(), filePath);
#endif
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------
void ChecklistManager::next()
{
    if (m_currentIndex < m_items.size() - 1) { ++m_currentIndex; emit currentIndexChanged(); }
}

void ChecklistManager::back()
{
    if (m_currentIndex > 0) { --m_currentIndex; emit currentIndexChanged(); }
}

void ChecklistManager::exitList()
{
    m_items.clear();
    m_currentIndex = 0;
    m_listTitle.clear();
    emit listLoadedChanged();
    emit currentIndexChanged();
    refreshCsvList();
}

// ---------------------------------------------------------------------------
// Accessors
// ---------------------------------------------------------------------------
QString ChecklistManager::currentText() const
{
    return validIdx(m_currentIndex, m_items.size())
        ? m_items.at(m_currentIndex).text : QString{};
}
QString ChecklistManager::currentEmoji() const
{
    return validIdx(m_currentIndex, m_items.size())
        ? m_items.at(m_currentIndex).emoji : QString{};
}
QString ChecklistManager::currentImageUrl() const
{
    if (!validIdx(m_currentIndex, m_items.size())) return {};
    const QString &img = m_items.at(m_currentIndex).imagePath;
    if (img.isEmpty()) return {};
#ifdef CHECKLIST_WASM
    return m_wasmBaseUrl + QStringLiteral("checklists/") + img;
#else
    const QFileInfo fi(m_currentCsvDir + QLatin1Char('/') + img);
    return fi.exists() ? QStringLiteral("file://") + fi.absoluteFilePath() : QString{};
#endif
}
int  ChecklistManager::currentTimerSecs()   const {
    return validIdx(m_currentIndex, m_items.size()) ? m_items.at(m_currentIndex).timerSeconds : -1;
}
bool ChecklistManager::currentAutoProceed() const {
    return validIdx(m_currentIndex, m_items.size()) ? m_items.at(m_currentIndex).autoProceed : false;
}
bool ChecklistManager::hasNext() const { return m_currentIndex < m_items.size() - 1; }
bool ChecklistManager::hasPrev() const { return m_currentIndex > 0; }
