import SwiftUI
import FusionhaKit

/// The live full-path preview (web `NamingPreview`): folder components joined
/// with `/`, then the file and `.mkv`, colour-coded per token through the
/// client-side mirror of `naming.py` (`NamingFormat.render`).
struct NamingPreview: View {
    let kind: NamingKind
    let value: (String) -> String
    let replaceIllegal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                NamingBlip()
                Text("Live preview — full path")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            }
            Text(path)
                .font(.system(size: 12.5, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityLabel(NamingFormat.plain(segments.flatMap { $0 }))
            Divider().overlay(Theme.line)
            Text("The **{Custom Formats}** token renders only formats flagged **“Include when renaming”** that matched this file.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    /// Each folder's segments, then the file's.
    private var segments: [[NamingSegment]] {
        let sample = NamingFormat.previewSample(kind)
        let formats = NamingFormat.previewFormats(kind, value: value)
        let folders = formats.folders.map {
            NamingFormat.render($0, sample: sample, replaceIllegal: replaceIllegal) + [NamingSegment(text: "/")]
        }
        let file = NamingFormat.render(formats.file, sample: sample, replaceIllegal: replaceIllegal)
        return folders + [file, [NamingSegment(text: ".mkv")]]
    }

    private var path: AttributedString {
        let groups = segments
        var out = AttributedString()
        for (i, group) in groups.enumerated() {
            // Folders and the extension are dim; the file's own literals are muted.
            let isFile = i == groups.count - 2
            for seg in group {
                out.append(styled(seg, literal: isFile ? Theme.mut : Theme.dim))
            }
        }
        return out
    }

    private func styled(_ seg: NamingSegment, literal: Color) -> AttributedString {
        var run = AttributedString(seg.text)
        switch seg.kind {
        case .title?:
            run.foregroundColor = Theme.txt
            run.font = .system(size: 12.5, weight: .semibold, design: .monospaced)
        case .quality?:
            run.foregroundColor = Theme.i2
            run.backgroundColor = Theme.i2.opacity(0.10)
        case .customFormat?:
            run.foregroundColor = Theme.edition
            run.backgroundColor = Theme.edition.opacity(0.10)
        case .episode?:
            run.foregroundColor = Theme.mut
        case nil:
            run.foregroundColor = literal
        }
        return run
    }
}

/// The preview's live dot; still under reduced motion.
private struct NamingBlip: View {
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(Theme.done)
            .frame(width: 6, height: 6)
            .opacity(dim ? 0.35 : 1)
            .onAppear {
                guard !motionOff else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}
