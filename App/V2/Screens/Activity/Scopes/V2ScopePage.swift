import SwiftUI
import FusionhaKit

// The frame every v2 Activity scope shares (mock activity-log.js
// `phonePage` / `splitPage`): the caption and the glass scope chips on top
// of a lazy list, and on the open Duo (or any pane from 720pt) the list a
// third, a hairline, and the right page.

/// The open Duo rule the queue uses (`QueueDuoRuleV2`), read from the pane.
struct V2ScopeSplit {
    let width: CGFloat
    let duoOpen: Bool
    let bookPose: Bool

    var splits: Bool { QueueDuoRuleV2.splits(width: Double(width), duoOpen: duoOpen) }
    var listWidth: CGFloat { CGFloat(QueueDuoRuleV2.listWidth(width: Double(width), bookPose: bookPose)) }
    var gutter: CGFloat { width >= 700 && !splits ? 24 : 20 }
}

/// The list column beside an optional right page.
/// `enabled` false runs the list across the whole pane (History's raw log).
struct V2ScopeColumns<List: View, Right: View>: View {
    let split: V2ScopeSplit
    var enabled = true
    @ViewBuilder var list: () -> List
    @ViewBuilder var right: () -> Right

    var body: some View {
        let splits = split.splits && enabled
        HStack(spacing: 0) {
            list().frame(width: splits ? split.listWidth : nil)
            if splits {
                if split.bookPose {
                    Color.clear.frame(width: CGFloat(QueueDuoRuleV2.gap(bookPose: true)))
                } else {
                    Rectangle().fill(Theme.txt.opacity(0.12)).frame(width: 0.5).ignoresSafeArea()
                }
                right().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The scrolling list: caption and scopes, then the scope's rows as direct
/// children of one lazy stack (blocks pad themselves; module rows touch).
struct V2ScopeList<Caption: View, Content: View>: View {
    let gutter: CGFloat
    @ViewBuilder var caption: () -> Caption
    @ViewBuilder var content: () -> Content
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    caption()
                        .font(.system(size: 13).monospacedDigit())
                        .lineLimit(3)
                    V2ActivityScopes(queueCount: model.queueTotal)
                }
                .padding(.bottom, 14)
                content()
            }
            .padding(.horizontal, gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

/// The open Duo's right page: its own scroll, the mock's 24pt inset.
struct V2RightPage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content() }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A scope's caption: the lead in the page ink and semibold, the rest
/// muted, joined by " · " (mock `.ac-cap`).
struct V2ScopeCaption: View {
    let lead: String?
    var rest: [String] = []
    @Environment(\.pagePalette) private var page

    var body: some View {
        text.foregroundStyle(page?.inkMuted ?? Theme.mut)
    }

    private var text: Text {
        var line = Text("")
        if let lead { line = Text(lead).fontWeight(.semibold).foregroundColor(page?.ink ?? Theme.txt) }
        for (index, part) in rest.enumerated() {
            line = line + Text(lead == nil && index == 0 ? part : " · \(part)")
        }
        return line
    }
}

/// A section caption on the ground between modules (mock `head`).
struct V2ScopeSectionHead<Trailing: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .semibold)) }
            Text(title)
            Spacer(minLength: 8)
            trailing()
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(page?.inkMuted ?? Theme.mut)
        .accessibilityAddTraits(.isHeader)
    }
}

extension V2ScopeSectionHead where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage, trailing: { EmptyView() })
    }
}
