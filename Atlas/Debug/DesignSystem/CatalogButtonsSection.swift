//
//  CatalogButtonsSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The seven buttons of README §4, with the AI start look and Accept All.
struct CatalogButtonsSection: View {
    var body: some View {
        CatalogSection(
            title: "Buttons",
            note: "One filled blue button per card or sheet. Starting AI from inside a page is secondary with the sparkles and a purple label."
        ) {
            Grid(alignment: .leading, horizontalSpacing: Spacing.large, verticalSpacing: Spacing.medium) {
                row("Hero") { Button("Get Started") {}.heroButton() }
                row("Toolbar") {
                    Button {} label: { Label("Review & Push", systemImage: "arrow.up.circle") }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                }
                row("Primary") { Button("Submit for Review…") {}.primaryButton() }
                row("Secondary") { Button("Choose Folder…") {}.secondaryButton() }
                row("Row action") {
                    HStack {
                        Button("Accept") {}.rowActionButton()
                        Button("Use This Capture") {}.rowActionButton()
                        Button("Dismiss") {}.controlSize(.regular)
                    }
                }
                row("Plain") { Button("Show Me How") {}.plainButton() }
                row("Destructive") { Button("Delete…", role: .destructive) {}.destructiveButton() }
                row("Start AI") {
                    Button {} label: { AIStartLabel("Make Review Screenshots…") }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                row("Accept All") {
                    Button {} label: {
                        HStack(spacing: Spacing.xSmall) {
                            Text("Accept All")
                            SuggestionBadge(count: 3)
                        }
                    }
                    .primaryButton()
                }
            }
        }
    }

    private func row(_ name: String, @ViewBuilder button: () -> some View) -> some View {
        GridRow {
            Text(name)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
            button()
        }
    }
}
#endif
