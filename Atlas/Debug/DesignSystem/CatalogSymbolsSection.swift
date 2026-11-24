//
//  CatalogSymbolsSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// README-DS §13, "Icons: only Apple SF Symbols": each section's outline
/// symbol in its system colour, the Settings panes, and the five status
/// symbols, each with its name and tint as `design-tokens.json → symbol`
/// lists them.
struct CatalogSymbolsSection: View {
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: Spacing.medium, alignment: .leading)]

    var body: some View {
        CatalogSection(
            title: "Symbols",
            note: "Only SF Symbols, outline, in a system colour per section. No tiles, no text characters as icons."
        ) {
            VStack(alignment: .leading, spacing: Spacing.large) {
                group("Sections") {
                    ForEach(AppWorkspaceSection.allCases) { section in
                        row(section.title, symbol: section.style.symbol, tint: section.style.tint.rawValue) {
                            SectionSymbol(style: section.style)
                        }
                    }
                }
                group("Settings") {
                    ForEach(SettingsPane.allCases) { pane in
                        row(pane.title, symbol: pane.style.symbol, tint: pane.style.tint.rawValue) {
                            SectionSymbol(style: pane.style)
                        }
                    }
                }
                group("Status") {
                    ForEach(StatusSymbol.allCases, id: \.self) { status in
                        row(status.rawValue, symbol: status.symbol, tint: status.tint.rawValue) {
                            status.image.frame(width: Metrics.symbolColumn)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("designSystem.catalog.symbols")
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .atlasTextStyle(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.small) {
                content()
            }
        }
    }

    private func row(_ title: String, symbol: String, tint: String, @ViewBuilder icon: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            icon()
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .atlasTextStyle(.body)
                Text("\(symbol) · \(tint)")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CatalogSymbolsSection().padding().frame(width: 760)
}
#endif
