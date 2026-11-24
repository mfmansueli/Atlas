//
//  TemplateGalleryGrid.swift
//  Atlas
//

import SwiftUI

/// The gallery's cards for the chosen style, three to a row where there's
/// room, shared by the first-run picker and the Templates sheet. In Free,
/// the templates past Free's three carry the PRO chip, and picking one
/// goes to `onLocked` instead (the template in use stays usable).
struct TemplateGalleryGrid: View {
    let viewModel: ScreenshotsViewModel
    /// "Use This Template" on first run; the sheet says "Switch to This"
    /// or, for the template in use, "Start Over from This".
    let isFirstRun: Bool
    /// A template that's part of Pro, picked in Free.
    var onLocked: (TemplateStarter) -> Void = { _ in }
    var onUse: (TemplateStarter) -> Void

    @Environment(ProGate.self) private var pro: ProGate?

    private let columns = [GridItem(.adaptive(minimum: 268), spacing: 14, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(TemplateStarter.starters(in: viewModel.galleryStyle)) { starter in
                let isInUse = !isFirstRun && viewModel.document?.template?.starter == starter
                let isLocked = !pro.mayUse(starter, inUse: isFirstRun ? nil : viewModel.document?.template?.starter)
                TemplateGalleryCard(
                    starter: starter,
                    images: viewModel.starterImages(starter),
                    fontNote: viewModel.starterFontNote(starter),
                    isInUse: isInUse,
                    buttonTitle: isFirstRun ? String(localized: "Use This Template") : viewModel.templateEditor.starterButtonTitle(starter),
                    isProminent: !isInUse,
                    isLocked: isLocked
                ) {
                    if isLocked { onLocked(starter) } else { onUse(starter) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.gallery")
    }
}
