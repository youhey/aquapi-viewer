import SwiftUI

struct StatusChipView: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .monospaced()
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
    }

    private var normalizedStatus: String {
        status.lowercased()
    }

    private var label: String {
        switch normalizedStatus {
        case "ok":
            "OK"
        case "low":
            "LOW"
        case "high":
            "HIGH"
        case "error":
            "ERR"
        default:
            "UNK"
        }
    }

    private var foregroundColor: Color {
        switch normalizedStatus {
        case "ok":
            .green
        case "low":
            .blue
        case "high":
            .orange
        case "error":
            .red
        default:
            .gray
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.16)
    }
}

#Preview {
    HStack {
        StatusChipView(status: "ok")
        StatusChipView(status: "low")
        StatusChipView(status: "high")
        StatusChipView(status: "unknown")
        StatusChipView(status: "error")
    }
    .padding()
}
