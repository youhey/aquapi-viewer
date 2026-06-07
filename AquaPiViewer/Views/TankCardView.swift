import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TankCardView: View {
    let sensor: AquaReading
    let lastUpdated: Date?

    @ObservedObject var imageStore: TankImageStore
    @ObservedObject var livestockStore: LivestockStore
    @State private var imageErrorMessage: String?
    @State private var selectedCropImage: SelectedCropImage?
    @State private var isLivestockSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photoArea

            sensorSummary

            livestockSummaryButton

            Text(rangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(lastUpdatedText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let imageErrorMessage {
                Text(imageErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 340, maxHeight: 340, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .sheet(isPresented: $isLivestockSheetPresented) {
            LivestockEditorView(
                tankName: sensor.name,
                initialItems: livestockStore.items(for: sensor.sensorID),
                onCancel: {
                    isLivestockSheetPresented = false
                },
                onSave: { items in
                    livestockStore.updateItems(items, for: sensor.sensorID)
                    isLivestockSheetPresented = false
                }
            )
        }
        .sheet(item: $selectedCropImage) { selectedImage in
            TankImageCropperView(
                image: selectedImage.image,
                onCancel: {
                    selectedCropImage = nil
                },
                onSave: { crop in
                    saveCroppedImage(selectedImage.image, crop: crop)
                }
            )
        }
    }

    private var photoArea: some View {
        Button {
            choosePhoto()
        } label: {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))

                    if let image = storedImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                            Text("No Photo")
                                .font(.callout.weight(.medium))
                            Text("Choose Photo")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var livestockSummaryButton: some View {
        Button {
            isLivestockSheetPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                Text(livestockSummary.displayText)
                    .lineLimit(1)
                Spacer()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(livestockSummary.speciesCount == 0 ? .secondary : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sensorSummary: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "thermometer.variable")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(sensor.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline) {
                    Text(temperatureText)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    WaterSafetyStatusChipView(status: waterSafetyStatus)
                }
            }
        }
    }

    private var livestockSummary: LivestockSummary {
        livestockStore.summary(for: sensor.sensorID)
    }

    private var waterSafetyStatus: WaterSafetyStatus {
        WaterSafetyEvaluator.evaluate(
            temperatureC: sensor.temperatureC,
            minC: sensor.min,
            maxC: sensor.max,
            crcOk: sensor.crcOK
        )
    }

    private var storedImage: NSImage? {
        guard let url = imageStore.imageURL(for: sensor.sensorID) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    private var temperatureText: String {
        guard let temperature = sensor.temperatureC else {
            return "--.-℃"
        }

        return String(format: "%.1f℃", temperature)
    }

    private var rangeText: String {
        switch (sensor.min, sensor.max) {
        case let (min?, max?):
            return String(format: "Range %.1f - %.1f℃", min, max)
        case (_, _):
            return "Range unavailable"
        }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated else {
            return "Last updated --"
        }

        return "Last updated \(Self.lastUpdatedFormatter.string(from: lastUpdated))"
    }

    private func choosePhoto() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let imageData: Data
        do {
            imageData = try Data(contentsOf: url)
        } catch {
            imageErrorMessage = error.localizedDescription
            return
        }

        guard let image = NSImage(data: imageData) else {
            imageErrorMessage = "画像を読み込めませんでした。"
            return
        }

        selectedCropImage = SelectedCropImage(image: image)
    }

    private func saveCroppedImage(_ image: NSImage, crop: TankImageCrop) {
        do {
            try imageStore.storeCroppedImage(image, crop: crop, for: sensor.sensorID)
            imageErrorMessage = nil
            selectedCropImage = nil
        } catch {
            imageErrorMessage = error.localizedDescription
            selectedCropImage = nil
        }
    }

    private static let lastUpdatedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct SelectedCropImage: Identifiable {
    let id = UUID()
    let image: NSImage
}

#Preview {
    TankCardView(
        sensor: AquaReading(
            sensorID: "28-00000020f5ed",
            name: "増田川水槽",
            type: "water",
            role: "aquarium",
            enabled: true,
            visible: true,
            sortOrder: 10,
            temperatureC: 23.4,
            rawTemperatureC: 23.4,
            offset: 0,
            min: 18,
            max: 28,
            status: "ok",
            crcOK: true,
            error: nil
        ),
        lastUpdated: Date(),
        imageStore: TankImageStore(),
        livestockStore: LivestockStore()
    )
    .padding()
}
