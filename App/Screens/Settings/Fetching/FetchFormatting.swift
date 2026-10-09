import SwiftUI
import FusionhaKit

// Formatting and layout helpers shared by the native card-list Settings panels.

// MARK: Formatting

enum FetchFormat {
    /// Parses the server's timestamps: ISO-8601 with or without a zone and fraction
    /// (naive values are UTC, like the web's `parseServerDate`).
    static func date(_ iso: String?) -> Date? {
        Format.timestamp(iso)
    }

    /// `just now` / `5m ago` / `3h ago` / `2d ago`.
    static func ago(_ iso: String?, now: Date = .now) -> String {
        guard let date = date(iso) else { return "never" }
        let secs = max(0, Int(now.timeIntervalSince(date).rounded()))
        if secs < 60 { return "just now" }
        let mins = Int((Double(secs) / 60).rounded())
        if mins < 60 { return "\(mins)m ago" }
        let hrs = Int((Double(mins) / 60).rounded())
        if hrs < 24 { return "\(hrs)h ago" }
        return "\(Int((Double(hrs) / 24).rounded()))d ago"
    }

    /// The web's `formatBytes`: `512 B`, `1.5 KB`, `42 GB`, `1.2 TB`.
    static func bytes(_ value: Int?) -> String {
        guard let value else { return "—" }
        if value < 1024 { return "\(value) B" }
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var v = Double(value) / 1024
        var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return String(format: v >= 100 ? "%.0f %@" : "%.1f %@", v, units[i])
    }

    static func grouped(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }
}

// MARK: Layout

/// A wrapping row (CSS `flex-wrap: wrap`) for chips and badges.
struct FetchFlow: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += line + lineSpacing
                x = 0
                line = 0
            }
            x += (x > 0 ? spacing : 0) + size.width
            widest = max(widest, x)
            line = max(line, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += line + lineSpacing
                x = bounds.minX
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

/// A rounded progress track whose fill grows in on appear (`transition: width .5s`).
struct FetchBar: View {
    let fraction: Double
    var color: Color = Theme.grab
    var height: CGFloat = 8
    var track: Color = Color.white.opacity(0.07)
    var delay: Double = 0
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(motionOff || shown ? fraction : 0, 0), 1)))
            }
        }
        .frame(height: height)
        .onAppear {
            guard !motionOff else { return }
            withAnimation(.easeOut(duration: 0.5).delay(delay)) { shown = true }
        }
    }
}
