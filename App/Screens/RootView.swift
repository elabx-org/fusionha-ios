import SwiftUI
import FusionhaKit

/// The app shell, mirroring the web's mobile layout: the five bottom-nav
/// destinations (Library, Discover, Calendar, Activity, Wanted) with the web's
/// icons in the native Liquid Glass tab bar, which hides on scroll like the
/// web's floating bar. Requester accounts get Discover, My requests and You.
/// Item details, Add, the omni search and the Delete confirmation open as
/// sheets, and toasts float above the tab bar, as they do on the web.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            if model.requestScoped {
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { DiscoverView() }
                Tab("My requests", image: "nav-requests", value: AppTab.requests) { RequestsView() }
                Tab("You", image: "nav-you", value: AppTab.you) { YouView() }
            } else {
                Tab("Library", image: "nav-library", value: AppTab.library) { LibraryView() }
                Tab("Discover", image: "nav-discover", value: AppTab.discover) { DiscoverView() }
                    .badge(model.canApproveRequests ? model.pendingRequests : 0)
                Tab("Calendar", image: "nav-calendar", value: AppTab.calendar) { CalendarView() }
                Tab("Activity", image: "nav-activity", value: AppTab.activity) { ActivityView() }
                    .badge(model.queueTotal > 0 ? Text(model.queueTotal > 99 ? "99+" : "\(model.queueTotal)") : nil)
                Tab("Wanted", image: "nav-wanted", value: AppTab.wanted) { WantedView() }
            }
        }
        .tint(Theme.cyan)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay(alignment: .bottom) {
            ToastHost()
                .padding(.bottom, 72)
        }
        .environment(\.motionEnabled, !reduceMotion && model.animationsEnabled)
        .environment(\.railStyle, model.railStyle)
        .environment(\.railConsolidate, model.railConsolidate)
        .sheet(item: $model.presentedItem) { ref in
            ItemDetailView(itemId: ref.id)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $model.showingAdd) {
            AddTitleSheet()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(Theme.panel)
        }
        .sheet(isPresented: $model.showingAccount) { AccountSheet().presentationBackground(Theme.bg) }
        .sheet(item: $model.deleteTarget) { target in
            DeleteTitleDialog(target: target)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .fullScreenCover(isPresented: $model.showingOmni) {
            OmniSearchView()
                .environment(\.motionEnabled, !reduceMotion && model.animationsEnabled)
        }
        .onOpenURL { url in
            // fusionha://activity from the widget and Live Activity.
            if url.host() == "activity" { model.tab = .activity }
        }
        .onChange(of: model.tab) {
            model.searchText = ""
            model.chromeHidden = false
            if model.tab != .library { model.exitSelectMode() }
        }
        .task {
            await model.loadMe()
            await model.registerPushDevice()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.pollQueue()
        }
        .task(id: "\(scenePhase == .active)|\(model.me?.id ?? -1)") {
            guard scenePhase == .active, model.me != nil else { return }
            await model.pollShell()
        }
    }
}

/// Wraps a tab's content in the web's mobile chrome: the top bar (logo, search
/// pill, avatar) that hides on scroll-down, the dark page background and,
/// where the web shows it, the gradient + button.
struct Screen<Content: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    var showsAdd = false
    /// Kept for source compatibility: Library filters in place through the
    /// top-bar pill, every other tab opens the omni search.
    var filtersInPlace = false
    @ViewBuilder var content: Content

    var body: some View {
        let hidden = model.chromeHidden
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if showsFab {
                AddButton { model.showingAdd = true }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                    .offset(y: hidden ? 140 : 0)
                    .opacity(hidden ? 0 : 1)
                    .allowsHitTesting(!hidden)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TopBar()
                .visualEffect { view, proxy in
                    view.offset(y: hidden ? -proxy.frame(in: .global).maxY : 0)
                }
        }
        .webBackground()
        .animation(motion ? .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.32) : nil, value: hidden)
        .animation(.smooth(duration: 0.2), value: showsFab)
    }

    private var showsFab: Bool {
        showsAdd && !model.requestScoped && model.me?.can("add") != false && !model.selectMode
    }
}

/// The web's mobile `Fab`: a 56pt gradient orb with a 22pt plus, pressing to .92.
struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.fusion, in: Circle())
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel("Add title")
    }
}

/// The web's DeleteItemDialog: "Delete {title}?", the delete-files checkbox, Cancel /
/// Delete (danger, "Deleting…" while pending).
struct DeleteTitleDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let target: DeleteTarget
    @State private var deleteFiles = false
    @State private var deleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete \(target.title)?")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.top, 8)
            Text("This removes the title and all its editions from your library. This cannot be undone.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: $deleteFiles) {
                Text("Also delete the downloaded files from disk")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.txt)
            }
            .toggleStyle(WebCheckboxStyle())
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .panel(Theme.panel2, radius: Theme.radius)
                }
                .buttonStyle(PressScaleStyle())
                Button {
                    Task {
                        deleting = true
                        let ok = await model.delete(target, deleteFiles: deleteFiles)
                        deleting = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text(deleting ? "Deleting…" : "Delete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.danger, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .disabled(deleting)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A web checkbox: an 18pt rounded square, indigo with a white tick when on.
struct WebCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(configuration.isOn ? Theme.indigo : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(configuration.isOn ? Theme.indigo : Theme.mut.opacity(0.6), lineWidth: 1.5))
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 18, height: 18)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
