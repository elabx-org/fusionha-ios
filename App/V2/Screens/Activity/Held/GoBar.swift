import SwiftUI

/// The decision's commit button (mock `ac-go` / `goBar`): the primary action
/// in the accent, an override in the held orange, a destructive bulk action
/// in the danger red, with a note under it. A prominent glass button: it is
/// a control, so it is Liquid Glass; on the Duo's right page it stays in view
/// over a fade while the panel scrolls under it.
struct GoBar: View {
    enum Tone { case primary, override, danger }

    let label: String
    let systemImage: String
    var tone: Tone = .primary
    var note: AttributedString?
    var busy = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            Button(action: action) {
                HStack(spacing: 8) {
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
                    }
                    Text(label).font(.system(size: 15.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .contentTransition(.interpolate)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(tint)
            .disabled(disabled || busy)
            if let note {
                Text(note)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var tint: Color {
        switch tone {
        case .primary: return Theme.primary
        case .override: return Theme.stuck
        case .danger: return Theme.danger
        }
    }
}

extension View {
    /// Pins a `GoBar` to the bottom of a scrolling panel over a fade into
    /// the page, so the panel scrolls under it (the Duo's right page and the
    /// phone's decision sheet).
    func goBarInset<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            bar()
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 14)
                .background {
                    LinearGradient(stops: [.init(color: Theme.bg.opacity(0), location: 0),
                                           .init(color: Theme.bg.opacity(0.85), location: 0.45)],
                                   startPoint: .top, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
        }
    }
}
