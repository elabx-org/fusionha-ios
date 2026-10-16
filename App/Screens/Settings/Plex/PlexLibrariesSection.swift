import SwiftUI
import FusionhaKit

/// "4K Plex libraries" (web `LibraryList`): every section with its detection
/// evidence, the suggestions to confirm, ON/OFF overrides and Re-detect.
struct PlexLibrariesSection: View {
    let plex: PlexServerModel
    @Environment(SettingsStore.self) private var store

    private var nameOnly: Bool { store.string("plex_server_url").isEmpty }

    var body: some View {
        SettingsSection("4K Plex libraries") {
            HStack(alignment: .top, spacing: 10) {
                Text(nameOnly
                     ? "No server URL, so these come from your Plex account by name only. Connect the server to detect 4K libraries from where your 4K files live."
                     : "Detected from where your 4K files live. A suggestion never applies itself: confirm it, or set any library by hand.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Re-detect 4K libraries", systemImage: "arrow.clockwise") { Task { await plex.redetect() } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.i2)
                    .symbolEffect(.rotate, isActive: plex.redetecting)
                    .disabled(plex.redetecting)
            }
            if let rows = plex.libraries {
                if rows.isEmpty {
                    Text("No Plex libraries yet. Save your server URL, then re-detect.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                } else {
                    summary(rows)
                    ForEach(rows) { lib in
                        PlexLibraryRow(lib: lib, flash: plex.flashKey == lib.sectionKey) { value in
                            Task { await plex.setOverride(lib, value) }
                        }
                    }
                }
            } else {
                Text("Loading libraries…").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
    }

    private func summary(_ rows: [PlexLibrary]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PlexLibraryEvidence.summary(rows)) { chip in
                    PlexChip(text: chip.label, color: PlexColors.state(chip.state))
                }
            }
        }
    }
}

/// One Plex section (web `LibraryRow`): its 4K evidence, state (ambient wash)
/// and the manual override. A SUGGESTED match gets an explicit "Confirm 4K";
/// it never applies itself.
struct PlexLibraryRow: View {
    let lib: PlexLibrary
    let flash: Bool
    let onOverride: (String?) -> Void
    @Environment(\.settingsMotionOff) private var motionOff

    private var state: PlexLibraryState { PlexLibraryEvidence.state(lib) }

    var body: some View {
        let color = PlexColors.state(state)
        VStack(alignment: .leading, spacing: 7) {
            title
            Text(PlexLibraryEvidence.evidenceText(lib)).font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            if let pair = PlexLibraryEvidence.pathPair(lib) {
                Text("\(Text("Plex").bold()) \(pair.plex) ↔ \(Text("fusionha").bold()) \(pair.root)")
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let why = PlexLibraryEvidence.decisionText(lib) {
                Text(why).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(state == .gone ? Theme.dim : Theme.stuck)
                    .fixedSize(horizontal: false, vertical: true)
            }
            controls
        }
        .padding(11)
        .background(color.opacity(flash ? 0.24 : 0.10), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .animation(motionOff ? nil : .easeOut(duration: 0.4), value: flash)
    }

    private var title: some View {
        HStack(spacing: 6) {
            Text(lib.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
            PlexChip(text: PlexLibraryEvidence.typeLabel(lib.type))
            PlexChip(text: state.word, color: PlexColors.state(state))
            if lib.uhdOverride != nil { PlexChip(text: "manual", color: Theme.dim).accessibilityHint("Set by hand") }
            if lib.lostWithoutServerUrl {
                PlexChip(text: "via server URL", color: Theme.dim)
                    .accessibilityHint("4K only through path detection: needs the server URL")
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if state == .suggested {
                Button("Confirm 4K") { onOverride("ON") }
                    .buttonStyle(.web(.primary))
                    .accessibilityLabel("Confirm 4K · \(lib.title)")
            }
            Picker("\(lib.title): 4K setting", selection: choice) {
                Text("Auto").tag("auto")
                Text("4K").tag("ON")
                Text("Not 4K").tag("OFF")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var choice: Binding<String> {
        Binding(get: { lib.uhdOverride ?? "auto" }, set: { v in
            guard v != (lib.uhdOverride ?? "auto") else { return }
            onOverride(v == "auto" ? nil : v)
        })
    }
}
