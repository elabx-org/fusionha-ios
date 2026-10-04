import SwiftUI
import FusionhaKit

/// First cut of Calendar: the agenda for the next two weeks. Month / Week / Day
/// views and the "Subscribe in Calendar" action follow the plan.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var entries: [CalendarEntry] = []
    @State private var error: String?

    private var days: [(String, [CalendarEntry])] {
        Dictionary(grouping: entries, by: \.date).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(days, id: \.0) { day, items in
                    Section(Self.dayTitle(day)) {
                        ForEach(items, id: \.self) { CalendarRow(entry: $0) }
                    }
                }
            }
            .navigationTitle("Calendar")
            .refreshable { await load() }
            .overlay {
                if entries.isEmpty {
                    if let error {
                        ContentUnavailableView("Couldn't load the calendar", systemImage: "wifi.exclamationmark", description: Text(error))
                    } else {
                        ContentUnavailableView("Nothing in the next two weeks", systemImage: "calendar")
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
            .task { await load() }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start
        do {
            entries = try await client.calendar(start: start, end: end)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    static func dayTitle(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(iso.prefix(10))) else { return iso }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).day().month())
    }
}

struct CalendarRow: View {
    let entry: CalendarEntry

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w92"))
                .frame(width: 32, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(entry.editions, id: \.editionId) { EditionChip(tier: $0.tier, status: $0.status) }
            }
        }
    }

    private var subtitle: String {
        if entry.mediaKind == .movie { return (entry.type).capitalized }
        var parts: [String] = []
        if let s = entry.seasonNumber, let e = entry.episodeNumber {
            parts.append(String(format: "S%02dE%02d", s, e))
        }
        if entry.isAnime, let abs = entry.absoluteNumber { parts.append("#\(abs)") }
        if let t = entry.episodeTitle { parts.append(t) }
        return parts.joined(separator: " · ")
    }
}
