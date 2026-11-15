import SwiftUI
import FusionhaKit

/// What a finger on the hologram page took hold of, decided where it went
/// down (tabletop plan, slice 6; the hinge-fix mock's pointer modes): the
/// dial (the band round the emitter ring's rim, on the bottom half and clear
/// of the fold), the slab (the focused title, on either half: it spins), or
/// anywhere else (a swipe turns the ring). Each excludes the others, so the
/// dial's turn and the slab's spin never also swipe.
enum V2HologramGrip: Equatable {
    case dial(TabletopDial.Drag)
    /// The slab's turn when the finger went down.
    case spin(from: Double)
    case swipe
    /// Taken by nothing (the slab under Reduce Motion, or the page not live).
    case idle
}

extension V2HologramPage {
    /// One drag for the three grips: it starts after 6 pt (the mock's spin
    /// threshold), so a tap still opens or centres a title.
    var drag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                if grip == nil { grip = take(at: value.startLocation) }
                follow(value)
            }
            .onEnded { value in
                letGo(value)
                grip = nil
            }
    }

    private var rig: V2HologramRig { V2HologramRig(space: space, hingeDegrees: hinge, seat: seat) }

    /// The emitter ring's centre in the page's coordinates.
    private var ringCentre: TabletopPoint {
        TabletopPoint(Double(space.size.width) / 2, Double(rig.hingeY) + TabletopScene.ringZ * rig.scale)
    }

    private func take(at start: CGPoint) -> V2HologramGrip {
        guard live, !cards.isEmpty, !lineUpFrame.contains(start) else { return .idle }
        let point = TabletopPoint(Double(start.x), Double(start.y))
        if TabletopDial.accepts(point, centre: ringCentre, scale: rig.scale, foldBottom: Double(space.fold.upperBound)) {
            return .dial(TabletopDial.Drag(position: Double(index), count: cards.count,
                                           angle: TabletopDial.angle(of: point, centre: ringCentre)))
        }
        if onSlab(start) {
            guard motion else { return .idle }
            let now = Date().timeIntervalSinceReferenceDate
            let from = hand.spin(at: now)
            hand.coast = nil
            hand.spinHeld = from
            return .spin(from: from)
        }
        return .swipe
    }

    private func onSlab(_ point: CGPoint) -> Bool {
        let placed = V2HologramPlaced.all(cards, position: Double(index), art: [:], seat: seat, hinge: hinge,
                                          moment: V2HologramMoment(glass: style.amount))
        return V2HologramPlaced.hit(point, in: placed, rig: rig, atFold: style == .glass) == current.id
    }

    private func follow(_ value: DragGesture.Value) {
        switch grip ?? .idle {
        case .dial(var turning):
            turning.move(to: TabletopDial.angle(of: TabletopPoint(Double(value.location.x), Double(value.location.y)),
                                                centre: ringCentre))
            grip = .dial(turning)
            // The scene follows the finger at once; the row's focus moves
            // to the nearest title as it changes (the haptic tick and the
            // ring's flash go with it).
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                hand.dial = turning.position
                let nearest = cards[turning.nearest].id
                if focused != nearest { focused = nearest }
            }
        case .spin(let from):
            hand.spinHeld = from + TabletopSpin.turn(points: Double(value.translation.width) / rig.scale)
        default:
            break
        }
    }

    /// The finger let go (`value` nil: the gesture was cancelled).
    func letGo(_ value: DragGesture.Value?) {
        switch grip ?? .idle {
        case .dial(let turning):
            withAnimation(motion ? .smooth(duration: 0.4) : nil) {
                hand.dial = nil
                focused = cards[turning.nearest].id
            }
        case .spin:
            let speed = value.map { Double($0.velocity.width) / rig.scale } ?? 0
            hand.coast = TabletopSpin.Coast(start: hand.spinHeld ?? 0, velocity: TabletopSpin.velocity(pointsPerSecond: speed))
            hand.coastStart = Date().timeIntervalSinceReferenceDate
            hand.spinHeld = nil
        case .swipe:
            guard let value else { return }
            let across = value.translation.width
            guard live, abs(across) > abs(value.translation.height), abs(across) >= 40 else { return }
            turn(to: index + (across < 0 ? 1 : -1))
        case .idle:
            break
        }
    }
}
