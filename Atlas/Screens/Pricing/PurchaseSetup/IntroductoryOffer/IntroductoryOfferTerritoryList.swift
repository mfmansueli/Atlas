//
//  IntroductoryOfferTerritoryList.swift
//  Atlas
//

import SwiftUI

/// The countries or regions an introductory offer runs in, when they're
/// chosen: every territory with a checkbox, filtered by name.
struct IntroductoryOfferTerritoryList: View {
    @Binding var chosen: Set<String>

    @State private var search = ""

    private var territories: [Territory] {
        let all = TerritoryCatalog.standard.territories.sorted { $0.name < $1.name }
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack {
                TextField("Search", text: $search, prompt: Text("Search countries or regions"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("pricing.introductoryOffer.search")
                Text("\(chosen.count) chosen")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
            }
            List(territories) { territory in
                Toggle(isOn: Binding {
                    chosen.contains(territory.id)
                } set: { isOn in
                    if isOn { chosen.insert(territory.id) } else { chosen.remove(territory.id) }
                }) {
                    Text(territory.name)
                }
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("pricing.introductoryOffer.territory.\(territory.id)")
            }
            .listStyle(.bordered)
        }
    }
}
