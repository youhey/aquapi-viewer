import Foundation

struct AppEventLogger {
    private let fileManager: FileManager
    private let calendar: Calendar

    init(fileManager: FileManager = .default, calendar: Calendar = .current) {
        self.fileManager = fileManager
        self.calendar = calendar
    }

    func log(_ event: String, fields: [String: Any] = [:], now: Date = Date()) {
        do {
            try pruneOldLogs(now: now)

            var payload: [String: Any] = [
                "logged_at": Self.timestampFormatter.string(from: now),
                "event": event
            ]
            fields.forEach { key, value in
                payload[key] = value
            }

            guard JSONSerialization.isValidJSONObject(payload) else {
                return
            }

            var data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            data.append(0x0A)
            try append(data, to: logFileURL(for: now))
        } catch {
            return
        }
    }

    private func append(_ data: Data, to url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer {
                try? handle.close()
            }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    private func pruneOldLogs(now: Date) throws {
        let directoryURL = try logsDirectoryURL(create: false)
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        let threshold = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        for url in urls where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modifiedAt = values.contentModificationDate, modifiedAt < threshold else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    private func logFileURL(for date: Date) throws -> URL {
        try logsDirectoryURL(create: true)
            .appendingPathComponent("aquapi-viewer-\(Self.fileDateFormatter.string(from: date)).jsonl")
    }

    private func logsDirectoryURL(create: Bool) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
        return applicationSupportURL
            .appendingPathComponent("AquaPiViewer", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        formatter.timeZone = .current
        return formatter
    }()

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
