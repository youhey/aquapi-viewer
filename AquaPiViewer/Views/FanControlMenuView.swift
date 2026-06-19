import SwiftUI

struct FanControlMenuView: View {
    let mode: FanMode
    let state: FanState
    let reason: String?
    let isInProgress: Bool
    let onSelectMode: (FanMode) -> Void

    private var isControllable: Bool {
        state != .disabled && mode != .disabled && !isInProgress
    }

    var body: some View {
        Menu {
            Text("Fan Control")
            Divider()

            Button {
                onSelectMode(.auto)
            } label: {
                Label(menuTitle("Auto", for: .auto), systemImage: FanMode.auto.iconName)
            }

            Button {
                onSelectMode(.manualOn)
            } label: {
                Label(menuTitle("Turn On", for: .manualOn), systemImage: FanMode.manualOn.iconName)
            }

            Button {
                onSelectMode(.manualOff)
            } label: {
                Label(menuTitle("Turn Off", for: .manualOff), systemImage: FanMode.manualOff.iconName)
            }
        } label: {
            Group {
                if isInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            .frame(width: 42, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isControllable)
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private var helpText: String {
        var text = "Fan \(mode.label)"
        if let reason, !reason.isEmpty {
            text += " - \(reason)"
        }
        return text
    }

    private var iconColor: Color {
        switch mode {
        case .auto:
            state == .on ? .blue : .gray
        case .manualOn:
            .orange
        case .manualOff:
            .red
        case .unknown:
            .gray
        case .disabled:
            .gray.opacity(0.5)
        }
    }

    private func menuTitle(_ title: String, for targetMode: FanMode) -> String {
        mode == targetMode ? "✓ \(title)" : title
    }
}

#Preview {
    HStack(spacing: 16) {
        FanControlMenuView(
            mode: .auto,
            state: .on,
            reason: "temperature_above_start",
            isInProgress: false,
            onSelectMode: { _ in }
        )
        FanControlMenuView(
            mode: .manualOn,
            state: .on,
            reason: "manual_on",
            isInProgress: false,
            onSelectMode: { _ in }
        )
        FanControlMenuView(
            mode: .manualOff,
            state: .off,
            reason: "manual_off",
            isInProgress: false,
            onSelectMode: { _ in }
        )
    }
    .padding()
}
