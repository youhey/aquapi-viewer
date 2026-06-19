import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TankCardView: View {
    let sensor: AquaReading
    let temperatureSeries: TemperatureSeriesResponse?
    let temperatureSeriesErrorMessage: String?

    @ObservedObject var imageStore: TankImageStore
    @ObservedObject var livestockStore: LivestockStore
    @ObservedObject var journalStore: TankJournalStore
    let isFanOperationInProgress: Bool
    let onSetFanMode: (FanMode) -> Void

    @State private var imageErrorMessage: String?
    @State private var selectedCropImage: SelectedCropImage?
    @State private var isLivestockPreviewPresented = false
    @State private var isLivestockSheetPresented = false
    @State private var isJournalNoteSheetPresented = false
    @State private var isJournalListSheetPresented = false
    @State private var journalFeedbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photoArea

            sensorSummary

            livestockSummaryButton

            MiniTemperatureChartView(
                points: temperatureSeries?.points ?? [],
                minC: sensor.min,
                maxC: sensor.max,
                errorMessage: temperatureSeriesErrorMessage
            )

            TankJournalQuickActionsView(
                summary: journalStore.todaySummary(for: sensor.sensorID),
                feedbackMessage: journalFeedbackMessage,
                onQuickRecord: recordJournalEntry,
                onNote: {
                    isJournalNoteSheetPresented = true
                },
                onOpenList: {
                    isJournalListSheetPresented = true
                }
            )

            if let imageErrorMessage {
                Text(imageErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 382, maxHeight: 382, alignment: .topLeading)
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
        .sheet(isPresented: $isJournalNoteSheetPresented) {
            TankJournalNoteEditorView(
                tankName: sensor.name,
                onCancel: {
                    isJournalNoteSheetPresented = false
                },
                onSave: { text in
                    if journalStore.createEntry(kind: .note, text: text, for: sensor) {
                        journalFeedbackMessage = "日誌を記録しました。"
                    } else {
                        journalFeedbackMessage = journalStore.errorMessage
                    }
                    isJournalNoteSheetPresented = false
                }
            )
        }
        .sheet(isPresented: $isJournalListSheetPresented) {
            TankJournalListView(
                sensor: sensor,
                store: journalStore,
                onClose: {
                    isJournalListSheetPresented = false
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
            isLivestockPreviewPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                Text(livestockSummary.displayText)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(livestockSummary.speciesCount == 0 ? .secondary : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("生体一覧を表示")
        .popover(isPresented: $isLivestockPreviewPresented, arrowEdge: .trailing) {
            LivestockPreviewPopoverView(
                tankName: sensor.name,
                items: livestockStore.items(for: sensor.sensorID),
                summary: livestockSummary,
                onEdit: openLivestockEditorFromPopover
            )
        }
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

                HStack(alignment: .center, spacing: 12) {
                    Text(temperatureText)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    WaterSafetyStatusChipView(status: waterSafetyStatus)
                    if sensor.hasFanControl {
                        FanControlMenuView(
                            mode: sensor.effectiveFanMode,
                            state: sensor.effectiveFanState,
                            reason: sensor.fanReason,
                            isInProgress: isFanOperationInProgress,
                            onSelectMode: onSetFanMode
                        )
                    }
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

    private func openLivestockEditorFromPopover() {
        isLivestockPreviewPresented = false
        DispatchQueue.main.async {
            isLivestockSheetPresented = true
        }
    }

    private func recordJournalEntry(_ kind: TankJournalKind) {
        if journalStore.createEntry(kind: kind, for: sensor) {
            journalFeedbackMessage = "\(kind.displayName)を記録しました。"
        } else {
            journalFeedbackMessage = journalStore.errorMessage
        }
    }
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
        temperatureSeries: TemperatureSeriesResponse(
            sensorId: "28-00000020f5ed",
            name: "増田川水槽",
            range: "24h",
            points: [
                TemperatureSeriesPoint(ts: Date().addingTimeInterval(-3600 * 3), temperatureC: 22.8, rawTemperatureC: 22.8, status: "ok", crcOk: true),
                TemperatureSeriesPoint(ts: Date().addingTimeInterval(-3600 * 2), temperatureC: 23.1, rawTemperatureC: 23.1, status: "ok", crcOk: true),
                TemperatureSeriesPoint(ts: Date().addingTimeInterval(-3600), temperatureC: 22.9, rawTemperatureC: 22.9, status: "ok", crcOk: true),
                TemperatureSeriesPoint(ts: Date(), temperatureC: 23.4, rawTemperatureC: 23.4, status: "ok", crcOk: true)
            ]
        ),
        temperatureSeriesErrorMessage: nil,
        imageStore: TankImageStore(),
        livestockStore: LivestockStore(),
        journalStore: TankJournalStore(databasePath: ":memory:"),
        isFanOperationInProgress: false,
        onSetFanMode: { _ in }
    )
    .padding()
}
