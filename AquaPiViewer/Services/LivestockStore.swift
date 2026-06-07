import Combine
import Foundation

@MainActor
final class LivestockStore: ObservableObject {
    @Published private(set) var itemsBySensorId: [String: [LivestockItem]] = [:]
    @Published private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() {
        do {
            let url = try livestockURL(createDirectory: false)
            guard fileManager.fileExists(atPath: url.path) else {
                itemsBySensorId = [:]
                errorMessage = nil
                return
            }

            let data = try Data(contentsOf: url)
            itemsBySensorId = try decoder.decode([String: [LivestockItem]].self, from: data)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() {
        do {
            try write(itemsBySensorId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func items(for sensorId: String) -> [LivestockItem] {
        itemsBySensorId[sensorId] ?? []
    }

    func updateItems(_ items: [LivestockItem], for sensorId: String) {
        let normalizedItems = items.compactMap { item -> LivestockItem? in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return nil
            }

            return LivestockItem(
                id: item.id,
                name: name,
                count: max(0, item.count),
                note: item.note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        itemsBySensorId[sensorId] = normalizedItems
        save()
    }

    func summary(for sensorId: String) -> LivestockSummary {
        let items = items(for: sensorId)
        return LivestockSummary(
            speciesCount: items.count,
            totalCount: items.reduce(0) { $0 + max(0, $1.count) }
        )
    }

    private func write(_ payload: [String: [LivestockItem]]) throws {
        let url = try livestockURL(createDirectory: true)
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    private func livestockURL(createDirectory: Bool) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: createDirectory
        )
        let directoryURL = applicationSupportURL
            .appendingPathComponent("AquaPiViewer", isDirectory: true)

        if createDirectory {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL.appendingPathComponent("Livestock.json")
    }
}
