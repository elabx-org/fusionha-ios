import SwiftUI
import FusionhaKit

/// My requests' "From source" filter (web `SourceChip` + `SourceDetails`,
/// fusionha 0.4.209 / 0.4.213): a glass chip with the number of automatic
/// requests; pressed, the provider segment (All automatic · Plex ·
/// Letterboxd), one chip per source of that provider and the note that
/// removing a title never cancels a request. Counts come from the UNFILTERED
/// `by_source` buckets, so they never shrink with the filter. Nothing shows
/// while the person has no automatic request and the filter is off.
struct RequestSourceFilterBar: View {
    let bySource: [RequestSourceCount]
    @Binding var value: RequestSourceFilter?

    var body: some View {
        let total = RequestSourceFilter.total(bySource)
        if total > 0 || value != nil {
            VStack(alignment: .leading, spacing: 10) {
                chip(total)
                if let current = value { details(current) }
            }
        }
    }

    private func chip(_ total: Int) -> some View {
        let on = value != nil
        return Button {
            value = on ? nil : RequestSourceFilter(provider: .all)
        } label: {
            HStack(spacing: 6) {
                RequestSourceGlyph(kind: "PLEX_LIST", size: 12)
                Text("From source").fontWeight(.semibold)
                Text("\(total)").foregroundStyle(Theme.mut)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .glassEffect(Self.glass(on), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show only requests from automatic sources")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private func details(_ current: RequestSourceFilter) -> some View {
        let subs = RequestSourceFilter.subs(bySource, provider: current.provider)
        Picker("Which provider", selection: Binding(get: { current.provider },
                                                     set: { value = RequestSourceFilter(provider: $0) })) {
            ForEach(RequestSourceFilter.Provider.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        if !subs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    subChip(current.provider.allTitle, count: nil, on: current.sub == nil) {
                        value = RequestSourceFilter(provider: current.provider)
                    }
                    ForEach(subs, id: \.self) { bucket in
                        let sub = RequestSourceFilter.Sub(bucket)
                        subChip(RequestSourceFilter.subLabel(bucket), count: bucket.count, on: current.sub == sub) {
                            value = RequestSourceFilter(provider: current.provider, sub: sub)
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        Label(RequestSourceFilter.note, systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subChip(_ title: String, count: Int?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title).fontWeight(.semibold).lineLimit(1)
                if let count { Text("\(count)").foregroundStyle(Theme.mut) }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(on ? Theme.txt : Theme.mut)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .glassEffect(Self.glass(on), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private static func glass(_ on: Bool) -> Glass {
        on ? Glass.regular.tint(Theme.i1.opacity(0.35)).interactive() : Glass.regular.interactive()
    }
}
