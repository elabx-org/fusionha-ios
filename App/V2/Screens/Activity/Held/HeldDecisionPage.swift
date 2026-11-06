import SwiftUI
import FusionhaKit

/// The decision panel with its commit button, as the open Duo's right page
/// or the phone's sheet. "Stays held" commits to Manual Import; an override
/// turns the button orange with its own words, says you are overriding, and
/// asks once more before it runs (risk 11: destructive, confirmed, gated).
struct HeldDecisionPage: View {
    let item: QueueItem
    let siblings: [QueueItem]
    let canDecide: Bool
    var dense = false
    /// The page gutter around the panel's card.
    var gutter: CGFloat = 16
    /// Opens Manual Import for this download.
    let review: () -> Void
    /// Runs an override; true when it went through.
    let perform: (HeldChoice) async -> Bool
    /// After an override ran (the sheet closes; the page moves on).
    let done: () -> Void
    /// The queue's kept choice and scroll (fold continuity); nil keeps its own.
    var draft: HeldDecisionDraft?
    @State private var choice: HeldChoice
    @State private var confirming = false
    @State private var busy = false
    @Environment(\.motionEnabled) private var motion

    init(item: QueueItem, siblings: [QueueItem], canDecide: Bool, dense: Bool = false, gutter: CGFloat = 16,
         draft: HeldDecisionDraft? = nil, review: @escaping () -> Void,
         perform: @escaping (HeldChoice) async -> Bool, done: @escaping () -> Void) {
        self.item = item
        self.siblings = siblings
        self.canDecide = canDecide
        self.dense = dense
        self.gutter = gutter
        self.draft = draft
        self.review = review
        self.perform = perform
        self.done = done
        _choice = State(initialValue: draft?.choice(for: item.id) ?? .stay)
    }

    var body: some View {
        ScrollView {
            HeldDecisionPanel(item: item, siblings: siblings, choice: $choice, canDecide: canDecide, dense: dense)
                .padding(dense ? 14 : 16)
                .background { ModuleSurface() }
                .padding(.horizontal, gutter)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .keepsScrollOffset(read: { [draft, item] in draft?.offset(for: item.id) ?? 0 },
                           write: { [draft, item] y in draft?.setOffset(y, for: item.id) })
        .scrollIndicators(.hidden)
        .goBarInset {
            GoBar(label: choice.goLabel, systemImage: choice.goIcon, tone: choice.isOverride ? .override : .primary,
                  note: note, busy: busy, disabled: choice.isOverride && !canDecide, action: commit)
                .animation(motion ? .snappy(duration: 0.25) : nil, value: choice)
        }
        .onChange(of: item.id) { choice = draft?.choice(for: item.id) ?? .stay }
        .onChange(of: choice) { draft?.setChoice(choice, for: item.id) }
        .confirmationDialog(choice.confirmTitle(item), isPresented: $confirming, titleVisibility: .visible) {
            Button(choice.goLabel, role: .destructive) { run(choice) }
            Button("Keep it held", role: .cancel) {}
        } message: {
            Text(choice.detail(item))
        }
        .sensoryFeedback(.selection, trigger: choice)
    }

    private var note: AttributedString {
        if choice.isOverride {
            var text = AttributedString("You are overriding what happens now. You confirm once more next.")
            if let range = text.range(of: "overriding") {
                text[range].foregroundColor = Theme.stuckText
                text[range].font = .system(size: 12.5, weight: .semibold)
            }
            return text
        }
        return AttributedString("Import, keep or skip each file there")
    }

    private func commit() {
        if choice.isOverride { confirming = true } else { review() }
    }

    private func run(_ value: HeldChoice) {
        busy = true
        Task {
            let ok = await perform(value)
            busy = false
            if ok { done() }
        }
    }
}
