import SwiftUI

struct CompactAquariumView: View {
    let sensors: [AquaReading]
    let allReadings: [AquaReading]
    let lastUpdated: Date?

    @State private var contentWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if sensors.isEmpty {
                ContentUnavailableView(
                    "No tank data",
                    systemImage: "drop.degreesign",
                    description: Text("表示対象の水槽センサーがありません。")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                LazyVGrid(columns: compactColumns(for: contentWidth), spacing: 8) {
                    ForEach(Array(sensors.enumerated()), id: \.element.id) { index, sensor in
                        CompactTankCardView(sensor: sensor, fallbackIndex: index + 1)
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: CompactWidthPreferenceKey.self, value: proxy.size.width)
                    }
                }
                .onPreferenceChange(CompactWidthPreferenceKey.self) { width in
                    contentWidth = width
                }
            }

            compactFooter
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("AquaPi")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.cyan)

            Spacer()

            Text(lastUpdatedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var compactFooter: some View {
        HStack(spacing: 12) {
            Text(roomText)
            Text("Hum --%")
            Text("Leak --")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private var roomText: String {
        guard let temperature = roomTemperature else {
            return "Room --.-°C"
        }
        return String(format: "Room %.1f°C", temperature)
    }

    private var roomTemperature: Double? {
        allReadings.first { reading in
            reading.role == "indoor" || reading.type == "air"
        }?.temperatureC
    }

    private var lastUpdatedText: String {
        guard let lastUpdated else {
            return "Updated --:--"
        }
        return "Updated \(Self.timeFormatter.string(from: lastUpdated))"
    }

    private func compactColumns(for width: CGFloat) -> [GridItem] {
        if width < 520 {
            return [GridItem(.flexible(), spacing: 8)]
        }

        return [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct CompactWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CompactTankCardView: View {
    let sensor: AquaReading
    let fallbackIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayCode)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                    .frame(minWidth: 36, alignment: .leading)
                    .lineLimit(1)

                Text(sensor.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 6)

                if sensor.effectiveFanState == .on {
                    Image(systemName: "fan.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.orange)
                        .help("Fan running")
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Text(temperatureText)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer()

                Text(waterSafetyStatus.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var displayCode: String {
        let candidates = [
            sensor.displayCode,
            shortASCIIName,
            sensor.name
        ]

        for candidate in candidates {
            if let normalized = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !normalized.isEmpty {
                return normalized
            }
        }

        return "T\(fallbackIndex)"
    }

    private var shortASCIIName: String? {
        let ascii = String(sensor.name
            .uppercased()
            .unicodeScalars
            .filter { scalar in
                (65...90).contains(Int(scalar.value))
            })
        guard !ascii.isEmpty else {
            return nil
        }
        return String(ascii.prefix(3))
    }

    private var temperatureText: String {
        guard let temperature = sensor.temperatureC, temperature.isFinite else {
            return "--.-°C"
        }

        return String(format: "%.1f°C", temperature)
    }

    private var waterSafetyStatus: WaterSafetyStatus {
        WaterSafetyEvaluator.evaluate(
            temperatureC: sensor.temperatureC,
            minC: sensor.min,
            maxC: sensor.max,
            crcOk: sensor.crcOK
        )
    }

    private var statusColor: Color {
        switch waterSafetyStatus {
        case .safety:
            .green
        case .warning:
            .orange
        case .danger:
            .red
        case .unknown:
            .gray
        }
    }
}

#Preview {
    CompactAquariumView(
        sensors: [
            AquaReading(
                sensorID: "28-00000020f5ed",
                name: "増田川水槽",
                type: "water",
                role: "aquarium",
                enabled: true,
                visible: true,
                sortOrder: 10,
                displayCode: "MDS",
                temperatureC: 24.4,
                rawTemperatureC: 24.4,
                offset: 0,
                min: 18,
                max: 28,
                status: "ok",
                crcOK: true,
                error: nil,
                fanID: "fan-1",
                fanState: "on",
                fanMode: "auto",
                fanReason: nil
            )
        ],
        allReadings: [],
        lastUpdated: Date()
    )
    .padding()
}
