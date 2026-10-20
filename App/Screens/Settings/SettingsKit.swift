import SwiftUI
import FusionhaKit

// Shared building blocks for the native Settings panels (also SettingsStore,
// SettingsMotion, SettingsRows, SettingsButtons): the panel page around a
// native Form.

// MARK: Page

/// A native panel page: a dark Form under the panel title (the system bar's,
/// D1), whose first block is its subtitle, revealed on entry. Scrolls to
/// and flashes a searched-for field.
struct SettingsForm<Content: View>: View {
    let slug: String
    @ViewBuilder var content: Content
    @Environment(SettingsFlash.self) private var flash

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                } header: {
                    SettingsPanelHeading(slug: slug)
                    .textCase(nil)
                    .padding(.horizontal, -4)
                    .settingsReveal()
                }
                content
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .environment(\.settingsPanelSlug, slug)
            .settingsLayout()
            .task(id: flash.target(in: slug)) {
                guard let label = flash.target(in: slug) else { return }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.smooth) { proxy.scrollTo(label, anchor: .center) }
            }
        }
        .settingsPanelTitle(slug)
        .overlay(alignment: .bottom) { SettingsSaveErrorBanner() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
    }
}

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private struct SettingsSaveErrorBanner: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        if let message = store.saveError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger)
                Text(message).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                Button { store.saveError = nil } label: { Image(systemName: "xmark") }
                    .foregroundStyle(Theme.mut)
                    .accessibilityLabel("Dismiss")
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .task(id: message) {
                try? await Task.sleep(for: .seconds(5))
                if store.saveError == message { store.saveError = nil }
            }
        }
    }
}
