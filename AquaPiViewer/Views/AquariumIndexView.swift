import SwiftUI

struct AquariumIndexView: View {
    @StateObject private var viewModel = AquariumIndexViewModel()
    @StateObject private var imageStore = TankImageStore()
    @StateObject private var livestockStore = LivestockStore()

    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                if let livestockErrorMessage = livestockStore.errorMessage {
                    errorBanner("生体メモ: \(livestockErrorMessage)")
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Aquariums")
                        .font(.title2.weight(.semibold))

                    if viewModel.isLoading && viewModel.visibleAquariumSensors.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if viewModel.visibleAquariumSensors.isEmpty {
                        ContentUnavailableView(
                            "No visible aquarium sensors.",
                            systemImage: "drop.degreesign",
                            description: Text("表示対象の水槽センサーがありません。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.visibleAquariumSensors) { sensor in
                                TankCardView(
                                    sensor: sensor,
                                    lastUpdated: viewModel.lastUpdated,
                                    temperatureSeries: viewModel.temperatureSeriesBySensorId[sensor.sensorID],
                                    temperatureSeriesErrorMessage: viewModel.temperatureSeriesErrorsBySensorId[sensor.sensorID],
                                    imageStore: imageStore,
                                    livestockStore: livestockStore
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 720, minHeight: 520)
        .task {
            livestockStore.load()
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "fish.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AquaPi")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.cyan)
                    Text("Aquarium monitoring dashboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task {
                    await viewModel.reload()
                }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .lineLimit(2)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.red)
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    AquariumIndexView()
}
