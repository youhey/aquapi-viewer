import SwiftUI

struct AquariumIndexView: View {
    @StateObject private var viewModel = AquariumIndexViewModel()
    @StateObject private var imageStore = TankImageStore()
    @StateObject private var livestockStore = LivestockStore()
    @StateObject private var journalStore = TankJournalStore()
    @AppStorage("aquapi.displayMode") private var displayModeRawValue = AquaDisplayMode.normal.rawValue

    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 16)
    ]
    private let autoReloadIntervalNanoseconds: UInt64 = 60 * 1_000_000_000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                errorBanners

                if displayMode == .compact {
                    compactContent
                } else {
                    normalContent
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowTitleConfigurator(title: "AquaPi"))
        .frame(
            minWidth: displayMode == .compact ? 360 : 720,
            minHeight: displayMode == .compact ? 320 : 520
        )
        .task {
            livestockStore.load()
            await viewModel.loadIfNeeded()
            journalStore.refreshSummaries(for: visibleSensorIds)
            await runAutoReload()
        }
        .onChange(of: visibleSensorIds) {
            journalStore.refreshSummaries(for: visibleSensorIds)
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

            ToolbarItem(placement: .principal) {
                Picker("Display Mode", selection: $displayModeRawValue) {
                    ForEach(AquaDisplayMode.allCases) { mode in
                        Text(mode.label)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            ToolbarSpacer(.flexible)

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Text("Auto Refresh 60s")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await reloadSensors()
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

            await reloadSensors()
        }
    }

    private var visibleSensorIds: [String] {
        viewModel.visibleAquariumSensors.map(\.sensorID)
    }

    private var displayMode: AquaDisplayMode {
        AquaDisplayMode(rawValue: displayModeRawValue) ?? .normal
    }

    private var errorBanners: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }

            if let fanControlErrorMessage = viewModel.fanControlErrorMessage {
                errorBanner(fanControlErrorMessage)
            }

            if displayMode == .normal {
                if let livestockErrorMessage = livestockStore.errorMessage {
                    errorBanner("生体メモ: \(livestockErrorMessage)")
                }

                if let journalErrorMessage = journalStore.errorMessage {
                    errorBanner("日誌: \(journalErrorMessage)")
                }
            }
        }
    }

    private var normalContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.visibleAquariumSensors.isEmpty {
                NoTankDataView()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.visibleAquariumSensors) { sensor in
                        tankCard(for: sensor)
                    }
                }
            }
        }
    }

    private var compactContent: some View {
        CompactAquariumView(
            sensors: viewModel.visibleAquariumSensors
        )
    }

    private func tankCard(for sensor: AquaReading) -> some View {
        TankCardView(
            sensor: sensor,
            temperatureSeries: viewModel.temperatureSeriesBySensorId[sensor.sensorID],
            temperatureSeriesErrorMessage: viewModel.temperatureSeriesErrorsBySensorId[sensor.sensorID],
            imageStore: imageStore,
            livestockStore: livestockStore,
            journalStore: journalStore,
            isFanOperationInProgress: viewModel.isFanOperationInProgress(for: sensor),
            onSetFanMode: { mode in
                Task {
                    await viewModel.setFanMode(mode, for: sensor)
                }
            }
        )
    }

    private func reloadSensors() async {
        await viewModel.reload()
        journalStore.refreshSummaries(for: visibleSensorIds)
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
