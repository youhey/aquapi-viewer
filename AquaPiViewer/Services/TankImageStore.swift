import AppKit
import Combine
import Foundation

struct TankImageCrop {
    let cropFrameSize: CGSize
    let imageDisplaySize: CGSize
    let offset: CGSize
}

@MainActor
final class TankImageStore: ObservableObject {
    @Published private(set) var version = 0

    static let normalizedImageSize = CGSize(width: 1200, height: 675)

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

    func storeCroppedImage(_ image: NSImage, crop: TankImageCrop, for sensorID: String) throws {
        let destinationDirectory = try tankImagesDirectory()
        let destinationURL = destinationDirectory
            .appendingPathComponent(sanitizedFileName(for: sensorID))
            .appendingPathExtension("jpg")
        let jpegData = try normalizedJPEGData(from: image, crop: crop)

        if let previousURL = imageURL(for: sensorID), previousURL != destinationURL {
            try? fileManager.removeItem(at: previousURL)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try jpegData.write(to: destinationURL, options: .atomic)
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

    private func normalizedJPEGData(from image: NSImage, crop: TankImageCrop) throws -> Data {
        guard crop.cropFrameSize.width > 0, crop.cropFrameSize.height > 0 else {
            throw TankImageStoreError.invalidCrop
        }

        guard image.size.width > 0, image.size.height > 0 else {
            throw TankImageStoreError.invalidImage
        }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(Self.normalizedImageSize.width),
            pixelsHigh: Int(Self.normalizedImageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw TankImageStoreError.renderingFailed
        }

        bitmap.size = Self.normalizedImageSize

        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.black.setFill()
        NSRect(origin: .zero, size: Self.normalizedImageSize).fill()

        let scaleX = Self.normalizedImageSize.width / crop.cropFrameSize.width
        let scaleY = Self.normalizedImageSize.height / crop.cropFrameSize.height
        let imageOrigin = CGPoint(
            x: ((crop.cropFrameSize.width - crop.imageDisplaySize.width) / 2 + crop.offset.width) * scaleX,
            y: ((crop.cropFrameSize.height - crop.imageDisplaySize.height) / 2 - crop.offset.height) * scaleY
        )
        let imageRect = NSRect(
            x: imageOrigin.x,
            y: imageOrigin.y,
            width: crop.imageDisplaySize.width * scaleX,
            height: crop.imageDisplaySize.height * scaleY
        )

        image.draw(
            in: imageRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        guard let data = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.9]
        ) else {
            throw TankImageStoreError.jpegEncodingFailed
        }

        return data
    }
}

enum TankImageStoreError: LocalizedError {
    case invalidCrop
    case invalidImage
    case renderingFailed
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidCrop:
            "トリミング範囲を確定できませんでした。"
        case .invalidImage:
            "画像サイズを読み取れませんでした。"
        case .renderingFailed:
            "画像の正規化に失敗しました。"
        case .jpegEncodingFailed:
            "JPEG への変換に失敗しました。"
        }
    }
}
