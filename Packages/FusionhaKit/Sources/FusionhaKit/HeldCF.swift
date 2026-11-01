import Foundation

/// The held file's custom-format score against the copy it would replace
/// (web `frontend/src/lib/held-cf.ts`, fusionha 0.4.234): the queue's
/// "Why it's held" and the Manual Import held strip share it.
public enum HeldCF {
    /// "CF 4825 vs your 4875"; negatives take a true minus ("CF 1075 vs your −9245").
    /// Nil when either score is unknown.
    public static func compareLine(_ candidate: Int?, _ current: Int?) -> String? {
        guard let candidate, let current else { return nil }
        return "CF \(number(candidate)) vs your \(number(current))"
    }

    private static func number(_ n: Int) -> String {
        n < 0 ? "\u{2212}\(n.magnitude)" : String(n)
    }
}
