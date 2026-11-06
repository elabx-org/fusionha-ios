import SwiftUI
import FusionhaKit

/// The chip row's one Service chip (owner's Service option 1, mock calm.js
/// `chipRow(1)` / calm-grid.js, 2026-11-04): never a pill per service.
/// - Nothing picked: a glass `tv` Service chip with a chevron, opening a menu
///   of All services, then each service as its one-ink mark and name, most
///   titles first (`V2LibraryServices`).
/// - One picked: the accent chip with that service's mark, its name and an
///   ✕; a tap clears it, a long press opens the menu to switch.
/// Nothing at all until library rows carry a network (servers before 0.4.238).
struct V2LibraryServiceChip: View {
    let filters: V2LibraryFilters
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @State private var services: [V2LibraryService] = []
    @State private var marks = V2ServiceMarks()

    private var picked: V2LibraryService? {
        services.first { $0.name == filters.network }
    }

    var body: some View {
        Group {
            if !services.isEmpty || !filters.network.isEmpty {
                if filters.network.isEmpty { idleChip } else { pickedChip }
            }
        }
        .task(id: "\(model.libraryVersion)|\(filters.network)") { rebuild() }
        .task(id: services.map(\.name)) { await marks.load(services) }
    }

    private func rebuild() {
        let next = V2LibraryServices.from(model.library, keeping: filters.network)
        if next != services { services = next }
    }

    // MARK: Chips

    private var idleChip: some View {
        Menu { menuItems } label: {
            HStack(spacing: 6) {
                Image(systemName: "tv").font(.system(size: 13, weight: .semibold))
                Text("Service").font(.system(size: 13.5, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).opacity(0.7)
            }
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(height: 34)
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel("Service")
        .accessibilityHint("Shows only the titles on one streaming service")
    }

    private var pickedChip: some View {
        Menu { menuItems } label: {
            HStack(spacing: 7) {
                V2NetworkMarkLine(studio: picked?.studio, spacing: 7) {
                    Text(filters.network).font(.system(size: 13.5, weight: .semibold))
                }
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).opacity(0.8)
            }
            .foregroundStyle(Theme.onAccent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 13)
            .frame(height: 34)
            .glassEffect(.regular.tint(Theme.primary).interactive(), in: Capsule())
            .contentShape(Capsule())
        } primaryAction: {
            pick("")
        }
        .accessibilityLabel("\(filters.network), remove filter")
        .accessibilityAddTraits(.isSelected)
    }

    // MARK: Menu

    @ViewBuilder private var menuItems: some View {
        Picker("Service", selection: Binding(get: { filters.network }, set: { pick($0) })) {
            Label("All services", systemImage: "tv").tag("")
            Divider()
            ForEach(services) { service in
                row(service).tag(service.name)
            }
        }
        .pickerStyle(.inline)
    }

    @ViewBuilder private func row(_ service: V2LibraryService) -> some View {
        if let mark = marks.mark(service.name) {
            Label { Text(service.name) } icon: { Image(uiImage: mark) }
        } else {
            Label(service.name, systemImage: "tv")
        }
    }

    private func pick(_ name: String) {
        withAnimation(motion ? .snappy : nil) { filters.network = name }
    }
}
