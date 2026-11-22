//
//  TourTipModifier.swift
//  Atlas
//

import SwiftUI

/// Anchors one of the tour's tips to a view: while the tour shows `step`,
/// its popover points at the view. Nil, or a window without a tour, never
/// shows one. The last tip's Connect an Assistant… opens Settings on AI
/// Assistants.
struct TourTipModifier: ViewModifier {
    let step: TourStep?
    let arrowEdge: Edge
    var anchor: PopoverAttachmentAnchor = .rect(.bounds)

    @Environment(FirstRunTour.self) private var tour: FirstRunTour?
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.popover(isPresented: isPresented, attachmentAnchor: anchor, arrowEdge: arrowEdge) {
            if let step {
                TourTipView(step: step) {
                    tour?.next()
                } onAlternative: {
                    alternative()
                } onClose: {
                    tour?.close()
                }
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding {
            step != nil && tour?.step == step
        } set: { shown in
            if !shown, let step { tour?.tipClosed(step) }
        }
    }

    private func alternative() {
        guard tour?.alternative() == .connectsAssistant else { return }
        SettingsNavigation.shared.pane = .assistants
        openSettings()
    }
}

extension View {
    /// Points the tour's `step` tip at this view (see `TourTipModifier`).
    func tourTip(_ step: TourStep?, arrowEdge: Edge, anchor: PopoverAttachmentAnchor = .rect(.bounds)) -> some View {
        modifier(TourTipModifier(step: step, arrowEdge: arrowEdge, anchor: anchor))
    }
}
