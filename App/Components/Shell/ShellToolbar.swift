import SwiftUI
import UIKit
import FusionhaKit

/// A tab root's system bar (D1, owner's pick (b)): the page title in the bar,
/// large and on the same row as the toolbar items (`.inlineLarge`), and the
/// Account item at the trailing end. The page adds its own items with
/// `.toolbar`; iOS 27.1 can move all of them into the vertical bar on the
/// iPhone Duo outer display.
struct ShellPage: ViewModifier {
    @Environment(AppModel.self) private var model
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar { AccountToolbarItem(model: model) }
            .task(id: model.me?.id) { await AccountBarArt.shared.load(model.me, client: model.client) }
    }
}

extension View {
    /// The tab root's title and Account item in the system bar.
    func shellPage(_ title: String) -> some View {
        modifier(ShellPage(title: title))
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

    /// Items whose words carry state (Select / Done) stay in the horizontal bar.
    @ToolbarContentBuilder
    func horizontalOnly() -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            axisBehavior(.horizontalOnly)
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
            Button { model.avatar.showingSheet = true } label: {
                Label {
                    Text("Account")
                } icon: {
                    Image(uiImage: AccountBarArt.shared.glyph(me: model.me, dot: dot))
                        .renderingMode(.original)
                }
            }
            .accessibilityLabel(dot ? "Account, \(model.attentionCount) need attention" : "Account")
        }
        .sharedBackgroundVisibility(.hidden)
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
    static let side: CGFloat = 30

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
