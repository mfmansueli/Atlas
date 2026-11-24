//
//  NominationCountriesField.swift
//  Atlas
//

import SwiftUI

/// Countries and regions: all of them or some (picked in a sheet), and
/// Launch in some markets first.
struct NominationCountriesField: View {
    @Binding var territories: [String]
    @Binding var launchInSelectMarketsFirst: Bool

    @State private var isChoosing = false
    /// "Some" picked with nothing chosen yet.
    @State private var isSome = false

    private var catalog: TerritoryCatalog { .standard }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Picker("Countries and regions", selection: Binding { territories.isEmpty && !isSome ? 0 : 1 } set: { value in
                isSome = value == 1
                if value == 0 { territories = [] } else if territories.isEmpty { isChoosing = true }
            }) {
                Text("All \(catalog.count)").tag(0)
                Text("Some").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("nominations.countries.mode")
            if !territories.isEmpty || isSome {
                FlowLayout(spacing: Spacing.xSmall) {
                    ForEach(territories, id: \.self) { id in
                        HStack(spacing: Spacing.xxSmall) {
                            Text(catalog.territory(alpha3: id)?.name ?? id)
                            Button {
                                territories.removeAll { $0 == id }
                            } label: {
                                Image(systemName: "xmark").font(.footnote.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove"))
                        }
                        .font(.subheadline)
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, Spacing.xxSmall)
                        .background(Palette.fill1, in: Capsule())
                    }
                    Button("Choose Countries…") { isChoosing = true }
                        .controlSize(.small)
                        .accessibilityIdentifier("nominations.countries.choose")
                }
            }
            Toggle(isOn: $launchInSelectMarketsFirst) {
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text("Launch in some markets first")
                    Text("Tell the editors it starts in a few countries before the rest.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityIdentifier("nominations.countries.first")
        }
        .sheet(isPresented: $isChoosing) {
            NominationCountriesSheet(selection: $territories)
        }
    }
}
