import SwiftUI

struct TankJournalCalendarView: View {
    let sensor: AquaReading
    @ObservedObject var store: TankJournalStore
    let onClose: () -> Void

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var monthEntries: [TankJournalEntry] = []
    @State private var editingEntry: TankJournalEntry?
    @State private var deletingEntry: TankJournalEntry?

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .top, spacing: 18) {
                calendarPane
                    .frame(width: 500)

                Divider()

                selectedDateDetail
                    .frame(width: 360)
            }
        }
        .padding(22)
        .frame(width: 930)
        .frame(minHeight: 620)
        .onAppear {
            displayedMonth = monthStart(for: selectedDate)
            reloadMonth()
        }
        .onChange(of: displayedMonth) {
            reloadMonth()
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
                        selectedDate = occurredAt
                        displayedMonth = monthStart(for: occurredAt)
                        reloadMonth()
                    }
                }
            )
        }
        .confirmationDialog("この日誌を削除しますか？", isPresented: isDeleteDialogPresented) {
            Button("削除", role: .destructive) {
                if let deletingEntry {
                    _ = store.deleteEntry(deletingEntry)
                    reloadMonth()
                }
                deletingEntry = nil
            }
            Button("キャンセル", role: .cancel) {
                deletingEntry = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(sensor.name)の日誌カレンダー")
                .font(.title3.weight(.semibold))

            Spacer()

            Button("Today") {
                selectedDate = Date()
                displayedMonth = monthStart(for: selectedDate)
                reloadMonth()
            }

            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("前月")

            Text(Self.monthFormatter.string(from: displayedMonth))
                .font(.headline)
                .frame(width: 160)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("次月")

            Button("閉じる") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var calendarPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: calendarColumns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: calendarColumns, spacing: 8) {
                ForEach(calendarDays) { day in
                    TankJournalCalendarDayCell(
                        day: day,
                        entries: entriesByDay[day.dayKey] ?? [],
                        isToday: day.date.map { calendar.isDateInToday($0) } ?? false,
                        isSelected: day.date.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false,
                        onSelect: { date in
                            selectedDate = date
                        }
                    )
                }
            }

            Spacer()
        }
    }

    private var selectedDateDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Self.selectedDateFormatter.string(from: selectedDate))
                .font(.headline)

            if selectedEntries.isEmpty {
                ContentUnavailableView(
                    "この日の記録はありません。",
                    systemImage: "calendar",
                    description: Text("水槽カードのクイックボタンから記録できます。")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(TankJournalDayPart.allCases) { dayPart in
                            dayPartSection(dayPart)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxHeight: 500)
            }
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var calendarDays: [TankJournalCalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let monthStart = monthInterval.start
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlankCount = (firstWeekday + 6) % 7

        var days: [TankJournalCalendarDay] = (0..<leadingBlankCount).map {
            TankJournalCalendarDay(id: "blank-leading-\($0)", date: nil)
        }

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(TankJournalCalendarDay(id: dayKey(for: date), date: date))
            }
        }

        let trailingBlankCount = (7 - days.count % 7) % 7
        days.append(contentsOf: (0..<trailingBlankCount).map {
            TankJournalCalendarDay(id: "blank-trailing-\($0)", date: nil)
        })

        return days
    }

    private var entriesByDay: [String: [TankJournalEntry]] {
        Dictionary(grouping: monthEntries) { entry in
            dayKey(for: entry.occurredAt)
        }
    }

    private var selectedEntries: [TankJournalEntry] {
        let selectedKey = dayKey(for: selectedDate)
        return (entriesByDay[selectedKey] ?? []).sorted { $0.occurredAt < $1.occurredAt }
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

    private func dayPartSection(_ dayPart: TankJournalDayPart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayPart.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let entries = selectedEntries.filter { entry in
                TankJournalDayPart(hour: calendar.component(.hour, from: entry.occurredAt)) == dayPart
            }

            if entries.isEmpty {
                Text("-")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    journalRow(entry)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func journalRow(_ entry: TankJournalEntry) -> some View {
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

    private func moveMonth(by value: Int) {
        let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        displayedMonth = monthStart(for: newMonth)
        selectedDate = displayedMonth
    }

    private func reloadMonth() {
        monthEntries = store.entries(for: sensor.sensorID, month: displayedMonth)
    }

    private func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func dayKey(for date: Date) -> String {
        Self.dayKeyFormatter.string(from: calendar.startOfDay(for: date))
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let selectedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy/MM/dd E"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct TankJournalCalendarDay: Identifiable {
    let id: String
    let date: Date?

    var dayKey: String {
        id
    }
}

private struct TankJournalCalendarDayCell: View {
    let day: TankJournalCalendarDay
    let entries: [TankJournalEntry]
    let isToday: Bool
    let isSelected: Bool
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        if let date = day.date {
            Button {
                onSelect(date)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption.weight(isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? .cyan : .primary)
                        Spacer()
                    }

                    HStack(spacing: 4) {
                        ForEach(distinctKinds, id: \.rawValue) { kind in
                            Image(systemName: kind.iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }

                        if overflowCount > 0 {
                            Text("+\(overflowCount)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 14, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(height: 68)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 1.4 : 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(height: 68)
        }
    }

    private var distinctKinds: [TankJournalKind] {
        TankJournalKind.allCases.filter { kind in
            entries.contains { $0.kind == kind }
        }
    }

    private var overflowCount: Int {
        max(0, entries.count - distinctKinds.count)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.cyan.opacity(0.14)
        }

        if !entries.isEmpty {
            return Color.primary.opacity(0.06)
        }

        return Color.primary.opacity(0.025)
    }

    private var borderColor: Color {
        if isSelected {
            return .cyan
        }

        if isToday {
            return Color.cyan.opacity(0.45)
        }

        return Color.primary.opacity(0.08)
    }
}

#Preview {
    TankJournalCalendarView(
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
        store: TankJournalStore(databasePath: ":memory:"),
        onClose: {}
    )
}
