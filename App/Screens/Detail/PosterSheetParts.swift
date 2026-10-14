import SwiftUI

// MARK: - Action sheet parts (ui/ActionSheet.module.css, redesign `.msheet`)
//
// The poster sheet sits on the system's glass sheet; its rows are grouped in
// a quiet rounded block (`.ps-list`), split by hairlines, with the cream
// primary (`.ps-primary`) above them.

/// A grouped block of sheet rows.
struct SheetList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(Theme.panel2.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.top, 2)
            .padding(.bottom, 4)
    }
}

/// The hairline between two rows of a group, inset past the glyph column.
struct SheetSeparator: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
            .padding(.leading, 14)
    }
}

struct SheetGroupLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.dim)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }
}

/// A drilled page: `‹ Back` + title, an optional caption, then its rows.
struct SheetPage<Content: View>: View {
    let title: String
    var caption: String?
    let back: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: back) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                        Text("Back").font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Theme.txt)
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .frame(height: 36)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassControl()
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
            }
            .padding(.bottom, 8)
            if let caption {
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .padding(.bottom, 8)
            }
            content
        }
    }
}

/// The cream primary action (`.ps-primary`): full width, house light, dark text.
struct SheetPrimaryButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Theme.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.fusion, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
            .contentShape(Capsule())
        }
        .buttonStyle(SheetPrimaryStyle())
    }
}

/// Press dims and settles the primary a touch (no scale under Reduce Motion).
struct SheetPrimaryStyle: ButtonStyle {
    @Environment(\.motionEnabled) private var motion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && motion ? 0.98 : 1)
            .animation(motion ? .easeOut(duration: 0.15) : nil, value: configuration.isPressed)
    }
}

/// A row with a switch (Monitor), same metrics and entrance as `SheetRow`.
struct SheetToggleRow: View {
    @Environment(\.motionEnabled) private var motion
    let index: Int
    let label: String
    let icon: String
    @Binding var isOn: Bool
    @State private var shown = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 26)
                Text(label).font(.system(size: 16))
            }
            .foregroundStyle(Theme.txt)
        }
        .tint(Theme.indigo)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .opacity(shown || !motion ? 1 : 0)
        .offset(y: shown || !motion ? 0 : 6)
        .onAppear {
            guard motion, !shown else { return }
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.24).delay(Double(min(index, 10)) * 0.018 + 0.04)) {
                shown = true
            }
        }
    }
}

struct SheetRow: View {
    enum Tone { case normal, primary, danger, recommended }

    @Environment(\.motionEnabled) private var motion
    let index: Int
    let label: String
    var detail: String?
    var icon: String?
    var tone: Tone = .normal
    var hint: String?
    var chevron = false
    let action: () -> Void
    @State private var shown = false

    private var color: Color {
        switch tone {
        case .primary: return Theme.i2
        case .danger: return Theme.danger
        default: return Theme.txt
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .regular))
                        .frame(width: 26)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 16))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundStyle(tone == .recommended ? Theme.miss : Theme.mut)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                }
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(SheetRowStyle())
        // Rows rise in with a short stagger (off under Reduce Motion).
        .opacity(shown || !motion ? 1 : 0)
        .offset(y: shown || !motion ? 0 : 6)
        .onAppear {
            guard motion, !shown else { return }
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.24).delay(Double(min(index, 10)) * 0.018 + 0.04)) {
                shown = true
            }
        }
    }
}

/// The pressed row lights up in place (rows are content inside the group).
struct SheetRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.07 : 0))
    }
}
