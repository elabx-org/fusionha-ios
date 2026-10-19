import SwiftUI
import FusionhaKit

/// Browse's own controls (Proposal 2, approved 2026-10-19): the kind lens,
/// the TMDB search (or a requester's search field) and "Add as". They sit
/// inside Browse, under the Browse | Requests tabs, since none of them
/// touches Requests.
struct DiscoverBrowseControls: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var kind: SearchKind
    @Binding var query: String
    let canAdd: Bool
    let canRequest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phone: four equal segments across the width (the web's ≤720 grid).
            DiscoverSegmented(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, size: .md,
                              fill: sizeClass != .regular)
                .padding(.bottom, 14)
            if canAdd {
                Button { model.openAdd(nil, providerOverride: DiscoverSession.shared.providerOverride) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold))
                        Text("Search TMDB to add movies, series & anime…")
                            .font(.system(size: 14.5))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: 560, minHeight: 44, alignment: .leading)
                    .background(DiscoverPalette.well, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search TMDB to add movies, series and anime")
                DiscoverAddAsControl()
                    .padding(.top, 8)
            } else if canRequest {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.mut)
                    TextField("", text: $query, prompt: Text("Search movies & shows to request…").foregroundStyle(Theme.mut))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.txt)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                                .frame(width: 24, height: 24)
                                .background(Theme.txt.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                    }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: 560, minHeight: 44)
                .background(DiscoverPalette.well, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            }
        }
        .padding(.bottom, 22)
    }
}
