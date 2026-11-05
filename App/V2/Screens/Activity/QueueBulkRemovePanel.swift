import SwiftUI
import FusionhaKit

/// How the selected downloads leave the queue (mock queue `bulk`, v1's
/// `BulkRemoveDialog` options as one choice).
enum QueueBulkRemoveOption: String, CaseIterable, Identifiable {
    case deleteData, blocklist, keepData

    var id: String { rawValue }
    var deletesData: Bool { self == .deleteData || self == .blocklist }
    var blocklists: Bool { self == .blocklist }

    var title: String {
        switch self {
        case .deleteData: return "Remove from the client too"
        case .blocklist: return "Remove and blocklist the releases"
        case .keepData: return "Remove from the queue only"
        }
    }

    func detail(_ items: [QueueItem]) -> String {
        switch self {
        case .deleteData: return "The downloaded data is deleted"
        case .blocklist:
            let groups = Array(Set(items.compactMap { $0.parsed?.releaseGroup })).sorted()
            let who = groups.isEmpty ? "These releases" : ListFormatter.localizedString(byJoining: groups)
            return "\(who) \(groups.count == 1 ? "is" : "are") not grabbed again for these titles"
        case .keepData: return "Downloaded files stay on disk; nothing is blocklisted"
        }
    }

    func goLabel(_ count: Int) -> String {
        switch self {
        case .deleteData: return "Remove \(count) · delete their data"
        case .blocklist: return "Remove \(count) · blocklist releases"
        case .keepData: return "Remove \(count)"
        }
    }
}

/// The open Duo's right page in select mode (and the phone's Remove sheet):
/// "N selected", the chosen cards, then the three ways to remove them, with
/// the red commit button pinned under the panel.
struct QueueBulkRemovePanel: View {
    let items: [QueueItem]
    let telemetry: [Int: QueueTelemetry]
    let remove: (QueueBulkRemoveOption) async -> Bool
    let done: () -> Void
    /// Keep the files by default, as v1's bulk dialog does; deleting data
    /// is chosen on purpose and confirmed.
    @State private var option: QueueBulkRemoveOption = .keepData
    @State private var busy = false
    @State private var confirming = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(items.count) selected")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.txt)
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(Theme.mut)
                    .lineLimit(2)
                    .padding(.top, 3)
                ModuleRows {
                    ForEach(items.prefix(6)) { item in QueueCardV2(downloads: [item], telemetry: telemetry) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background { ModuleSurface() }
                .padding(.top, 14)
                Text("REMOVE \(items.count) FROM THE QUEUE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 18)
                    .accessibilityAddTraits(.isHeader)
                ForEach(QueueBulkRemoveOption.allCases) { row($0) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .goBarInset {
            GoBar(label: option.goLabel(items.count), systemImage: "trash", tone: .danger, busy: busy,
                  disabled: items.isEmpty) {
                if option.deletesData { confirming = true } else { commit() }
            }
        }
        .confirmationDialog(option.goLabel(items.count), isPresented: $confirming, titleVisibility: .visible) {
            Button(option.goLabel(items.count), role: .destructive) { commit() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(option.detail(items))
        }
    }

    private func commit() {
        busy = true
        Task {
            let ok = await remove(option)
            busy = false
            if ok { done() }
        }
    }

    /// "Wicked: For Good (HD and 4K) · VisionQuest S1 E7 HD".
    private var summary: String {
        items.prefix(4).map { [$0.title, $0.episodeLabel, $0.tier.badgeLetters].compactMap { $0 }.joined(separator: " ") }
            .joined(separator: " · ") + (items.count > 4 ? " and \(items.count - 4) more" : "")
    }

    private func row(_ value: QueueBulkRemoveOption) -> some View {
        let on = option == value
        return Button { option = value } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? Theme.primary : Theme.txt.opacity(0.35))
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(value.detail(items)).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.primary.opacity(on ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? Theme.primary : Theme.txt.opacity(0.12), lineWidth: on ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 7)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
