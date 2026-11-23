//
//  TourTipModifier.swift
//  Atlas
//

import SwiftUI
import TipKit

/// Anchors one of the tour's tips to a view with TipKit's `.popoverTip`:
/// while the tour shows `step`, its tip points at the view. Nil, or a
/// window without a tour, never shows one. The last tip's Connect an
/// Assistant… opens Settings on AI Assistants. A tip whose popover closes
/// by itself (a click elsewhere, Escape) ends the tour.
struct TourTipModifier: ViewModifier {
    let step: TourStep?
    let arrowEdge: Edge
    var anchor: PopoverAttachmentAnchor = .rect(.bounds)

    @Environment(FirstRunTour.self) private var tour: FirstRunTour?
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content
            .popoverTip(tip, isPresented: isPresented, attachmentAnchor: anchor, arrowEdge: arrowEdge)
            .tipViewStyle(TourTipViewStyle())
    }

    /// This view's tip while the tour shows it.
    private var tip: TourTip? {
        guard let step, let tour, tour.step == step else { return nil }
        let openSettings = openSettings
        return TourTip(step: step, run: tour.run) {
            tour.next()
        } onAlternative: {
            guard tour.alternative() == .connectsAssistant else { return }
            SettingsNavigation.shared.pane = .assistants
            openSettings()
        } onClose: {
            tour.close()
        }
    }

    private var isPresented: Binding<Bool> {
        Binding {
            step != nil && tour?.step == step
        } set: { shown in
            if !shown, let step { tour?.tipClosed(step) }
        }
    }
}

extension View {
    /// Points the tour's `step` tip at this view (see `TourTipModifier`).
    func tourTip(_ step: TourStep?, arrowEdge: Edge, anchor: PopoverAttachmentAnchor = .rect(.bounds)) -> some View {
        modifier(TourTipModifier(step: step, arrowEdge: arrowEdge, anchor: anchor))
    }
}
