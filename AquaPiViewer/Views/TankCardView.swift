import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TankCardView: View {
    let sensor: AquaReading
    let lastUpdated: Date?

    @ObservedObject var imageStore: TankImageStore
    @State private var imageErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photoArea

            Text(sensor.name)
                .font(.headline)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline) {
                Text(temperatureText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                StatusChipView(status: sensor.status)
            }

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
        .frame(maxWidth: .infinity, minHeight: 308, maxHeight: 308, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var photoArea: some View {
        Button {
            choosePhoto()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))

                if let image = storedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                        Text("Choose Photo")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
        case let (min?, nil):
            return String(format: "Min %.1f℃", min)
        case let (nil, max?):
            return String(format: "Max %.1f℃", max)
        case (nil, nil):
            return "Range --"
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

        do {
            try imageStore.storeImage(from: url, for: sensor.sensorID)
            imageErrorMessage = nil
        } catch {
            imageErrorMessage = error.localizedDescription
        }
    }

    private static let lastUpdatedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
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
        imageStore: TankImageStore()
    )
    .padding()
}
