import SwiftUI

struct LivestockEditorView: View {
    let tankName: String
    let initialItems: [LivestockItem]
    let onCancel: () -> Void
    let onSave: ([LivestockItem]) -> Void

    @State private var draftItems: [LivestockDraftItem]
    @State private var validationMessage: String?

    init(
        tankName: String,
        initialItems: [LivestockItem],
        onCancel: @escaping () -> Void,
        onSave: @escaping ([LivestockItem]) -> Void
    ) {
        self.tankName = tankName
        self.initialItems = initialItems
        self.onCancel = onCancel
        self.onSave = onSave
        _draftItems = State(initialValue: initialItems.map(LivestockDraftItem.init))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(tankName)の生体")
                .font(.title3.weight(.semibold))

            if draftItems.isEmpty {
                ContentUnavailableView(
                    "生体が登録されていません。",
                    systemImage: "fish",
                    description: Text("追加ボタンから生体名と匹数を登録できます。")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                livestockRows
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button {
                    addItem()
                } label: {
                    Label("追加", systemImage: "plus")
                }

                Spacer()

                Button("キャンセル") {
                    onCancel()
                }

                Button("保存") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 720)
        .frame(minHeight: 360)
        .onChange(of: draftItems) {
            validationMessage = validationError
        }
        .onAppear {
            validationMessage = validationError
        }
    }

    private var livestockRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("名前")
                    .frame(minWidth: 200, alignment: .leading)
                Text("数")
                    .frame(width: 80, alignment: .leading)
                Text("メモ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear
                    .frame(width: 28)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($draftItems) { $item in
                        HStack(alignment: .center, spacing: 10) {
                            TextField("生体名", text: $item.name)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 200)

                            TextField("0", text: $item.countText)
                                .textFieldStyle(.roundedBorder)
                                .monospacedDigit()
                                .frame(width: 80)

                            TextField("メモ", text: $item.note)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                removeItem(item.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("削除")
                            .frame(width: 28)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 160, maxHeight: 260)
        }
    }

    private var validationError: String? {
        for item in draftItems {
            if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "生体名を入力してください。"
            }

            guard let count = Int(item.countText.trimmingCharacters(in: .whitespacesAndNewlines)), count >= 0 else {
                return "匹数は0以上の整数で入力してください。"
            }
        }

        return nil
    }

    private var canSave: Bool {
        validationError == nil
    }

    private func addItem() {
        draftItems.append(LivestockDraftItem())
    }

    private func removeItem(_ id: UUID) {
        draftItems.removeAll { $0.id == id }
    }

    private func save() {
        guard validationError == nil else {
            validationMessage = validationError
            return
        }

        let items = draftItems.map {
            LivestockItem(
                id: $0.id,
                name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                count: Int($0.countText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                note: $0.note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        onSave(items)
    }
}

private struct LivestockDraftItem: Identifiable, Equatable {
    var id: UUID
    var name: String
    var countText: String
    var note: String

    init() {
        id = UUID()
        name = ""
        countText = "1"
        note = ""
    }

    nonisolated init(item: LivestockItem) {
        id = item.id
        name = item.name
        countText = String(max(0, item.count))
        note = item.note
    }
}

#Preview {
    LivestockEditorView(
        tankName: "増田川水槽",
        initialItems: [
            LivestockItem(id: UUID(), name: "ヤマトヌマエビ", count: 5, note: "大きめ"),
            LivestockItem(id: UUID(), name: "サワガニ", count: 1, note: "")
        ],
        onCancel: {},
        onSave: { _ in }
    )
}
