//
//  AppTerritoryChecklist.swift
//  Atlas
//

import SwiftUI

/// Every country or region with a checkbox, a search field, and Select All
/// / Select None for the ones the search shows: where the app is sold.
struct AppTerritoryChecklist: View {
    let territories: [AppTerritory]
    @Binding var selection: Set<String>

    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                TextField("Search", text: $search, prompt: Text("Find a country or region"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("pricing.territories.search")
                Button("Select All") { selection.formUnion(shown.map(\.id)) }
                    .accessibilityIdentifier("pricing.territories.all")
                Button("Select None") { selection.subtract(shown.map(\.id)) }
                    .accessibilityIdentifier("pricing.territories.none")
            }
            .controlSize(.small)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { territory in
                        Toggle(isOn: isOn(territory.id)) {
                            HStack(spacing: Spacing.xSmall) {
                                if let alpha2 = territory.alpha2 { FlagTile(regionCode: alpha2) }
                                Text(territory.name)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("pricing.territory.\(territory.id)")
                    }
                }
                .padding(.vertical, Spacing.xxSmall)
            }
            .frame(height: 240)
            .background(Palette.content, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
            Text("\(territories.count { selection.contains($0.id) }) of \(territories.count) selected")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("pricing.territories.count")
        }
        .accessibilityElement(children: .contain)
    }

    private var shown: [AppTerritory] {
        let wanted = search.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return territories }
        return territories.filter { $0.name.localizedStandardContains(wanted) || $0.id.localizedStandardContains(wanted) }
    }

    private func isOn(_ id: String) -> Binding<Bool> {
        Binding {
            selection.contains(id)
        } set: { isOn in
            if isOn { selection.insert(id) } else { selection.remove(id) }
        }
    }
}
