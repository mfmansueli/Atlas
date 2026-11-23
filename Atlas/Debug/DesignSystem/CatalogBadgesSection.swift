//
//  CatalogBadgesSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Badges (counts), pills (states), a source chip, a card and a suggestion
/// card's surface.
struct CatalogBadgesSection: View {
    var body: some View {
        CatalogSection(title: "Badges, pills and cards", note: "A badge is a count; a pill is a state. Cards are the only depth the app draws itself.") {
            VStack(alignment: .leading, spacing: Spacing.large) {
                HStack(spacing: Spacing.small) {
                    SuggestionBadge(count: 5)
                    SuggestionBadge(count: 32)
                    SuggestionBadge(count: 120)
                    SuggestionBadge(count: 3, isSmall: true)
                }
                FlowLayout(spacing: Spacing.small) {
                    Pill(text: "Live", style: .neutral)
                    Pill(text: "Not pushed", systemImage: "circle.fill", style: .accent)
                    Pill(text: "Suggested", style: .machineTranslated)
                    Pill(text: "Needs an answer", style: .warning)
                    Pill(text: "Rejected", style: .danger)
                    Pill(text: "Missing", style: .outline)
                    AssistantChip(name: "Claude Code")
                }
                HStack(alignment: .top, spacing: Spacing.large) {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                            Text("Card").atlasTextStyle(.title3)
                            Text("A 0.5 pt line and a 3 pt soft shadow.")
                                .atlasTextStyle(.callout)
                                .foregroundStyle(Palette.label2)
                        }
                    }
                    .frame(width: 260)
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Pill(text: "Suggested", style: .machineTranslated)
                        Text("Lifetime: $79.99 → $59.99").atlasTextStyle(.headline)
                        Text("9 of your last 220 reviews call it too expensive.")
                            .atlasTextStyle(.callout)
                            .foregroundStyle(Palette.label2)
                    }
                    .padding(Spacing.medium)
                    .frame(width: 300, alignment: .leading)
                    .suggestionSurface(isSettling: false, arrivalKey: "catalog.surface", arrivedAt: nil)
                }
            }
        }
    }
}
#endif
