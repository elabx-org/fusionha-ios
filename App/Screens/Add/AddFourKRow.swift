import SwiftUI
import FusionhaKit

/// The UHD card's 4K availability row. The check is manual: Check when idle,
/// ↻ after a result, Try again after an error. The best release's name shows
/// on a long press.
struct FourKRow: View {
    let flow: AddFlow
    @State private var showBest = false

    private enum RowState { case idle, checking, found, none, soon, error }

    private func plural(_ n: Int, _ one: String) -> String { "\(n) \(one)\(n == 1 ? "" : "s")" }

    private var rowState: RowState {
        switch flow.fourKStatus {
        case .idle: return .idle
        case .checking: return .checking
        case .error: return .error
        case .done:
            guard let r = flow.fourKResult else { return .error }
            if r.foundUhd == true { return .found }
            return flow.notOutYet(flow.timeline()) ? .soon : .none
        }
    }

    var body: some View {
        let state = rowState
        let r = flow.fourKResult
        let best = state == .found ? r?.bestReleaseName : nil
        Group {
            switch state {
            case .idle:
                AvailRow(tone: Theme.mut, icon: { Text("4K") }, title: Text("Not checked yet"),
                         sub: AnyView(availSub("See if a genuine 4K release exists before adding"))) {
                    Button { check() } label: {
                        Label("Check", systemImage: "magnifyingglass")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Theme.i2)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Theme.i2.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.i2.opacity(0.55)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            case .checking:
                AvailRow(tone: Theme.i2, icon: { ProgressView().controlSize(.mini).tint(Theme.i2) },
                         title: Text(flow.fourKLastCount.map { "Searching \(plural($0, "indexer"))…" } ?? "Searching your indexers…"),
                         sub: AnyView(availSub("Looking for genuine 2160p releases")), shimmer: true)
            case .found:
                let seasons = flow.isSeries ? (r?.seasonsSeen ?? []).compactMap { $0 } : []
                let meta = ([plural(r?.queriedIndexers ?? 0, "indexer")] + (seasons.isEmpty ? [] : [seasons.map { "S\($0)" }.joined(separator: ", ")]))
                    .joined(separator: " · ")
                let tags = r?.formatTags ?? []
                AvailRow(tone: Theme.done, icon: { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)) },
                         title: Text("Genuine 4K found ") + Text("· \(meta)").fontWeight(.medium).foregroundColor(Theme.mut),
                         sub: tags.isEmpty ? AnyView(availSub(best ?? "A genuine 2160p release")) : AnyView(tagLine(tags))) {
                    recheck("Check again")
                }
            case .none:
                let text = r?.dispatched == false && !(r?.message ?? "").isEmpty
                    ? (r?.message ?? "") : "\(plural(r?.queriedIndexers ?? 0, "indexer")) · only upscales found"
                AvailRow(tone: Theme.miss, icon: { Text("!") }, title: Text("No genuine 4K yet"), sub: AnyView(availSub(text))) {
                    recheck("Check again")
                }
            case .soon:
                AvailRow(tone: Theme.unaired, icon: { Image(systemName: "clock").font(.system(size: 13, weight: .bold)) },
                         title: Text("Not out yet"), sub: AnyView(availSub("4K will be searched on release"))) {
                    recheck("Check anyway")
                }
            case .error:
                AvailRow(tone: Theme.miss, icon: { Text("!") }, title: Text("Couldn’t check"),
                         sub: AnyView(availSub("The indexer search didn’t finish"))) {
                    Button("Try again") { check() }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Theme.i2)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Theme.i2.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.i2.opacity(0.55)))
                        .buttonStyle(PressScaleStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(best.map { "Best release: \($0)" } ?? "")
        .onLongPressGesture(minimumDuration: 0.45) { if best != nil { showBest = true } }
        .popover(isPresented: $showBest) {
            Text(best ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(.success, trigger: state == .found)
    }

    private func check() {
        Task { await flow.checkFourK() }
    }

    private func recheck(_ label: String) -> some View {
        Button { check() } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.txt.opacity(0.14)))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }

    /// The found row's CF chips: one line, clipped.
    /// As many chips as fit on the one line (dropping from the end), never
    /// wider than the card: fixed-size chips in a plain HStack forced the
    /// whole sheet wider than the screen.
    private func tagLine(_ tags: [FourKAvailabilityTag]) -> some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: tags.count, through: 1, by: -1)), id: \.self) { n in
                tagChips(Array(tags.prefix(n)))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func tagChips(_ tags: [FourKAvailabilityTag]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                let color = Self.tagColor(tag.kind)
                Text(tag.label)
                    .font(.system(size: 11, weight: .semibold, design: tag.kind == "group" ? .monospaced : .default))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.14), in: Capsule())
            }
        }
    }

    /// `FORMAT_TAG_COLOR`.
    private static func tagColor(_ kind: String?) -> Color {
        switch kind {
        case "quality": return Theme.grab
        case "hdr": return Theme.miss
        case "audio": return Theme.done
        case "group": return Theme.edition
        default: return Theme.mut
        }
    }
}
