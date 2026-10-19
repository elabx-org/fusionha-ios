import SwiftUI
import FusionhaKit

/// One inset grouped list (Final mock): a single rounded card with hairlines
/// between rows, instead of a card per row.
struct RequestsGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 64) }
                    row
                }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A grouped list's section label: a stage dot (optional), the name, its
/// count, and quiet facts ("· all by eafx · oldest 5d").
struct RequestsSectionHeader: View {
    let title: String
    var count: Int?
    var dot: Color?
    var facts: String?

    var body: some View {
        HStack(spacing: 7) {
            if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
            if let count {
                Text(verbatim: "\(count)").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.txt)
            }
            if let facts, !facts.isEmpty {
                Text("· \(facts)").font(.system(size: 13)).foregroundStyle(Theme.dim).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        .padding(.bottom, 7)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One row: poster, "Title 2026", a meta line, and an optional trailing
/// detail (History's time). `compact` is the filter sheet's density.
struct RequestsListRow<Meta: View, Trailing: View>: View {
    let request: MediaRequest
    var compact = false
    @ViewBuilder var meta: () -> Meta
    @ViewBuilder var trailing: () -> Trailing

    init(request: MediaRequest, compact: Bool = false,
         @ViewBuilder meta: @escaping () -> Meta,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.request = request
        self.compact = compact
        self.meta = meta
        self.trailing = trailing
    }

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        HStack(spacing: 12) {
            if !compact {
                ActPoster(url: request.poster, title: title, size: .sm)
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                (Text(title).fontWeight(.semibold).foregroundColor(Theme.txt)
                 + Text(verbatim: request.year.map { " \($0)" } ?? "").foregroundColor(Theme.dim))
                    .font(.system(size: 15))
                    .lineLimit(1)
                meta()
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 8 : 8)
        .frame(minHeight: compact ? 52 : 70)
        .background(Theme.card)
        .contentShape(Rectangle())
    }
}

/// "Show all 9" as a group's last row.
struct RequestsShowAllRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accentText)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Theme.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
