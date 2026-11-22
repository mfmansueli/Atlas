//
//  AIFilingFields.swift
//  Atlas
//

import SwiftUI

/// The AI content declaration's Yes: the approved filing of the app's
/// large language model or algorithm, and whose it is when it's another
/// company's, as App Store Connect asks for them.
struct AIFilingFields: View {
    let viewModel: AppInformationViewModel

    private var filing: AIFilingDetails { viewModel.aiFiling }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Picker("Filed as", selection: binding(\.kind)) {
                ForEach(AIFilingKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityIdentifier("appInformation.compliance.ai.kind")
            TextField(String(localized: "Filing number"), text: binding(\.number))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .accessibilityLabel(Text("Filing number"))
                .accessibilityIdentifier("appInformation.compliance.ai.number")
            TextField(String(localized: "Registered name"), text: binding(\.name))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .accessibilityLabel(Text("Registered filing name"))
                .accessibilityIdentifier("appInformation.compliance.ai.name")
            Toggle(String(localized: "It’s another company’s model or algorithm"), isOn: binding(\.usesAnotherCompanysModel))
                .accessibilityIdentifier("appInformation.compliance.ai.thirdParty")
            if filing.usesAnotherCompanysModel {
                TextField(String(localized: "Company that owns it"), text: binding(\.technologyOwner))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .accessibilityLabel(Text("Company that owns the model"))
                    .accessibilityIdentifier("appInformation.compliance.ai.owner")
                Text("""
                App Store Connect also takes their authorization or usage agreement. It names the model and its \
                filing number, you as the authorized party, and the owner as in the Cyberspace Administration of \
                China’s registry.
                """)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
            Text("Only the Cyberspace Administration of China approves a filing. Atlas keeps it here: Apple’s API doesn’t take it.")
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.ai.filing")
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AIFilingDetails, Value>) -> Binding<Value> {
        Binding {
            viewModel.aiFiling[keyPath: keyPath]
        } set: { value in
            var filing = viewModel.aiFiling
            filing[keyPath: keyPath] = value
            viewModel.setAIFiling(filing)
        }
    }
}
