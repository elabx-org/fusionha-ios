import SwiftUI
import FusionhaKit

/// One download client on a W1 card (mock `.s2-cc`): its logo tile, name,
/// mono address and switch; the category per kind ("Movies → fusionha-
/// movies"); the verified line with its priority; then Test, Edit and
/// Delete. A test result shows under the header.
struct V2DownloadClientCard: View {
    let client: DownloadClientInfo
    let result: ConnectionTestResult?
    let testing: Bool
    let onToggle: (Bool) -> Void
    let onTest: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.pagePalette) private var page

    private static let kinds: [(key: String, label: String)] = [("movie", "Movies"), ("series", "Series"), ("anime", "Anime")]

    private var address: String {
        let base = (client.urlBase ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return "\(client.host):\(String(client.port))" + (base.isEmpty ? "" : "/\(base)")
    }

    private struct Category: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private var categories: [Category] {
        Self.kinds.compactMap { kind in
            guard let value = client.categoryMap?[kind.key], !value.isEmpty else { return nil }
            return Category(label: kind.label, value: value)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            if testing || result != nil { testLine }
            if !categories.isEmpty { chips }
            V2ClientVerifiedLine(client: client)
            actions
        }
        .v2CardStyle(padding: 15)
        .opacity(client.enable == false ? 0.72 : 1)
    }

    private var header: some View {
        HStack(spacing: 11) {
            FetchLogoTile(image: ServiceLogo.downloadClient(name: client.name, host: client.host, isTorrent: client.isTorrent),
                          size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                Text(address)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Toggle("Enable \(client.name)", isOn: Binding(get: { client.enable != false }, set: onToggle))
                .labelsHidden()
                .tint(Theme.indigo)
        }
    }

    @ViewBuilder
    private var testLine: some View {
        if testing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.mini)
                Text("Testing…").font(.footnote).foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
        } else if let result {
            VStack(alignment: .leading, spacing: 4) {
                FetchPill(text: result.ok ? "Connected" : "Failed", tone: result.ok ? .ok : .err)
                if !result.ok {
                    Text(result.message)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .lineLimit(3)
                }
            }
        }
    }

    private var chips: some View {
        PreviewFlow(spacing: 6, rowSpacing: 6) {
            ForEach(categories) { cat in
                (Text(cat.label).foregroundStyle(page?.ink ?? Theme.txt)
                    + Text(" → \(cat.value)").foregroundStyle(page?.inkMuted ?? Theme.mut))
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((page?.ink ?? Theme.txt).opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("\(cat.label) category \(cat.value)")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onTest) {
                Label("Test", systemImage: "bolt").frame(height: 22)
            }
            .disabled(testing)
            .accessibilityLabel("Test \(client.name)")
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil").frame(height: 22)
            }
            .accessibilityLabel("Edit \(client.name)")
            Button(action: onDelete) {
                Image(systemName: "trash").frame(height: 22)
            }
            .tint(Theme.danger)
            .accessibilityLabel("Delete \(client.name)")
            Spacer(minLength: 0)
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}
