//
//  CatalogColorsSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Every colour token of `design-tokens.json`, each in light, dark, high
/// contrast light and high contrast dark, drawn from the asset catalogue.
struct CatalogColorsSection: View {
    private let names = Self.tokenNames()

    var body: some View {
        CatalogSection(title: "Colour", note: "Blue is what you do; purple is what AI brings; green, amber and red only describe state.") {
            Grid(alignment: .leading, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xSmall) {
                GridRow {
                    Text("Token")
                    Text("Light")
                    Text("Dark")
                    Text("HC light")
                    Text("HC dark")
                }
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                ForEach(names, id: \.self) { name in
                    GridRow {
                        Text(name)
                            .atlasTextStyle(.body)
                            .monospaced()
                        swatch(name, scheme: .light, contrast: .standard)
                        swatch(name, scheme: .dark, contrast: .standard)
                        swatch(name, scheme: .light, contrast: .increased)
                        swatch(name, scheme: .dark, contrast: .increased)
                    }
                }
            }
        }
    }

    private func swatch(_ name: String, scheme: ColorScheme, contrast: ColorSchemeContrast) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
        return shape
            // A checkerboard-free stand-in: the window colour of that
            // appearance behind, so tints read as they do on screen.
            .fill(Palette.content)
            .overlay(shape.fill(Color(name == "accent" ? "AccentColor" : name, bundle: .main)))
            .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
            .frame(width: 72, height: 22)
            .environment(\.colorScheme, scheme)
            .environment(\._colorSchemeContrast, contrast)
            .accessibilityLabel(Text("\(name), \(scheme == .dark ? "dark" : "light")\(contrast == .increased ? ", high contrast" : "")"))
    }

    /// The colour names in `design-tokens.json`, accent first.
    static func tokenNames() -> [String] {
        guard let url = Bundle.main.url(forResource: "design-tokens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = object["color"] as? [String: Any] else { return [] }
        return colors.keys.sorted { lhs, rhs in
            if lhs == "accent" { return true }
            if rhs == "accent" { return false }
            return lhs < rhs
        }
    }
}
#endif
