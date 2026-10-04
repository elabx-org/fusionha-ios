import SwiftUI
import FusionhaKit

enum CalendarMode: Hashable {
    case month, agenda
}

/// The web's Calendar page: month title, kind chips, Month / Agenda views,
/// prev / Today / next, the status legend and the month grid.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var anchor = Calendar.current.startOfDay(for: .now)
    @State private var mode: CalendarMode = .month
    @State private var kind: KindBucket?
    @State private var entries: [CalendarEntry] = []
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: .now)
    @State private var error: String?

    private var calendar: Calendar { Calendar.current }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
    }

    private var range: (Date, Date) {
        switch mode {
        case .month:
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
            return (monthStart, end)
        case .agenda:
            let start = calendar.startOfDay(for: anchor)
            return (start, calendar.date(byAdding: .day, value: 30, to: start) ?? start)
        }
    }

    private var visible: [CalendarEntry] {
        entries.filter { entry in
            guard let kind else { return true }
            let bucket: KindBucket = entry.isAnime ? .anime : (entry.mediaKind == .movie ? .movie : .series)
            return bucket == kind
        }
    }

    private var byDay: [Date: [CalendarEntry]] {
        Dictionary(grouping: visible) { Format.day($0.date) ?? .distantPast }
    }

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: title, subtitle: subtitle, stacked: true)
                    kindChips
                    SegmentedPills(options: [(CalendarMode.month, "Month"), (.agenda, "Agenda")],
                                   selection: $mode, style: .plain)
                    navigation
                    legend
                    switch mode {
                    case .month:
                        MonthGrid(month: monthStart, byDay: byDay, selected: $selectedDay)
                        dayList
                    case .agenda:
                        agenda
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .refreshable { await load() }
        }
        .task(id: "\(range.0.timeIntervalSince1970)|\(mode)") { await load() }
    }

    private var title: String {
        switch mode {
        case .month: return monthStart.formatted(.dateTime.month(.wide).year())
        case .agenda: return "Agenda"
        }
    }

    private var subtitle: String {
        let today = byDay[calendar.startOfDay(for: .now)]?.count ?? 0
        return "\(visible.count) scheduled · \(today) today"
    }

    private var kindChips: some View {
        HStack(spacing: 8) {
            chip("All", nil)
            chip("Series", .series)
            chip("Movies", .movie)
            chip("Anime", .anime)
        }
    }

    private func chip(_ label: String, _ value: KindBucket?) -> some View {
        Button {
            withAnimation(.snappy) { kind = value }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(kind == value ? Theme.txt : Theme.mut)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(kind == value ? Theme.indigo.opacity(0.22) : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(kind == value ? Theme.indigo.opacity(0.7) : Theme.line))
        }
        .buttonStyle(.plain)
    }

    private var navigation: some View {
        HStack(spacing: 14) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 34, height: 34)
            }
            .accessibilityLabel("Previous")
            Button {
                withAnimation(.snappy) {
                    anchor = calendar.startOfDay(for: .now)
                    selectedDay = anchor
                }
            } label: {
                Text("Today").font(.system(size: 15, weight: .bold)).padding(.horizontal, 14).frame(height: 36)
                    .panel(Theme.panel, radius: 10)
            }
            Button { step(1) } label: {
                Image(systemName: "chevron.right").frame(width: 34, height: 34)
            }
            .accessibilityLabel("Next")
            Spacer()
            if let server = model.credentials?.serverURL {
                Link(destination: server.appendingPathComponent("calendar")) {
                    Label("iCal feed", systemImage: "calendar.badge.plus")
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.txt)
    }

    private func step(_ direction: Int) {
        withAnimation(.snappy) {
            switch mode {
            case .month: anchor = calendar.date(byAdding: .month, value: direction, to: monthStart) ?? anchor
            case .agenda: anchor = calendar.date(byAdding: .day, value: 30 * direction, to: anchor) ?? anchor
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("Downloaded", Theme.done)
            legendItem("Downloading", Theme.grab)
            legendItem("Missing", Theme.miss)
            legendItem("Unaired", Theme.unaired)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.mut)
    }

    private func legendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label).lineLimit(1)
        }
    }

    @ViewBuilder
    private var dayList: some View {
        if let day = selectedDay {
            let items = byDay[day] ?? []
            VStack(alignment: .leading, spacing: 10) {
                EyebrowLabel(text: day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                if items.isEmpty {
                    Text("Nothing scheduled.").font(.system(size: 14)).foregroundStyle(Theme.mut)
                }
                ForEach(items, id: \.self) { entry in
                    CalendarRow(entry: entry).onTapGesture { model.open(entry.itemId) }
                }
            }
        }
    }

    @ViewBuilder
    private var agenda: some View {
        let days = byDay.keys.sorted()
        if days.isEmpty {
            EmptyBox(message: error == nil ? "Nothing scheduled in the next 30 days." : "The calendar could not be loaded.")
        }
        ForEach(days, id: \.self) { day in
            VStack(alignment: .leading, spacing: 10) {
                EyebrowLabel(text: Self.dayTitle(day), color: calendar.isDateInToday(day) ? Theme.cyan : Theme.dim)
                ForEach(byDay[day] ?? [], id: \.self) { entry in
                    CalendarRow(entry: entry).onTapGesture { model.open(entry.itemId) }
                }
            }
        }
    }

    static func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).day().month())
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            entries = try await client.calendar(start: range.0, end: range.1)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension CalendarEntry {
    /// The colour of the most relevant monitored edition.
    var statusColor: Color {
        let monitored = editions.filter(\.monitored)
        return (monitored.first ?? editions.first)?.status.color ?? Theme.unmonitored
    }
}

