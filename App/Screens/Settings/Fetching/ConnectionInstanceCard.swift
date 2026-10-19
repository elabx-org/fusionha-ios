import SwiftUI
import FusionhaKit

// MARK: Instance card

struct InstanceCard: View {
    let instance: VirtualInstance
    let roots: [RootFolder]
    let revealedKey: String?
    let copied: String?
    let onToggle: (Bool) -> Void
    let onRemapRoot: (Int) -> Void
    let onReveal: () -> Void
    let onHide: () -> Void
    let onCopyKey: () -> Void
    let onCopyURL: () -> Void
    let onRegenerate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var offeredRoots: [RootFolder] {
        guard let allowed = instance.allowedRootFolderIds, !allowed.isEmpty else { return roots }
        return roots.filter { allowed.contains($0.id) }
    }

    private var offered: (text: String, scoped: Bool) {
        guard let p = instance.allowedQualityProfileIds, let r = instance.allowedRootFolderIds else {
            return ("All profiles · all roots", false)
        }
        return ("\(p.count) profile\(p.count == 1 ? "" : "s") · \(r.count) root\(r.count == 1 ? "" : "s")", true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: instance.isRadarr ? "film" : "tv")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(instance.tier.color)
                    .frame(width: 40, height: 40)
                    .background(instance.tier.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(instance.tier.color.opacity(0.3)))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(instance.instanceName).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                        HStack(spacing: 5) {
                            Circle().fill(instance.enabled ? Theme.done : Theme.dim).frame(width: 6, height: 6)
                            Text(instance.enabled ? "Enabled" : "Disabled")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(instance.enabled ? Theme.done : Theme.mut)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background((instance.enabled ? Theme.done : Theme.dim).opacity(0.12), in: Capsule())
                    }
                    FetchFlow(spacing: 5, lineSpacing: 4) {
                        EditionChip(tier: instance.tier)
                        Text("·").foregroundStyle(Theme.dim)
                        Text(instance.kind == "movie" ? "Movies" : "Series")
                        if let scope = instance.scope, scope != "all" {
                            Text("·").foregroundStyle(Theme.dim)
                            FetchChip(text: scope == "anime" ? "Anime only" : "Non-anime", color: Theme.anime,
                                      border: Theme.anime.opacity(0.4))
                        }
                        Text("·").foregroundStyle(Theme.dim)
                        Text(instance.slug).font(.system(size: 11.5, design: .monospaced))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 0)
                Toggle("Enable \(instance.instanceName)", isOn: Binding(get: { instance.enabled }, set: onToggle))
                    .labelsHidden().tint(Theme.indigo)
            }

            field("API key") {
                valuePill(revealedKey ?? String(repeating: "•", count: 28) + (instance.apiKeyLast4 ?? ""),
                          secret: revealedKey == nil, copiedNow: copied == "\(instance.id):key",
                          copyLabel: "Copy key for \(instance.instanceName)", onCopy: onCopyKey) {
                    FetchIconButton(systemName: revealedKey == nil ? "eye" : "eye.slash",
                                    label: revealedKey == nil ? "Reveal key for \(instance.instanceName)"
                                        : "Hide key for \(instance.instanceName)",
                                    action: revealedKey == nil ? onReveal : onHide)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                field("Connect URL") {
                    valuePill("/\(instance.slug)", secret: false, copiedNow: copied == "\(instance.id):url",
                              copyLabel: "Copy connect URL for \(instance.instanceName)", onCopy: onCopyURL) { EmptyView() }
                }
                field("Root folder") {
                    Menu {
                        ForEach(offeredRoots) { root in
                            Button {
                                onRemapRoot(root.id)
                            } label: {
                                if root.id == instance.defaultRootFolderId {
                                    Label(root.path, systemImage: "checkmark")
                                } else {
                                    Text(root.path)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(roots.first { $0.id == instance.defaultRootFolderId }?.path ?? "Root folder")
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 2)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    }
                    .accessibilityLabel("Root folder for \(instance.instanceName)")
                }
            }
            field("Offered to Overseerr") {
                Button(action: onEdit) {
                    HStack(spacing: 8) {
                        Circle().fill(offered.scoped ? Theme.miss : Theme.done).frame(width: 7, height: 7)
                        Text(offered.text).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Spacer()
                        Image(systemName: "slider.horizontal.3").font(.system(size: 13)).foregroundStyle(Theme.mut)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                    .background((offered.scoped ? Theme.miss : Theme.done).opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Offer limits for \(instance.instanceName): \(offered.text)")
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 4) {
                Text(instance.isRadarr ? "Radarr" : "Sonarr").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                Spacer()
                Button(action: onRegenerate) { Label("Regenerate key", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.web())
                    .accessibilityLabel("Regenerate key for \(instance.instanceName)")
                FetchIconButton(systemName: "pencil", label: "Edit \(instance.instanceName)", action: onEdit)
                FetchIconButton(systemName: "trash", label: "Delete \(instance.instanceName)", danger: true, action: onDelete)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(instance.tier.color, radius: 14)
        .opacity(instance.enabled ? 1 : 0.75)
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(0.6).foregroundStyle(Theme.dim)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valuePill<A: View>(_ display: String, secret: Bool, copiedNow: Bool, copyLabel: String,
                                    onCopy: @escaping () -> Void, @ViewBuilder accessory: () -> A) -> some View {
        HStack(spacing: 0) {
            Text(display)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(secret ? Theme.mut : Theme.txt)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.leading, 10)
            Spacer(minLength: 4)
            accessory()
            FetchIconButton(systemName: copiedNow ? "checkmark" : "doc.on.doc", label: copyLabel,
                            tint: copiedNow ? Theme.done : nil, action: onCopy)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(height: 36)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
    }
}
