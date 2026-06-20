import SwiftUI

struct CompactAquariumView: View {
    let sensors: [AquaReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sensors.isEmpty {
                NoTankDataView()
            } else {
                ViewThatFits(in: .horizontal) {
                    tankGrid(columns: twoColumns)
                        .frame(minWidth: 520, maxWidth: .infinity, alignment: .leading)

                    tankGrid(columns: oneColumn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tankGrid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(sensors) { sensor in
                CompactTankCardView(sensor: sensor)
            }
        }
    }

    private var oneColumn: [GridItem] {
        [GridItem(.flexible(), spacing: 8)]
    }

    private var twoColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }
}

struct NoTankDataView: View {
    var body: some View {
        ContentUnavailableView(
            "No tank data",
            systemImage: "drop.degreesign",
            description: Text("表示対象の水槽センサーがありません。")
        )
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}

private struct CompactTankCardView: View {
    let sensor: AquaReading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "thermometer.variable")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.cyan)

                Text(sensor.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 6)

                if sensor.hasFanControl {
                    Image(systemName: sensor.effectiveFanMode.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(fanIconColor)
                        .help(fanHelpText)
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

    private var fanHelpText: String {
        var text = "Fan \(sensor.effectiveFanMode.label)"
        if let reason = sensor.fanReason, !reason.isEmpty {
            text += " - \(reason)"
        }
        return text
    }

    private var fanIconColor: Color {
        switch sensor.effectiveFanMode {
        case .auto:
            sensor.effectiveFanState == .on ? .blue : .gray
        case .manualOn:
            .orange
        case .manualOff:
            .red
        case .unknown:
            .gray
        case .disabled:
            .gray.opacity(0.5)
        }
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
        ]
    )
    .padding()
}
