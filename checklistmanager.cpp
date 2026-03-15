#include "checklistmanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QCoreApplication>
#include <QRegularExpression>
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

// Read just the first # heading from a .md file without parsing the whole thing
static QString extractMdTitle(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.startsWith(QStringLiteral("# ")) && !line.startsWith(QStringLiteral("## "))) {
            QString title = line.mid(2).trimmed();
            title.remove(QStringLiteral("**"));
            return title;
        }
    }
    return {};
}


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
// Markdown parser
// Format:
//   # Title          → sets m_listTitle (not a step)
//   ## Step heading  → new step; heading text becomes item.text
//   <!-- <tok> ... → metadata: <emoji> <Ns/Nm> <auto> <file.ext>
//   other lines      → appended to current step body
// ---------------------------------------------------------------------------
void ChecklistManager::parseMdContent(const QString &content, const QString &sourceId)
{
    m_items.clear();
    m_currentIndex = 0;
    m_listTitle     = QFileInfo(sourceId).baseName();
    m_currentCsvDir = QFileInfo(sourceId).absolutePath();

    ChecklistItem current;
    bool hasCurrent = false;
    QStringList bodyLines;

    static const QRegularExpression tokenRe(QStringLiteral("<([^>]+)>"));
    static const QRegularExpression timerRe(QStringLiteral("^(\\d+)([sm])$"));

    auto flush = [&]() {
        if (!hasCurrent) return;
        if (!bodyLines.isEmpty()) {
            current.text += QStringLiteral("\\n") + bodyLines.join(QStringLiteral("\\n"));
            bodyLines.clear();
        }
        if (current.timerSeconds <= 0)
            current.autoProceed = false;
        m_items << current;
        current     = ChecklistItem{};
        hasCurrent  = false;
    };

    for (const QString &rawLine : content.split(QLatin1Char('\n'))) {
        const QString line = rawLine.trimmed();

        // Title page  (# but not ##)
        if (line.startsWith(QStringLiteral("# ")) && !line.startsWith(QStringLiteral("## "))) {
            flush();
            current.text    = line.mid(2).trimmed();
            current.isTitle = true;
            hasCurrent      = true;
            m_listTitle     = current.text;
            m_listTitle.remove(QStringLiteral("**"));
            continue;
        }

        // New step  (##)
        if (line.startsWith(QStringLiteral("## "))) {
            flush();
            current.text = line.mid(3).trimmed();
            hasCurrent   = true;
            continue;
        }

        if (!hasCurrent) continue;

        // Metadata line  <!-- <tok> <tok> ... -->
        if (line.startsWith(QStringLiteral("<!--")) && line.contains(QStringLiteral("-->"))) {
            // Strip <!-- ... --> wrappers before tokenising so the opening
            // "<!--" is not consumed as part of the first <token> match.
            const int end = line.lastIndexOf(QStringLiteral("-->"));
            const QString meta = line.mid(4, end - 4);  // between <!-- and -->
            auto it = tokenRe.globalMatch(meta);
            while (it.hasNext()) {
                const QString token = it.next().captured(1).trimmed();
                if (token.isEmpty()) continue;

                if (token.compare(QStringLiteral("auto"), Qt::CaseInsensitive) == 0) {
                    current.autoProceed = true;
                    continue;
                }

                const auto tm = timerRe.match(token);
                if (tm.hasMatch()) {
                    int val = tm.captured(1).toInt();
                    if (tm.captured(2) == QLatin1Char('m')) val *= 60;
                    current.timerSeconds = val;
                    continue;
                }

                // contains '.' → image filename; otherwise → emoji
                if (token.contains(QLatin1Char('.')))
                    current.imagePath = token;
                else
                    current.emoji = token;
            }
            continue;
        }

        // Body text
        if (!line.isEmpty())
            bodyLines << line;
    }

    flush();

    // Append a copy of the title page as the final step (end screen)
    if (!m_items.isEmpty() && m_items.first().isTitle)
        m_items.append(m_items.first());

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
    m_csvFileTitles.clear();
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
            QString name, title;
            if (v.isString()) {
                name  = v.toString().trimmed();
                title = name;
            } else {
                const QJsonObject obj = v.toObject();
                name  = obj.value(QStringLiteral("name")).toString().trimmed();
                title = obj.value(QStringLiteral("title")).toString().trimmed();
            }
            if (name.isEmpty()) continue;
            if (title.isEmpty()) title = name;
            m_csvFileNames  << name;
            m_csvFileTitles << title;
            m_csvFilePaths  << (m_wasmBaseUrl + QStringLiteral("checklists/") + name + QStringLiteral(".md"));
        }

        qDebug() << "Found checklists:" << m_csvFileNames;
        emit csvFilesChanged();
    });

#else
    QDir dir(QCoreApplication::applicationDirPath() + QStringLiteral("/checklists"));
    const QFileInfoList files =
        dir.entryInfoList({QStringLiteral("*.md"), QStringLiteral("*.csv")}, QDir::Files, QDir::Name);
    for (const QFileInfo &fi : files) {
        m_csvFilePaths << fi.absoluteFilePath();
        m_csvFileNames << fi.baseName();
        QString title;
        if (fi.suffix().toLower() == QStringLiteral("md"))
            title = extractMdTitle(fi.absoluteFilePath());
        m_csvFileTitles << (title.isEmpty() ? fi.baseName() : title);
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

    const bool isMd = filePath.endsWith(QStringLiteral(".md"), Qt::CaseInsensitive);

#ifdef CHECKLIST_WASM
    setBusy(true);
    qDebug() << "Fetching file:" << filePath;
    auto *reply = m_nam->get(QNetworkRequest(QUrl(filePath)));

    connect(reply, &QNetworkReply::finished, this, [this, reply, filePath, isMd]() {
        reply->deleteLater();
        setBusy(false);

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "File fetch failed:" << reply->errorString();
            return;
        }

        const QString content = QString::fromUtf8(reply->readAll());
        if (isMd) parseMdContent(content, filePath);
        else      parseCsvContent(content, filePath);
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
    const QString content = in.readAll();
    if (isMd) parseMdContent(content, filePath);
    else      parseCsvContent(content, filePath);
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

void ChecklistManager::restart()
{
    m_currentIndex = 0;
    emit currentIndexChanged();
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
bool ChecklistManager::currentIsTitle() const
{
    return validIdx(m_currentIndex, m_items.size())
        && m_items.at(m_currentIndex).isTitle;
}

int ChecklistManager::stepCount() const
{
    int n = 0;
    for (const auto &item : m_items)
        if (!item.isTitle) n++;
    return n;
}

int ChecklistManager::stepIndex() const
{
    if (!validIdx(m_currentIndex, m_items.size())) return -1;
    if (m_items.at(m_currentIndex).isTitle) return -1;
    int idx = 0;
    for (int i = 0; i < m_currentIndex; ++i)
        if (!m_items.at(i).isTitle) idx++;
    return idx;
}

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
