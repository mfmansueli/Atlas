//
//  PricingPreviewInMenu.swift
//  Atlas
//

import SwiftUI

/// "Preview in"'s country menu, like the language menu (README-DS §12):
/// Find a country or currency at the top with how many there are, focused
/// when the menu opens; then the countries with price changes, then every
/// country and region, by full name with its currency. Typing filters at
/// once and keeps the groups; closing the menu clears it. A popover, so it
/// can search.
struct PricingPreviewInMenu: View {
    let countries: PricingPreviewInCountries
    let currentID: String
    let onSelect: (String) -> Void

    /// What Find a country or currency has; empty each time the menu opens.
    @State private var query = ""
    @FocusState private var findsCountry: Bool

    var body: some View {
        let groups = countries.groups(matching: query)
        VStack(alignment: .leading, spacing: 0) {
            find
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        list(groups)
                    }
                    .padding(.horizontal, Spacing.xSmall)
                    .padding(.bottom, Spacing.xSmall)
                }
                // Opens on the current country, without moving.
                .onAppear {
                    let group = groups.first { $0.countries.contains { $0.id == currentID } }
                    proxy.scrollTo(Self.rowID(currentID, in: group?.kind), anchor: .center)
                }
            }
        }
        .padding(.top, Spacing.xSmall)
        .frame(width: 300)
        .frame(maxHeight: 460)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("pricing.preview.menu")
        .defaultFocus($findsCountry, true)
        .task { findsCountry = true }
        .onDisappear { query = "" }
    }

    @ViewBuilder
    private func list(_ groups: [PricingPreviewInGroup]) -> some View {
        if groups.isEmpty {
            Text("No country or region matches “\(query.trimmingCharacters(in: .whitespaces))”.", comment: "kind:empty-state")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .padding(Spacing.small)
                .accessibilityIdentifier("pricing.preview.menu.none")
        }
        ForEach(groups) { group in
            section(group)
        }
    }

    /// A row's scroll position: the changed countries show in both groups.
    private static func rowID(_ id: String, in kind: PricingPreviewInGroup.Kind?) -> String {
        "\(kind?.rawValue ?? "").\(id)"
    }

    private var find: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return HStack(spacing: Spacing.xSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            TextField(String(localized: "Find a country or currency", comment: "kind:placeholder"), text: $query)
                .textFieldStyle(.plain)
                .focused($findsCountry)
                .onSubmit(selectOnlyMatch)
                .accessibilityIdentifier("pricing.preview.menu.find")
            Text(countries.countText(matching: query))
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label3)
                .monospacedDigit()
                .fixedSize()
        }
        .atlasTextStyle(.body)
        .padding(.horizontal, Spacing.small)
        .frame(height: Metrics.menuFieldHeight)
        .background(Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
        .padding(.horizontal, Spacing.small)
        .padding(.bottom, Spacing.xSmall)
    }

    /// Return opens the one country found.
    private func selectOnlyMatch() {
        let found = countries.matching(query)
        guard found.count == 1, let only = found.first else { return }
        onSelect(only.id)
    }

    private func section(_ group: PricingPreviewInGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .atlasTextStyle(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.label2)
                .padding(.horizontal, Spacing.small)
                .padding(.top, Spacing.xSmall)
                .padding(.bottom, Spacing.tiny)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pricing.preview.menu.group.\(group.kind.rawValue)")
            ForEach(group.countries) { country in
                row(country, in: group)
            }
        }
    }

    private func row(_ country: PricingPreviewInCountry, in group: PricingPreviewInGroup) -> some View {
        let isCurrent = country.id == currentID
        return Button {
            onSelect(country.id)
        } label: {
            HStack(spacing: Spacing.small) {
                FlagTile(regionCode: country.territory.alpha2)
                    .frame(width: 20)
                Text(country.territory.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(country.territory.currencyCode)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label3)
                    .fixedSize()
                Image(systemName: "checkmark")
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.accentText)
                    .opacity(isCurrent ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .atlasTextStyle(.body)
            .frame(minHeight: Metrics.menuFieldHeight)
            .padding(.horizontal, Spacing.small)
            .background(
                isCurrent ? AnyShapeStyle(Palette.accentTint) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(Self.rowID(country.id, in: group.kind))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(country)))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        // The changed countries show twice; the group keeps ids apart.
        .accessibilityIdentifier(group.kind == .all ? "pricing.preview.menu.\(country.id)" : "pricing.preview.menu.changed.\(country.id)")
    }

    /// "Brazil, BRL, price changes".
    private func accessibilityText(_ country: PricingPreviewInCountry) -> String {
        let name = "\(country.territory.name), \(country.territory.currencyCode)"
        return country.hasChange ? String(localized: "\(name), price changes", comment: "kind:accessibility-label") : name
    }
}
