import SwiftUI
import FusionhaKit

/// Desktop Settings' Default profiles matrix (web `DefaultProfilesPanel`
/// `.table`, above 720): kind rows × tier columns, `120px 1fr 1fr` 14 apart,
/// each cell its quality profile and root folder menus. The phone shows a
/// section per kind instead.
struct DefaultProfilesTable: View {
    let kinds: [(String, String)]
    let tiers: [QualityTier]
    let unset: String
    let profiles: (String) -> [(Int, String)]
    let roots: [(Int, String)]
    let profile: (String, QualityTier) -> Binding<Int?>
    let root: (String, QualityTier) -> Binding<Int?>

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                Color.clear.frame(width: 120, height: 1)
                ForEach(tiers, id: \.self) { tier in
                    HStack(spacing: 6) {
                        Circle().fill(tier.color).frame(width: 7, height: 7)
                        Text(tier.chipLabel).font(.system(size: 12, weight: .bold)).foregroundStyle(tier.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                }
            }
            ForEach(kinds, id: \.0) { kind in
                Divider().overlay(Theme.line).gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text(kind.1)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.txt)
                        .frame(width: 120, alignment: .leading)
                        .padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(tiers, id: \.self) { tier in
                        cell(kind: kind, tier: tier)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func cell(kind: (String, String), tier: QualityTier) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            menu(title: "Quality profile", tag: "Add + Import", color: Theme.i2,
                 selection: profile(kind.0, tier), options: profiles(kind.0))
                .accessibilityLabel("Quality profile · \(kind.1) · \(tier.chipLabel)")
            menu(title: "Root folder", tag: "Add flow", color: Theme.edition,
                 selection: root(kind.0, tier), options: roots)
                .accessibilityLabel("Root folder · \(kind.1) · \(tier.chipLabel)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsField(tier == .hd ? "Quality profile" : "Root folder")
    }

    private func menu(title: String, tag: String, color: Color, selection: Binding<Int?>,
                      options: [(Int, String)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                DefaultProfilesTag(text: tag, color: color)
            }
            Picker(title, selection: selection) {
                Text(unset).tag(Int?.none)
                ForEach(options.indices, id: \.self) { i in
                    Text(options[i].1).tag(Int?.some(options[i].0))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .lineLimit(1)
            .tint(Theme.txt)
        }
    }
}
