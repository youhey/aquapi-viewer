import SwiftUI

struct WaterSafetyStatusChipView: View {
    let status: WaterSafetyStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch status {
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

    private var backgroundColor: Color {
        foregroundColor.opacity(0.16)
    }
}

#Preview {
    HStack {
        WaterSafetyStatusChipView(status: .safety)
        WaterSafetyStatusChipView(status: .warning)
        WaterSafetyStatusChipView(status: .danger)
        WaterSafetyStatusChipView(status: .unknown)
    }
    .padding()
}
