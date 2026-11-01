import SwiftUI
import FusionhaKit

/// Activity's right page in a Spread with nothing picked (F6; the owner's
/// "never empty, the most useful real item", 2026-10-21): the first download
/// that needs you (why it's held, Review in Manual Import, Open in Queue),
/// else the first one moving (its progress, Open in Queue), else "Pick a
/// download". Read from the queue the app polls. Solid content, never glass.
struct ActivityRightPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var needsYou: QueueItem? { model.queue.first { QueueSection.of($0) == .needs } }
    private var moving: QueueItem? {
        model.queue.first { [.downloading, .progress, .importing].contains(QueueSection.of($0)) }
    }

    var body: some View {
        Group {
            if let item = needsYou {
                card(item, label: QueueSection.needs.label, color: Theme.miss) { needsBody(item) }
            } else if let item = moving {
                card(item, label: QueueSection.of(item).label, color: Theme.grab) { movingBody(item) }
            } else {
                pickHint
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg)
        // The right page settles in from the fold (Duo motion); a fade under Reduce Motion.
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown || !motion ? 1 : 0.97, anchor: .leading)
        .onAppear {
            withAnimation(motion ? .spring(duration: 0.35, bounce: 0) : .easeInOut(duration: 0.2)) { shown = true }
        }
    }

    private func card<Content: View>(_ item: QueueItem, label: String, color: Color,
                                     @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(color)
                HStack(alignment: .bottom, spacing: 14) {
                    PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w342"))
                        .frame(width: 92, height: 138)
                        .shelfPoster(radius: 8)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.txt)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let episode = item.episodeLabel {
                            Text(episode).font(.subheadline).foregroundStyle(Theme.mut)
                        }
                        TierPill(tier: item.tier)
                    }
                }
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder private func needsBody(_ item: QueueItem) -> some View {
        if let why = item.held?.line ?? HeldCopy.headline(item.heldDetail, reason: item.heldReason) {
            Text(why)
                .font(.subheadline)
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
        }
        ActFlow(spacing: 8, lineSpacing: 8) {
            if item.status.lowercased() == "held" {
                Button("Review in Manual Import", systemImage: "square.and.arrow.down") {
                    model.pendingRescueIds = [item.id]
                }
                .buttonStyle(ActButtonStyle(kind: .primary))
            }
            openInQueue(item)
        }
    }

    @ViewBuilder private func movingBody(_ item: QueueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: item.fraction).tint(Theme.grab)
            Text("\(Int((item.fraction * 100).rounded()))%")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.mut)
        }
        .accessibilityElement(children: .combine)
        openInQueue(item)
    }

    private func openInQueue(_ item: QueueItem) -> some View {
        Button("Open in Queue", systemImage: "list.bullet") { model.openInQueue(downloadId: item.id) }
            .buttonStyle(ActButtonStyle(kind: .ghost))
    }

    private var pickHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.dim)
                .accessibilityHidden(true)
            Text("Pick a download")
                .font(.headline)
                .foregroundStyle(Theme.txt)
            Text("Nothing needs you and nothing is downloading right now.")
                .font(.footnote)
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
