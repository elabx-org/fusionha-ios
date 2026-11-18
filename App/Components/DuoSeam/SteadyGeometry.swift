import SwiftUI

/// Geometry for pages that should only re-lay out once things stop moving.
///
/// On the open Duo a title's column changes size and insets several times
/// while it slides in, lands or follows the split handle: width 494 → 503 →
/// 558 → 577 → 494 → 578, the trailing inset 84 → 0 → 84 and the top 24 → 82
/// → 24 over one landing, and every 16 ms through a drag (local Duo run,
/// 2026-11-18). Read straight into state, each reading re-laid out the whole
/// title page and re-fitted its hero art, which zoomed in and out.
///
/// Here the first real reading (non-zero) applies at once, and so does a
/// real resize (`isResize`: the column going full screen or back, so the art
/// is refitted and re-centred in the frame it lands in); other readings
/// apply once they have held still for `settle` with the seam at rest
/// (`DuoSeamDrag.live` nil), so a landing re-lays out the page once.
extension View {
    func onSteadyGeometryChange<Value: Equatable>(
        for type: Value.Type, settle: Duration = .milliseconds(180),
        isReal: @escaping (Value) -> Bool = { _ in true },
        isResize: @escaping (_ from: Value, _ to: Value) -> Bool = { _, _ in false },
        of read: @escaping (GeometryProxy) -> Value, action: @escaping (Value) -> Void
    ) -> some View {
        modifier(SteadyGeometry(settle: settle, isReal: isReal, isResize: isResize, read: read, apply: action))
    }
}

private struct SteadyGeometry<Value: Equatable>: ViewModifier {
    let settle: Duration
    let isReal: (Value) -> Bool
    let isResize: (Value, Value) -> Bool
    let read: (GeometryProxy) -> Value
    let apply: (Value) -> Void
    @Environment(DuoSeamDrag.self) private var seam: DuoSeamDrag?
    /// Not state: holding a reading must not re-run anything.
    @State private var held = Held()

    func body(content: Content) -> some View {
        content.onGeometryChange(for: Value.self, of: read) { value in
            held.wait?.cancel()
            let held = held
            guard let last = held.applied, isReal(value), !isResize(last, value) else {
                if isReal(value) { held.applied = value }
                apply(value)
                return
            }
            let seam = seam, settle = settle, apply = apply
            held.wait = Task { @MainActor in
                // `live` is read here, outside any body, so a moving seam
                // never re-runs the page.
                repeat { try? await Task.sleep(for: settle) } while !Task.isCancelled && seam?.live != nil
                guard !Task.isCancelled else { return }
                held.applied = value
                apply(value)
            }
        }
    }

    final class Held {
        var applied: Value?
        var wait: Task<Void, Never>?
    }
}

/// A change of more than 120 pt either way: a real resize, not an inset flip.
func isColumnResize(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) > 120 }
func isColumnResize(_ a: CGSize, _ b: CGSize) -> Bool { abs(a.width - b.width) > 120 || abs(a.height - b.height) > 120 }
