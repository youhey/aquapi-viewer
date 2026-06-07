import SwiftUI

struct LivestockPreviewPopoverView: View {
    let tankName: String
    let items: [LivestockItem]
    let summary: LivestockSummary
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(tankName)の生体")
                .font(.headline)

            if items.isEmpty {
                Text("生体が登録されていません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(items) { item in
                            livestockRow(item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 280)
            }

            Divider()

            HStack {
                Text("合計 \(summary.speciesCount)種 / \(summary.totalCount)匹")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func livestockRow(_ item: LivestockItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                Spacer(minLength: 12)

                Text("\(max(0, item.count))匹")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            if !item.note.isEmpty {
                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    LivestockPreviewPopoverView(
        tankName: "増田川水槽",
        items: [
            LivestockItem(id: UUID(), name: "ヤマトヌマエビ", count: 5, note: "大きめ"),
            LivestockItem(id: UUID(), name: "サワガニ", count: 1, note: ""),
            LivestockItem(id: UUID(), name: "メダカ", count: 4, note: "白メダカ")
        ],
        summary: LivestockSummary(speciesCount: 3, totalCount: 10),
        onEdit: {}
    )
}
