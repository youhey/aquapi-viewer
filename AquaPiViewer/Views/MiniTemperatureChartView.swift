import SwiftUI

struct MiniTemperatureChartView: View {
    let points: [TemperatureSeriesPoint]
    let minC: Double?
    let maxC: Double?
    let errorMessage: String?

    private var chartValues: [ChartValue] {
        points
            .compactMap { point -> ChartValue? in
                guard let temperature = point.temperatureC, temperature.isFinite else {
                    return nil
                }

                return ChartValue(ts: point.ts, temperature: temperature)
            }
            .sorted { $0.ts < $1.ts }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("24h")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let errorMessage {
                placeholder("24h data unavailable", systemImage: "waveform.path.ecg")
                    .help(errorMessage)
            } else if chartValues.count < 2 {
                placeholder("No 24h data", systemImage: "waveform.path.ecg")
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58, alignment: .leading)
    }

    private var chart: some View {
        GeometryReader { proxy in
            let values = chartValues
            let scale = chartScale(for: values)

            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .textBackgroundColor))

                if let minC, minC.isFinite {
                    rangeLinePath(for: minC, in: proxy.size, scale: scale)
                        .stroke(
                            Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                }

                if let maxC, maxC.isFinite {
                    rangeLinePath(for: maxC, in: proxy.size, scale: scale)
                        .stroke(
                            Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                }

                sparklinePath(for: values, in: proxy.size, scale: scale)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    private func placeholder(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
    }

    private func sparklinePath(for values: [ChartValue], in size: CGSize, scale: ChartScale) -> Path {
        Path { path in
            guard values.count >= 2, size.width > 0, size.height > 0 else {
                return
            }

            let width = max(size.width - 12, 1)
            let height = max(size.height - 10, 1)
            let xInset = 6.0
            let yInset = 5.0

            for (index, value) in values.enumerated() {
                let x = xInset + width * Double(index) / Double(values.count - 1)
                let y = yInset + yPosition(
                    for: value.temperature,
                    height: height,
                    scale: scale
                )
                let point = CGPoint(x: x, y: y)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func rangeLinePath(for temperature: Double, in size: CGSize, scale: ChartScale) -> Path {
        Path { path in
            guard size.width > 0, size.height > 0 else {
                return
            }

            let height = max(size.height - 10, 1)
            let y = 5.0 + yPosition(for: temperature, height: height, scale: scale)
            path.move(to: CGPoint(x: 6, y: y))
            path.addLine(to: CGPoint(x: max(size.width - 6, 6), y: y))
        }
    }

    private func chartScale(for values: [ChartValue]) -> ChartScale {
        let temperatures = values.map(\.temperature)
        let rangeValues = [minC, maxC].compactMap { value -> Double? in
            guard let value, value.isFinite else {
                return nil
            }
            return value
        }
        let allValues = temperatures + rangeValues
        let minimum = allValues.min() ?? 0
        let maximum = allValues.max() ?? 1

        if minimum == maximum {
            return ChartScale(minimum: minimum - 0.5, maximum: maximum + 0.5)
        }

        let padding = max((maximum - minimum) * 0.12, 0.2)
        return ChartScale(minimum: minimum - padding, maximum: maximum + padding)
    }

    private func yPosition(for temperature: Double, height: Double, scale: ChartScale) -> Double {
        let ratio = (temperature - scale.minimum) / (scale.maximum - scale.minimum)
        return height * (1 - min(max(ratio, 0), 1))
    }
}

private struct ChartValue {
    let ts: Date
    let temperature: Double
}

private struct ChartScale {
    let minimum: Double
    let maximum: Double
}

#Preview {
    MiniTemperatureChartView(
        points: [
            TemperatureSeriesPoint(ts: Date().addingTimeInterval(-3600 * 3), temperatureC: 22.8, rawTemperatureC: 22.8, status: "ok", crcOk: true),
            TemperatureSeriesPoint(ts: Date().addingTimeInterval(-3600 * 2), temperatureC: 23.1, rawTemperatureC: 23.1, status: "ok", crcOk: true),
            TemperatureSeriesPoint(ts: Date().addingTimeInterval(-3600), temperatureC: 22.9, rawTemperatureC: 22.9, status: "ok", crcOk: true),
            TemperatureSeriesPoint(ts: Date(), temperatureC: 23.4, rawTemperatureC: 23.4, status: "ok", crcOk: true)
        ],
        minC: 18,
        maxC: 28,
        errorMessage: nil
    )
    .padding()
}
