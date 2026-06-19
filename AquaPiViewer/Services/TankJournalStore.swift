import Combine
import Foundation
import SQLite3

@MainActor
final class TankJournalStore: ObservableObject {
    @Published private(set) var entriesByTankId: [String: [TankJournalEntry]] = [:]
    @Published private(set) var summariesByTankId: [String: TankJournalDayPartSummary] = [:]
    @Published private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let logger: AppEventLogger
    private let databasePath: String
    private let calendar: Calendar

    private var database: OpaquePointer?

    init(
        fileManager: FileManager = .default,
        logger: AppEventLogger? = nil,
        databasePath: String? = nil,
        calendar: Calendar = .current
    ) {
        self.fileManager = fileManager
        self.logger = logger ?? AppEventLogger()
        self.databasePath = databasePath ?? Self.defaultDatabasePath(fileManager: fileManager)
        self.calendar = calendar
        openDatabase()
    }

    deinit {
        sqlite3_close(database)
    }

    func entries(for tankId: String) -> [TankJournalEntry] {
        entriesByTankId[tankId] ?? []
    }

    func todaySummary(for tankId: String) -> TankJournalDayPartSummary {
        summariesByTankId[tankId] ?? .empty
    }

    @discardableResult
    func createEntry(kind: TankJournalKind, text: String? = nil, for sensor: AquaReading) -> Bool {
        let normalizedText = (text ?? kind.defaultText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            errorMessage = "日誌の内容を入力してください。"
            return false
        }

        let now = Date()
        let entry = TankJournalEntry(
            id: UUID(),
            tankId: sensor.sensorID,
            tankDisplayCode: sensor.displayCode,
            tankName: sensor.name,
            kind: kind,
            text: normalizedText,
            occurredAt: now,
            createdAt: now,
            updatedAt: now
        )

        do {
            try insert(entry)
            errorMessage = nil
            loadEntries(for: sensor.sensorID)
            refreshSummary(for: sensor.sensorID)
            return true
        } catch {
            handle(error)
            return false
        }
    }

