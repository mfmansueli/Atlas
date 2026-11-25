//
//  CatalogEmptyStatesSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Empty states (README-DS §14, board 74): one ContentUnavailableView for
/// every section, page size and the smaller one inside a list or sheet.
struct CatalogEmptyStatesSection: View {
    var body: some View {
        CatalogSection(
            title: "Empty states",
            note: """
            The create button stays at the top; the middle explains: the section's symbol in tertiary label, “No … yet”, one \
            or two sentences naming the top and assistant buttons, and an optional small line. A button only when the action \
            is nowhere else on screen.
            """
        ) {
            VStack(alignment: .leading, spacing: Spacing.large) {
                specimen("EmptyStateView · page (44 pt, Title 2)") {
                    EmptyStateView(
                        "No nominations yet",
                        systemImage: AppWorkspaceSection.nominations.systemImage,
                        text: "A nomination tells Apple’s editors about a launch, a big update or an In-App Event before it happens.",
                        note: "Apple doesn’t reply, and a nomination isn’t a promise of featuring."
                    )
                    .frame(height: 300)
                }
                specimen("EmptyStateView · page, with the one action not elsewhere") {
                    EmptyStateView(
                        "No screenshots yet",
                        systemImage: AppWorkspaceSection.screenshots.systemImage,
                        text: "Add your own, or click Make Screenshots and Autopilot makes them from the app."
                    ) {
                        Button("Add Screenshots…") {}
                            .primaryButton()
                    }
                    .frame(height: 300)
                }
                specimen("EmptyStateView · inline (32 pt, Title 3)") {
                    EmptyStateView(
                        "Every review has a reply",
                        systemImage: AppWorkspaceSection.reviews.systemImage,
                        text: "New reviews that need one show up here.",
                        size: .inline
                    ) {
                        Button("Show All Reviews") {}
                            .secondaryButton()
                    }
                }
            }
            .frame(maxWidth: 640)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("designSystem.catalog.emptyStates")
    }

    private func specimen(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
            content()
                .background(Palette.content, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }
}
#endif
