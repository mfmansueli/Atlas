//
//  DebugFreeGate.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Puts a scene on the Free plan: its own gate instead of the launch's
/// (DEBUG builds start with Pro), so a scene can show what Free has.
struct DebugFreeGate: ViewModifier {
    let gate: ProGate?

    func body(content: Content) -> some View {
        if let gate {
            content.environment(gate)
        } else {
            content
        }
    }
}
#endif
