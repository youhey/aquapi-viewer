import SwiftUI

struct AquariumIndexView: View {
    @StateObject private var viewModel = AquariumIndexViewModel()
    @StateObject private var imageStore = TankImageStore()
    @StateObject private var livestockStore = LivestockStore()

    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 16)
    ]
    private let autoReloadIntervalNanoseconds: UInt64 = 60 * 1_000_000_000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                if let fanControlErrorMessage = viewModel.fanControlErrorMessage {
                    errorBanner(fanControlErrorMessage)
                }

                if let livestockErrorMessage = livestockStore.errorMessage {
                    errorBanner("生体メモ: \(livestockErrorMessage)")
                }

                VStack(alignment: .leading, spacing: 16) {
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
                                    livestockStore: livestockStore,
                                    isFanOperationInProgress: viewModel.isFanOperationInProgress(for: sensor),
                                    onSetFanMode: { mode in
                                        Task {
                                            await viewModel.setFanMode(mode, for: sensor)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowTitleConfigurator(title: "AquaPi"))
        .frame(minWidth: 720, minHeight: 520)
        .task {
            livestockStore.load()
            await viewModel.loadIfNeeded()
            await runAutoReload()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: "fish.circle.fill")
                        .font(.headline)
                    Text("AquaPi")
                        .font(.headline.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .foregroundStyle(.cyan)
                .accessibilityLabel("AquaPi")
            }

            ToolbarSpacer(.flexible)

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Text("Auto Refresh 60s")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await viewModel.reload()
                        }
                    } label: {
                        RefreshIconView(isLoading: viewModel.isLoading)
                    }
                    .disabled(viewModel.isLoading)
                    .help("Refresh")
                }
                .padding(.leading, 12)
                .padding(.trailing, 8)
            }
        }
    }

    private func runAutoReload() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: autoReloadIntervalNanoseconds)
            } catch {
                return
            }

            await viewModel.reload()
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

private struct RefreshIconView: View {
    let isLoading: Bool

    private let rotationDuration = 0.8

    var body: some View {
        if isLoading {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(rotationAngle(at: context.date)))
            }
        } else {
            Image(systemName: "arrow.clockwise")
        }
    }

    private func rotationAngle(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: rotationDuration)
        return elapsed / rotationDuration * 360
    }
}

private struct WindowTitleConfigurator: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        window?.title = title
        window?.titleVisibility = .hidden
    }
}
