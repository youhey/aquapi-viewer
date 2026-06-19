import SwiftUI

struct TankJournalQuickActionsView: View {
    let summary: TankJournalDayPartSummary
    let feedbackMessage: String?
    let onQuickRecord: (TankJournalKind) -> Void
    let onNote: () -> Void
    let onOpenList: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onOpenList()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                    Text(summary.displayText)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("日誌を表示")

            HStack(spacing: 8) {
                journalButton(kind: .feeding) {
                    onQuickRecord(.feeding)
                }
                journalButton(kind: .cleaning) {
                    onQuickRecord(.cleaning)
                }
                journalButton(kind: .waterTopUp) {
                    onQuickRecord(.waterTopUp)
                }
                journalButton(kind: .note) {
                    onNote()
                }

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func journalButton(kind: TankJournalKind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(kind.displayName, systemImage: kind.iconName)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 24)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(kind.displayName)
    }
}

struct TankJournalNoteEditorView: View {
    let tankName: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(tankName)のメモ")
                .font(.title3.weight(.semibold))

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 150)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.12))
                }

            HStack {
                Spacer()
                Button("キャンセル") {
                    onCancel()
                }
                Button("保存") {
                    onSave(trimmedText)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedText.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 480)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct TankJournalListView: View {
    let sensor: AquaReading
    @ObservedObject var store: TankJournalStore
    let onClose: () -> Void

    @State private var editingEntry: TankJournalEntry?
    @State private var deletingEntry: TankJournalEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(sensor.name)の日誌")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("閉じる") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if entries.isEmpty {
                ContentUnavailableView(
                    "日誌がありません。",
                    systemImage: "note.text",
                    description: Text("カード下部のボタンから記録できます。")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedEntries, id: \.date) { group in
                            dateGroupView(group)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(minHeight: 280, maxHeight: 520)
            }
        }
        .padding(22)
        .frame(width: 680)
        .onAppear {
            store.loadEntries(for: sensor.sensorID)
        }
        .sheet(item: $editingEntry) { entry in
            TankJournalEntryEditorView(
                entry: entry,
                onCancel: {
                    editingEntry = nil
                },
                onSave: { occurredAt, text in
                    if store.updateEntry(entry, occurredAt: occurredAt, text: text) {
                        editingEntry = nil
                    }
                }
            )
        }
        .confirmationDialog("この日誌を削除しますか？", isPresented: isDeleteDialogPresented) {
            Button("削除", role: .destructive) {
                if let deletingEntry {
                    _ = store.deleteEntry(deletingEntry)
                }
                deletingEntry = nil
            }
            Button("キャンセル", role: .cancel) {
                deletingEntry = nil
            }
        }
    }

    private var entries: [TankJournalEntry] {
        store.entries(for: sensor.sensorID)
    }

    private var groupedEntries: [(date: Date, entries: [TankJournalEntry])] {
        let grouped = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.occurredAt)
        }
        return grouped
            .map { (date: $0.key, entries: $0.value.sorted { $0.occurredAt > $1.occurredAt }) }
            .sorted { $0.date > $1.date }
    }

    private var isDeleteDialogPresented: Binding<Bool> {
        Binding(
            get: { deletingEntry != nil },
            set: { isPresented in
                if !isPresented {
                    deletingEntry = nil
                }
            }
        )
    }

    private func dateGroupView(_ group: (date: Date, entries: [TankJournalEntry])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.dateFormatter.string(from: group.date))
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(TankJournalDayPart.allCases) { dayPart in
                    let dayPartEntries = entries(for: dayPart, in: group.entries)
                    if !dayPartEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dayPart.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(dayPartEntries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func entryRow(_ entry: TankJournalEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.kind.iconName)
                .frame(width: 18)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(Self.timeFormatter.string(from: entry.occurredAt))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(entry.kind.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(entry.text)
                    .font(.body)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                editingEntry = entry
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("編集")

            Button {
                deletingEntry = entry
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("削除")
        }
    }

    private func entries(for dayPart: TankJournalDayPart, in entries: [TankJournalEntry]) -> [TankJournalEntry] {
        entries.filter { entry in
            TankJournalDayPart(hour: Calendar.current.component(.hour, from: entry.occurredAt)) == dayPart
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .current
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter
    }()
}

private struct TankJournalEntryEditorView: View {
    let entry: TankJournalEntry
    let onCancel: () -> Void
    let onSave: (Date, String) -> Void

    @State private var occurredAt: Date
    @State private var text: String

    init(
        entry: TankJournalEntry,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Date, String) -> Void
    ) {
        self.entry = entry
        self.onCancel = onCancel
        self.onSave = onSave
        _occurredAt = State(initialValue: entry.occurredAt)
        _text = State(initialValue: entry.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("日誌を編集")
                .font(.title3.weight(.semibold))

            Label(entry.kind.displayName, systemImage: entry.kind.iconName)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            DatePicker(
                "日時",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 150)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.12))
                }

            HStack {
                Spacer()
                Button("キャンセル") {
                    onCancel()
                }
                Button("保存") {
                    onSave(occurredAt, trimmedText)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedText.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    TankJournalQuickActionsView(
        summary: TankJournalDayPartSummary(morning: 1, afternoon: 0, evening: 1),
        feedbackMessage: "餌やりを記録しました。",
        onQuickRecord: { _ in },
        onNote: {},
        onOpenList: {}
    )
    .padding()
}