/// The web's month grid: weekday header, rounded day cells, today in cyan.
private struct MonthGrid: View {
    let month: Date
    let byDay: [Date: [CalendarEntry]]
    @Binding var selected: Date?

    private var calendar: Calendar { Calendar.current }

    private var cells: [Date?] {
        guard let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in days {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return result
    }

    private var weekdays: [String] {
        let symbols = calendar.shortWeekdaySymbols.map { $0.uppercased() }
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                }
            }
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        cell(date)
                    } else {
                        Color.clear.frame(height: 72)
                    }
                }
            }
        }
    }

    private func cell(_ date: Date) -> some View {
        let today = calendar.isDateInToday(date)
        let isSelected = selected == date
        let items = byDay[date] ?? []
        return Button {
            withAnimation(.snappy) { selected = date }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(today ? Theme.cyan : Theme.mut)
                ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, entry in
                    Capsule().fill(entry.statusColor).frame(height: 4)
                }
                if items.count > 3 {
                    Text("+\(items.count - 3)").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .background(isSelected ? Theme.indigo.opacity(0.14) : Color(hex: 0x10121A),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(today ? Theme.cyan.opacity(0.6) : (isSelected ? Theme.indigo.opacity(0.6) : Theme.line),
                              lineWidth: today ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(items.count) scheduled")
    }
}

struct CalendarRow: View {
    let entry: CalendarEntry

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w92"))
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(entry.editions, id: \.editionId) { edition in
                    HStack(spacing: 5) {
                        Circle().fill(edition.status.color).frame(width: 7, height: 7)
                        TierPill(tier: edition.tier)
                    }
                }
            }
        }
        .padding(10)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(entry.statusColor.opacity(0.8)).frame(height: 2).padding(.horizontal, 1)
        }
        .panel(Theme.card, radius: 12)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if entry.mediaKind == .movie { return entry.type.replacingOccurrences(of: "_", with: " ").capitalized }
        var parts: [String] = []
        if let s = entry.seasonNumber, let e = entry.episodeNumber {
            parts.append(String(format: "S%02dE%02d", s, e))
        }
        if entry.isAnime, let abs = entry.absoluteNumber { parts.append("#\(abs)") }
        if let t = entry.episodeTitle { parts.append(t) }
        return parts.joined(separator: " · ")
    }
}
