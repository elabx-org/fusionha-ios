import SwiftUI
import UIKit
import FusionhaKit

/// "Identified as": one copy-to-clipboard chip per known id.
struct AddIdsRow: View {
    let flow: AddFlow
    @State private var copied: String?

    var body: some View {
        let ids = flow.ids
        var chips: [(String, String)] = []
        if let tmdb = ids.tmdb { chips.append(("TMDB", String(tmdb))) }
        if let tvdb = ids.tvdb { chips.append(("TVDB", String(tvdb))) }
        if let imdb = ids.imdb, !imdb.isEmpty { chips.append(("IMDb", imdb)) }
        // While the preview loads, hold the space of the ids it usually brings.
        let pending = flow.previewLoading
            ? (flow.isSeries ? [ids.tvdb == nil, (ids.imdb ?? "").isEmpty] : [(ids.imdb ?? "").isEmpty]).filter { $0 }.count
            : 0
        return Group {
            if !chips.isEmpty || pending > 0 {
                // The chips wrap under the label on a phone.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Identified as").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    PreviewFlow(spacing: 6) {
                        ForEach(chips, id: \.0) { chip in
                            Button { copy(chip.0, chip.1) } label: {
                                (Text(chip.0).fontWeight(.bold).foregroundColor(Theme.txt)
                                 + Text(" " + (copied == chip.0 ? "Copied" : chip.1)))
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(copied == chip.0 ? Theme.i2 : Theme.mut)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .frame(minHeight: 36)
                                    .background(Theme.txt.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.line))
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityLabel("Copy \(chip.0) id \(chip.1)")
                        }
                        ForEach(0..<pending, id: \.self) { _ in
                            SkeletonBar(height: 30, radius: 7).frame(width: 74)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .sensoryFeedback(.success, trigger: copied)
            }
        }
    }

    private func copy(_ name: String, _ value: String) {
        UIPasteboard.general.string = value
        copied = name
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if copied == name { copied = nil }
        }
    }
}
