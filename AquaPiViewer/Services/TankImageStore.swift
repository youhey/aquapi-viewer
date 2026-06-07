import Combine
import Foundation

@MainActor
final class TankImageStore: ObservableObject {
    @Published private(set) var version = 0

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let keyPrefix = "tankImagePath."

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    func imageURL(for sensorID: String) -> URL? {
        guard let path = defaults.string(forKey: key(for: sensorID)) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func storeImage(from sourceURL: URL, for sensorID: String) throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationDirectory = try tankImagesDirectory()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        let destinationURL = destinationDirectory
            .appendingPathComponent(sanitizedFileName(for: sensorID))
            .appendingPathExtension(fileExtension)

        if let previousURL = imageURL(for: sensorID), previousURL != destinationURL {
            try? fileManager.removeItem(at: previousURL)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        defaults.set(destinationURL.path, forKey: key(for: sensorID))
        version += 1
    }

    private func tankImagesDirectory() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = applicationSupportURL
            .appendingPathComponent("AquaPiViewer", isDirectory: true)
            .appendingPathComponent("TankImages", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func key(for sensorID: String) -> String {
        keyPrefix + sensorID
    }

    private func sanitizedFileName(for sensorID: String) -> String {
        sensorID.map { character in
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                return character
            }
            return "_"
        }
        .map(String.init)
        .joined()
    }
}
