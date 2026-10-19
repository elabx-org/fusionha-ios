import SwiftUI
import FusionhaKit

/// One root's card, stacked like the web's mobile layout: identity, usage, actions.
struct RootFolderCard: View {
    let folder: RootFolderInfo
    let defaultsReady: Bool
    let saving: Bool
    let onToggleDefault: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let kindLabel = ["movie": "Movies", "series": "Series", "anime": "Anime"]

    private var kindLabel: String { Self.kindLabel[folder.inferredKind] ?? "Movies" }
    private var isDefaultHere: Bool {
        folder.defaultFor?.contains { $0.profileKind == folder.inferredKind && $0.tier == folder.inferredTier } == true
    }
    private var pct: Int? {
        guard let total = folder.totalSpace, total > 0, let used = folder.usedSpace else { return nil }
        return min(100, Int((Double(used) / Double(total) * 100).rounded()))
    }
    private var editions: Int { folder.trackedEditions ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 17))
                    .foregroundStyle(folder.online ? Theme.mut : Theme.stuck)
                    .frame(width: 42, height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
                VStack(alignment: .leading, spacing: 8) {
                    FetchFlow(spacing: 8, lineSpacing: 6) {
                        Text(folder.path)
                            .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        FetchTierChip(tier: folder.inferredTier)
                        FetchChip(text: kindLabel)
                        ForEach(folder.defaultFor ?? [], id: \.self) { slot in
                            Text("Default · \(Self.kindLabel[slot.profileKind] ?? slot.profileKind) · \(slot.tier.pill)".uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(0.2)
                                .foregroundStyle(Theme.done)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Theme.done.opacity(0.14), in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.done.opacity(0.36)))
                                .fixedSize()
                        }
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(folder.online ? Theme.done : Theme.stuck)
                                .frame(width: 7, height: 7)
                                .background(Circle().fill((folder.online ? Theme.done : Theme.stuck).opacity(0.16)).padding(-3))
                            Text(folder.online ? "Online" : "Offline · not reachable")
                                .font(.system(size: 11))
                                .foregroundStyle(folder.online ? Theme.mut : Theme.stuck)
                        }
                        Text(folder.importMode.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line))
                    }
                }
            }

            usage

            HStack(spacing: 7) {
                Spacer()
                actionButton(systemName: isDefaultHere ? "star.fill" : "star",
                             label: isDefaultHere ? "Clear default for \(kindLabel) · \(folder.inferredTier.pill)"
                                : "Set \(folder.path) as default for \(kindLabel) · \(folder.inferredTier.pill)",
                             tint: isDefaultHere ? Theme.done : Theme.dim, highlighted: isDefaultHere) {
                    onToggleDefault(!isDefaultHere)
                }
                .disabled(!defaultsReady || saving)
                actionButton(systemName: "pencil", label: "Edit \(folder.path)", action: onEdit)
                actionButton(systemName: "trash", label: "Delete \(folder.path)", tint: Theme.danger.opacity(0.85), action: onDelete)
            }
        }
        .fetchCard(padding: 13, radius: 14, border: folder.online ? Theme.line : Theme.stuck.opacity(0.4))
    }

    @ViewBuilder
    private var usage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if !folder.online {
                    Text("Mount not responding").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.stuck)
                    Spacer(minLength: 4)
                    mono("\(editions) versions")
                } else if let total = folder.totalSpace, let used = folder.usedSpace {
                    Text(FetchFormat.bytes(used)).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                    Text("used").font(.system(size: 12)).foregroundStyle(Theme.txt)
                    Spacer(minLength: 4)
                    mono((folder.freeSpace.map { "\(FetchFormat.bytes($0)) free · " } ?? "") + FetchFormat.bytes(total))
                } else {
                    Text("—").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("size not reported").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 4)
                    mono("\(editions) versions")
                }
            }
            .padding(.bottom, 7)

            diskBar

            HStack {
                if folder.online, let pct {
                    Text("\(editions) \(editions == 1 ? "version" : "versions") tracked here\(pct >= 90 ? " · running low" : "")")
                    Spacer()
                    Text("\(pct)%").foregroundStyle(pct >= 75 ? Theme.miss : Theme.dim)
                } else if folder.online {
                    Text("symlinks → mount target")
                    Spacer()
                } else {
                    Text("files show as not-found until it returns").foregroundStyle(Theme.stuck)
                    Spacer()
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Theme.dim)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var diskBar: some View {
        if !folder.online {
            FetchBar(fraction: 1, color: Theme.stuck.opacity(0.22))
        } else if let pct {
            FetchBar(fraction: max(4, Double(pct)) / 100,
                     color: pct >= 90 ? Theme.stuck : pct >= 75 ? Theme.miss : Theme.grab)
        } else {
            // Unreported mount → hatched, never a fake percentage.
            Capsule()
                .fill(Theme.txt.opacity(0.07))
                .overlay(
                    HStack(spacing: 6) {
                        ForEach(0..<60, id: \.self) { _ in
                            Rectangle().fill(Theme.grab.opacity(0.35)).frame(width: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                )
                .clipShape(Capsule())
                .frame(height: 8)
        }
    }

    private func mono(_ text: String) -> some View {
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut).lineLimit(1)
    }

    private func actionButton(systemName: String, label: String, tint: Color = Theme.dim,
                              highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(highlighted ? Theme.done.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(highlighted ? Theme.done.opacity(0.4) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
