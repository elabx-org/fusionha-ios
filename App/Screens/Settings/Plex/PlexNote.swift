import SwiftUI
import FusionhaKit

/// One ambient-wash note (web `PlexNote`): an icon in the cue colour, a bold
/// title and a muted second line. Status is the wash, never a border.
struct PlexNote: View {
    let color: Color
    let symbol: String
    var title: String?
    var text: String?
    var spinning = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if spinning {
                    ProgressView().controlSize(.small).tint(color)
                } else {
                    Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                }
            }
            .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                }
                if let text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: title == nil ? 13 : 12))
                        .foregroundStyle(title == nil ? Theme.txt : Theme.mut)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A dot + status line on a wash (web `.status`): the connection status, the
/// "Using …" summary, "Active since …".
struct PlexStatusLine<Trailing: View>: View {
    let color: Color
    let text: String
    var meta: String?
    var live = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(color).frame(width: 8, height: 8)
                .opacity(live ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                if let meta, !meta.isEmpty {
                    Text(meta).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

extension PlexStatusLine where Trailing == EmptyView {
    init(color: Color, text: String, meta: String? = nil, live: Bool = false) {
        self.init(color: color, text: text, meta: meta, live: live) { EmptyView() }
    }
}

/// A small tinted chip (library state, type, "manual").
struct PlexChip: View {
    let text: String
    var color: Color = Theme.mut

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

/// The copy action next to an address.
struct PlexCopyButton: View {
    let uri: String
    var label = "Copy full address"
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(label, systemImage: "doc.on.doc") {
            UIPasteboard.general.string = uri
            model.toast("Address copied")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(Theme.mut)
    }
}

enum PlexColors {
    static func state(_ s: PlexLibraryState) -> Color {
        switch s {
        case .uhd: return QualityTier.uhd.color
        case .suggested: return Theme.stuck
        case .notuhd, .gone: return Theme.dim
        }
    }

    static func bucket(_ tone: PlexBucketID.Tone) -> Color {
        switch tone {
        case .uhd: return QualityTier.uhd.color
        case .hd: return QualityTier.hd.color
        case .accent: return Theme.i1
        case .dim: return Theme.dim
        }
    }

    static func tail(_ s: PlexConnectionLabels.TailState) -> Color {
        switch s {
        case .ok: return Theme.done
        case .fail: return Theme.danger
        case .wait: return Theme.dim
        }
    }
}