    func loadEntries(for tankId: String) {
        do {
            entriesByTankId[tankId] = try fetchEntries(for: tankId)
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func refreshSummaries(for tankIds: [String]) {
        for tankId in tankIds {
            refreshSummary(for: tankId)
        }
    }

    func refreshSummary(for tankId: String) {
        do {
            summariesByTankId[tankId] = try fetchTodaySummary(for: tankId)
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    @discardableResult
    func updateEntry(_ entry: TankJournalEntry, occurredAt: Date, text: String) -> Bool {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            errorMessage = "日誌の内容を入力してください。"
            return false
        }

        var updatedEntry = entry
        updatedEntry.occurredAt = occurredAt
        updatedEntry.text = normalizedText
        updatedEntry.updatedAt = Date()

        do {
            try update(updatedEntry)
            errorMessage = nil
            loadEntries(for: entry.tankId)
            refreshSummary(for: entry.tankId)
            return true
        } catch {
            handle(error)
            return false
        }
    }

    @discardableResult
    func deleteEntry(_ entry: TankJournalEntry) -> Bool {
        do {
            try delete(id: entry.id)
            errorMessage = nil
            loadEntries(for: entry.tankId)
            refreshSummary(for: entry.tankId)
            return true
        } catch {
            handle(error)
            return false
        }
    }

    private func openDatabase() {
        do {
            if databasePath != ":memory:" {
                try fileManager.createDirectory(
                    at: URL(fileURLWithPath: databasePath).deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            }

            guard sqlite3_open(databasePath, &database) == SQLITE_OK else {
                throw TankJournalStoreError.databaseOpen(sqliteMessage)
            }

            try execute("""
            CREATE TABLE IF NOT EXISTS tank_journal_entries (
              id TEXT PRIMARY KEY,
              tank_id TEXT NOT NULL,
              tank_display_code TEXT,
              tank_name TEXT,
              kind TEXT NOT NULL,
              text TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            """)
            try execute("""
            CREATE INDEX IF NOT EXISTS idx_tank_journal_entries_tank_occurred_at
              ON tank_journal_entries (tank_id, occurred_at DESC);
            """)
            try execute("""
            CREATE INDEX IF NOT EXISTS idx_tank_journal_entries_occurred_at
              ON tank_journal_entries (occurred_at DESC);
            """)
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func insert(_ entry: TankJournalEntry) throws {
        let sql = """
        INSERT INTO tank_journal_entries (
          id, tank_id, tank_display_code, tank_name, kind, text, occurred_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        try withPreparedStatement(sql) { statement in
            bind(entry.id.uuidString, at: 1, to: statement)
            bind(entry.tankId, at: 2, to: statement)
            bind(entry.tankDisplayCode, at: 3, to: statement)
            bind(entry.tankName, at: 4, to: statement)
            bind(entry.kind.rawValue, at: 5, to: statement)
            bind(entry.text, at: 6, to: statement)
            bind(Self.timestampFormatter.string(from: entry.occurredAt), at: 7, to: statement)
            bind(Self.timestampFormatter.string(from: entry.createdAt), at: 8, to: statement)
            bind(Self.timestampFormatter.string(from: entry.updatedAt), at: 9, to: statement)
            try stepDone(statement)
        }
    }

    private func update(_ entry: TankJournalEntry) throws {
        let sql = """
        UPDATE tank_journal_entries
        SET text = ?, occurred_at = ?, updated_at = ?
        WHERE id = ?;
        """
        try withPreparedStatement(sql) { statement in
            bind(entry.text, at: 1, to: statement)
            bind(Self.timestampFormatter.string(from: entry.occurredAt), at: 2, to: statement)
            bind(Self.timestampFormatter.string(from: entry.updatedAt), at: 3, to: statement)
            bind(entry.id.uuidString, at: 4, to: statement)
            try stepDone(statement)
        }
    }

    private func delete(id: UUID) throws {
        try withPreparedStatement("DELETE FROM tank_journal_entries WHERE id = ?;") { statement in
            bind(id.uuidString, at: 1, to: statement)
            try stepDone(statement)
        }
    }

    private func fetchEntries(for tankId: String) throws -> [TankJournalEntry] {
        let sql = """
        SELECT id, tank_id, tank_display_code, tank_name, kind, text, occurred_at, created_at, updated_at
        FROM tank_journal_entries
        WHERE tank_id = ?
        ORDER BY occurred_at DESC, created_at DESC;
        """
        var entries: [TankJournalEntry] = []
        try withPreparedStatement(sql) { statement in
            bind(tankId, at: 1, to: statement)

            var result = sqlite3_step(statement)
            while result == SQLITE_ROW {
                if let entry = entry(from: statement) {
                    entries.append(entry)
                }
                result = sqlite3_step(statement)
            }

            guard result == SQLITE_DONE else {
                throw TankJournalStoreError.sqlite(sqliteMessage)
            }
        }
        return entries
    }

    private func fetchTodaySummary(for tankId: String) throws -> TankJournalDayPartSummary {
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let sql = """
        SELECT occurred_at
        FROM tank_journal_entries
        WHERE tank_id = ? AND occurred_at >= ? AND occurred_at < ?;
        """
        var summary = TankJournalDayPartSummary.empty
        try withPreparedStatement(sql) { statement in
            bind(tankId, at: 1, to: statement)
            bind(Self.timestampFormatter.string(from: startOfDay), at: 2, to: statement)
            bind(Self.timestampFormatter.string(from: endOfDay), at: 3, to: statement)

            var result = sqlite3_step(statement)
            while result == SQLITE_ROW {
                guard
                    let timestamp = text(at: 0, from: statement),
                    let date = Self.timestampFormatter.date(from: timestamp)
                else {
                    result = sqlite3_step(statement)
                    continue
                }

                switch TankJournalDayPart(hour: calendar.component(.hour, from: date)) {
                case .morning:
                    summary.morning += 1
                case .afternoon:
                    summary.afternoon += 1
                case .evening:
                    summary.evening += 1
                }
                result = sqlite3_step(statement)
            }

            guard result == SQLITE_DONE else {
                throw TankJournalStoreError.sqlite(sqliteMessage)
            }
        }
        return summary
    }

    private func execute(_ sql: String) throws {
        guard let database else {
            throw TankJournalStoreError.databaseOpen("database is not open")
        }

        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorPointer)
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? sqliteMessage
            sqlite3_free(errorPointer)
            throw TankJournalStoreError.sqlite(message)
        }
    }

    private func withPreparedStatement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        guard let database else {
            throw TankJournalStoreError.databaseOpen("database is not open")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw TankJournalStoreError.sqlite(sqliteMessage)
        }
        defer {
            sqlite3_finalize(statement)
        }

        return try body(statement)
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TankJournalStoreError.sqlite(sqliteMessage)
        }
    }

    private func entry(from statement: OpaquePointer) -> TankJournalEntry? {
        guard
            let idText = text(at: 0, from: statement),
            let id = UUID(uuidString: idText),
            let tankId = text(at: 1, from: statement),
            let kindText = text(at: 4, from: statement),
            let kind = TankJournalKind(rawValue: kindText),
            let body = text(at: 5, from: statement),
            let occurredAtText = text(at: 6, from: statement),
            let occurredAt = Self.timestampFormatter.date(from: occurredAtText),
            let createdAtText = text(at: 7, from: statement),
            let createdAt = Self.timestampFormatter.date(from: createdAtText),
            let updatedAtText = text(at: 8, from: statement),
            let updatedAt = Self.timestampFormatter.date(from: updatedAtText)
        else {
            return nil
        }

        return TankJournalEntry(
            id: id,
            tankId: tankId,
            tankDisplayCode: text(at: 2, from: statement),
            tankName: text(at: 3, from: statement),
            kind: kind,
            text: body,
            occurredAt: occurredAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func bind(_ value: String?, at index: Int32, to statement: OpaquePointer) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func text(at index: Int32, from statement: OpaquePointer) -> String? {
        guard let value = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: value)
    }

    private var sqliteMessage: String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "SQLite error"
        }
        return String(cString: message)
    }

    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
        logger.log("tank_journal_error", fields: ["message": error.localizedDescription])
    }

    private static func defaultDatabasePath(fileManager: FileManager) -> String {
        let applicationSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return applicationSupportURL
            .appendingPathComponent("AquaPiViewer", isDirectory: true)
            .appendingPathComponent("aquapi-viewer.sqlite")
            .path
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private enum TankJournalStoreError: LocalizedError {
    case databaseOpen(String)
    case sqlite(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpen(let message):
            "日誌データベースを開けませんでした: \(message)"
        case .sqlite(let message):
            "日誌データベースの操作に失敗しました: \(message)"
        }
    }
}
