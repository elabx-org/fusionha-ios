import SwiftUI
import UIKit
import FusionhaKit

extension ManualImportSession {
    /// Copy a path and confirm it in the sheet (web toast "Path copied").
    func copyPath(_ path: String) {
        UIPasteboard.general.string = path
        toast = CalToast(message: "Path copied")
    }
}

/// The scanned root (web `SourceLine`): "parent / last" once; tap for the
/// full path and Copy.
struct MISourceLine: View {
    let path: String
    @Environment(ManualImportSession.self) private var session
    @State private var open = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let line = ManualImportPaths.sourceLine(path)
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { open.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder").foregroundStyle(Theme.mut)
                    (Text(line.parent.isEmpty ? "" : "\(line.parent) / ").foregroundColor(Theme.mut)
                        + Text(line.last).bold().foregroundColor(Theme.txt))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .font(.footnote)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Source folder \(path)")
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            if open {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(path)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Copy", systemImage: "doc.on.doc") { session.copyPath(path) }
                        .buttonStyle(ActButtonStyle(kind: .ghost))
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }
}
