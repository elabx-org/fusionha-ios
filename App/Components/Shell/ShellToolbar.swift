import SwiftUI
import UIKit
import FusionhaKit

/// A tab root's system bar (D1, owner's pick (b)): the page title in the bar,
/// large and on the same row as the toolbar items (`.inlineLarge`), and the
/// Account item at the trailing end. The page adds its own items with
/// `.shellPage(_:actions:)` (bar order below); iOS 27.1 can move all of them into the vertical bar on the
/// iPhone Duo outer display.
struct ShellPage: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.duoOpen) private var duoOpen
    @AppStorage(DuoOpenLayout.storageKey) private var duoLayout: DuoOpenLayout = .standard
    let title: String
    /// The folded Duo's column leads with Account: the page declares it
    /// first itself (the Library), so the shell leaves it out there.
    var accountInPageWhenFolded = false
    /// D7-A: an inline title on the folded Duo and in compact height, so the
    /// page's first card starts higher (Activity).
    var inlineWhenCompact = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var heightClass
    /// The page's own width: past 900 the status cluster joins the bar (S3, as the web).
    @State private var width: CGFloat = 0
    @State private var clusterPanel: StatusClusterPanel?
    @Environment(\.collapsedTabs) private var tabs
    @Environment(\.libraryTabRoot) private var libraryRoot
    @State private var tabsOpen = false

    private var accountInPage: Bool {
        accountInPageWhenFolded && OuterDisplay.isFoldedDuo(sizeClass: sizeClass)
    }

    private var inlineTitle: Bool {
        inlineWhenCompact && OuterDisplay.wantsCompactChrome(sizeClass: sizeClass, heightClass: heightClass)
    }

    private var showsCluster: Bool {
        StatusClusterRule.shows(width: Double(width), requestScoped: model.requestScoped)
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(inlineTitle ? .inline : .inlineLarge)
            .toolbar {
                if tabs.on && !tabs.bottom {
                    CollapsedTabsItem(model: model, state: tabs, libraryRoot: libraryRoot, open: $tabsOpen)
                }
                StatusClusterItems(model: model, shown: showsCluster, open: $clusterPanel)
                DuoLayoutToolbarItem(shown: duoOpen, layout: $duoLayout)
                // Collapsed, Account is the last entry in the tabs' list.
                if !accountInPage && !tabs.on { AccountToolbarItem(model: model) }
            }
            .task(id: model.me?.id) { await AccountBarArt.shared.load(model.me, client: model.client) }
            #if DEBUG
            // Screenshot hook: the tabs' list open on the current tab's page.
            .task(id: tabs.on) {
                guard tabs.on, ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_COLLAPSED_TABS"] == "open" else { return }
                try? await Task.sleep(for: .seconds(4))
                tabsOpen = true
            }
            #endif
            .task(id: showsCluster) {
                while showsCluster && !Task.isCancelled {
                    await ShellStatusFeed.shared.refresh(model)
                    try? await Task.sleep(for: .seconds(5))
                }
            }
    }
}

// Bar order (the iPhone Duo's vertical bar keeps it): the page's actions
// first, Add leading where the page has it, then the shell's status cluster,
// the Duo layout switch and Account last. The page's items always sit inside
// `.shellPage` (pass them as `actions`, or declare them in the content, as the
// Library's header does), never in a `.toolbar` after it, so every tab merges
// them the same way.
extension View {
    /// The tab root's title and Account item in the system bar.
    /// `accountInPageWhenFolded`: on the folded Duo the page declares Account
    /// itself, first in its items (the Library's column order).
    func shellPage(_ title: String, accountInPageWhenFolded: Bool = false) -> some View {
        modifier(ShellPage(title: title, accountInPageWhenFolded: accountInPageWhenFolded))
    }

    /// The same, with the page's own toolbar items placed before the shell's.
    /// `inlineWhenCompact`: an inline title on the folded Duo and in compact height (D7-A).
    func shellPage<Actions: ToolbarContent>(_ title: String, inlineWhenCompact: Bool = false,
                                            @ToolbarContentBuilder actions: () -> Actions) -> some View {
        toolbar(content: actions).modifier(ShellPage(title: title, inlineWhenCompact: inlineWhenCompact))
    }

