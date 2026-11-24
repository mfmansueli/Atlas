//
//  NominationCountriesSheet.swift
//  Atlas
//

import SwiftUI

/// Choose Countries…: every country or region App Store Connect sells in,
/// searchable, ticked on and off.
struct NominationCountriesSheet: View {
    @Binding var selection: [String]

    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Choose Countries and Regions")
                .font(.title3.weight(.semibold))
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("nominations.countries.search")
            List(shown, id: \.id) { territory in
                Toggle(territory.name, isOn: Binding {
                    selection.contains(territory.id)
                } set: { isOn in
                    if isOn { selection.append(territory.id) } else { selection.removeAll { $0 == territory.id } }
                })
                .toggleStyle(.checkbox)
            }
            .listStyle(.bordered)
            .frame(minHeight: 280)
            HStack {
                Text("\(selection.count) chosen")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("nominations.countries.done")
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 420, height: 480)
    }

    private var shown: [Territory] {
        let all = TerritoryCatalog.standard.territories.sorted { $0.name < $1.name }
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? all : all.filter { $0.name.localizedStandardContains(query) }
    }
}
