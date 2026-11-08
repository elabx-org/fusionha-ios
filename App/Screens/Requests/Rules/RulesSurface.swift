import SwiftUI

extension View {
    /// A Rules card's ground. v1: the panel colour (or the rule's status
    /// wash). v2 (approved Rules and guardrails): solid content on the
    /// card colour, 22pt corners and a hairline; a rule's on/off reads from
    /// its toggle, not a green or red wash.
    @ViewBuilder
    func rulesSurface(wash: Color? = nil, v1Radius: CGFloat = Theme.radius, v1Panel: Bool = true) -> some View {
        #if V2
        self
            .background(Theme.card, in: RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous).strokeBorder(Theme.line))
        #else
        if v1Panel {
            self.background(Theme.panel, in: RoundedRectangle(cornerRadius: v1Radius, style: .continuous))
        } else {
            self.actWash(wash, radius: v1Radius, base: Theme.card)
        }
        #endif
    }
}