    /// Close-only sheets keep horizontal bars (ruling Q-DC6).
    @ViewBuilder
    func closeOnlyBars() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }
}

extension ToolbarContent {
    /// Overflow order when the bar runs out of room: frequent and badged items
    /// stay (`high`), occasional ones go first (`low`). iOS 27 and later.
    @ToolbarContentBuilder
    func barPriority(_ high: Bool) -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(high ? .high : .low)
        } else {
            self
        }
    }
}

/// The Account item (Q-DC2, ruled in #60): the user's Plex photo, initials
/// when there is none, with the attention dot, titled "Account" so the
/// vertical bar and VoiceOver have a name. It opens the shell-owned account
/// sheet (`AvatarPresentations`).
struct AccountToolbarItem: ToolbarContent {
    let model: AppModel

    private var dot: Bool { model.attentionCount > 0 && !model.requestScoped }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                #if V2
                // v2: one Account sheet (plan S12), no hub in front of it.
                model.showingAccount = true
                #else
                model.avatar.showingSheet = true
                #endif
            } label: {
                Label {
                    Text("Account")
                } icon: {
                    Image(uiImage: AccountBarArt.shared.glyph(me: model.me, dot: dot))
                        .renderingMode(.original)
                }
            }
            .accessibilityLabel(dot ? "Account, \(model.attentionCount) need attention" : "Account")
        }
        .barPriority(true)
    }
}

/// The Account item's picture: drawn once per photo, initials, dot and
/// palette into a bitmap, so the bar gets a plain image item (which the
/// system can place in either bar) rather than a custom view.
@MainActor
@Observable
final class AccountBarArt {
    static let shared = AccountBarArt()
    static let side: CGFloat = 24

    private(set) var photo: UIImage?
    private var photoUser: Int?
    @ObservationIgnored private var cache: (key: String, image: UIImage)?

    func load(_ me: Me?, client: APIClient?) async {
        guard let me, me.thumb != nil, let client else {
            photo = nil
            photoUser = nil
            return
        }
        guard photoUser != me.id || photo == nil else { return }
        if let data = try? await client.avatarData(userId: me.id), let image = UIImage(data: data) {
            photo = image
            photoUser = me.id
        }
    }

    func glyph(me: Me?, dot: Bool) -> UIImage {
        let photo = me?.id == photoUser ? photo : nil
        let palette = PaletteStore.shared
        let key = "\(photo.map { ObjectIdentifier($0).hashValue } ?? 0)|\(me?.initials ?? "")|\(dot)|\(palette.active.rawValue)|\(palette.posterWash.rawValue)"
        if let cache, cache.key == key { return cache.image }
        let renderer = ImageRenderer(content: AccountGlyph(photo: photo.map(PosterWashRenderer.washed),
                                                           initials: me?.initials ?? "", dot: dot))
        renderer.scale = 3
        // Original rendering at the UIKit level too: the bar tints template
        // images, and drew the first build's photo as a flat accent disc.
        let image = renderer.uiImage?.withRenderingMode(.alwaysOriginal) ?? UIImage()
        cache = (key, image)
        return image
    }
}

/// The bitmap's content: the round photo or initials on the brand fill, a
/// hairline ring that keeps it legible on any bar, and the attention dot.
private struct AccountGlyph: View {
    let photo: UIImage?
    let initials: String
    let dot: Bool

    var body: some View {
        let side = AccountBarArt.side
        ZStack {
            Circle().fill(Theme.fusion)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: side * 13 / 32, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
            }
        }
        .frame(width: side, height: side)
        .overlay(Circle().strokeBorder(Theme.line))
        .overlay(alignment: .topTrailing) {
            if dot {
                Circle()
                    .fill(Theme.miss)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2).padding(-2))
                    .offset(x: 1, y: -1)
            }
        }
        .padding(2)
    }
}
