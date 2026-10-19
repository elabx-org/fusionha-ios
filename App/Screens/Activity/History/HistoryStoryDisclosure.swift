import SwiftUI
import FusionhaKit

/// What a story card discloses (web `StoryCard`): the raw events of a
/// multi-event story, or a solo story's release name and failure (friendly
/// sentence plus the exact raw reason).
struct HistoryStoryDisclosure: View {
    let story: HistoryStory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if story.events.count > 1 {
                ForEach(story.events) { event in
                    let meta = HistoryLogic.eventMeta(event.eventType)
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(meta.color).frame(width: 7, height: 7).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meta.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(meta.color)
                            if let src = event.sourceTitle {
                                Text(src).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                            }
                        }
                        Spacer(minLength: 0)
                        Text(ActFmt.relative(event.createdAt)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    }
                }
            } else {
                if let release = story.releaseTitle {
                    Text(release).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
                }
                if let reason = story.failReason {
                    let fail = FailureCopy.format(reason, context: .download)
                    Text("\(fail.title) — \(fail.detail)\(fail.sub.map { " \($0)" } ?? "")")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    Text("RAW REASON").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(Theme.dim)
                    Text(fail.raw).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
