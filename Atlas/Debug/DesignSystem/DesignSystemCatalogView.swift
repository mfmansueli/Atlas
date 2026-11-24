//
//  DesignSystemCatalogView.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// DEBUG only · Debug → Design System Catalog… (⌥⌘D), Rule zero (README —
/// Design system): the design system drawn by its own components, the
/// first place to look when building or refining a screen. Every colour in
/// light, dark and high contrast; the type scale; the seven buttons;
/// badges, pills and cards; the SF Symbols of §13; and the five AI effects
/// playing. The bar on top
/// switches the whole catalog to light or dark, Increase Contrast and Reduce
/// Motion, so each effect shows its Reduce Motion version too.
struct DesignSystemCatalogView: View {
    @State private var scheme: ColorScheme?
    @State private var increasesContrast = false
    @State private var reducesMotion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxxLarge) {
                CatalogEffectsSection()
                CatalogButtonsSection()
                CatalogBadgesSection()
                CatalogSymbolsSection()
                CatalogTypeSection()
                CatalogColorsSection()
            }
            .padding(Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.content)
        .safeAreaInset(edge: .top, spacing: 0) { controls }
        .environment(\._accessibilityReduceMotion, reducesMotion)
        .environment(\._colorSchemeContrast, increasesContrast ? .increased : .standard)
        .preferredColorScheme(scheme)
        .frame(minWidth: 760, minHeight: 560)
        .accessibilityIdentifier("designSystem.catalog")
    }

    private var controls: some View {
        HStack(spacing: Spacing.medium) {
            Picker("Appearance", selection: $scheme) {
                Text("System").tag(ColorScheme?.none)
                Text("Light").tag(ColorScheme?.some(.light))
                Text("Dark").tag(ColorScheme?.some(.dark))
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Toggle("Increase Contrast", isOn: $increasesContrast)
            Toggle("Reduce Motion", isOn: $reducesMotion)
                .accessibilityIdentifier("designSystem.catalog.reduceMotion")
            Spacer()
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.small)
        .background(.bar)
    }
}

#Preview {
    DesignSystemCatalogView()
        .frame(width: 900, height: 700)
}
#endif
