//
//  OfferCodesFields.swift
//  Atlas
//

import SwiftUI

/// The codes an offer code comes with, in New Offer Code… and the sheets
/// that add codes to one App Store Connect has: a custom code customers
/// type (how many times it redeems, until when), and a batch of one-time
/// codes Apple makes. Each shows only when it's on.
struct OfferCodesFields: View {
    @Binding var customCode: NewCustomCode?
    @Binding var oneTimeCodes: NewOneTimeCodes?
    let identifier: String
    var showsCustomCode = true
    var showsOneTimeCodes = true
    /// Whether the switches show (off when the sheet is only for one).
    var canTurnOff = true

    var body: some View {
        if showsCustomCode { customSection }
        if showsOneTimeCodes { oneTimeSection }
    }

    private var customSection: some View {
        Section {
            if canTurnOff {
                Toggle("A custom code", isOn: Binding { customCode != nil } set: {
                    customCode = $0 ? NewCustomCode(code: "", numberOfCodes: 1000) : nil
                })
                .accessibilityIdentifier("\(identifier).hasCustomCode")
            }
            if let custom = customCode {
                TextField("Code", text: Binding { custom.code } set: { customCode?.code = $0.uppercased() }, prompt: Text(verbatim: "PODCAST30"))
                    .accessibilityIdentifier("\(identifier).customCode")
                Stepper(value: Binding { custom.numberOfCodes } set: { customCode?.numberOfCodes = $0 },
                        in: SubscriptionOfferRules.numberOfCodes, step: 100) {
                    Text("Redeems up to \(custom.numberOfCodes.formatted()) times")
                }
                .accessibilityIdentifier("\(identifier).customCount")
                Toggle("Expires", isOn: Binding { custom.expirationDate != nil } set: {
                    customCode?.expirationDate = $0 ? Calendar.current.date(byAdding: .month, value: 3, to: .now) : nil
                })
                .accessibilityIdentifier("\(identifier).customExpires")
                if let expiration = custom.expirationDate {
                    DatePicker("Last day", selection: Binding { expiration } set: { customCode?.expirationDate = $0 }, displayedComponents: .date)
                }
            }
        } header: {
            Text("Custom code")
        } footer: {
            note(String(localized: """
            One word people type to redeem it, e.g. for a podcast. Letters and digits, unique for the app. Customers see it: \
            no other platforms, betas or placeholders.
            """))
        }
    }

    private var oneTimeSection: some View {
        Section {
            if canTurnOff {
                Toggle("One-time codes", isOn: Binding { oneTimeCodes != nil } set: {
                    oneTimeCodes = $0 ? NewOneTimeCodes(numberOfCodes: 500, expirationDate: Self.inThreeMonths) : nil
                })
                .accessibilityIdentifier("\(identifier).hasOneTimeCodes")
            }
            if let batch = oneTimeCodes {
                Stepper(value: Binding { batch.numberOfCodes } set: { oneTimeCodes?.numberOfCodes = $0 },
                        in: SubscriptionOfferRules.numberOfCodes, step: 100) {
                    Text("\(batch.numberOfCodes.formatted()) codes")
                }
                .accessibilityIdentifier("\(identifier).oneTimeCount")
                DatePicker("Last day", selection: Binding { batch.expirationDate } set: { oneTimeCodes?.expirationDate = $0 }, displayedComponents: .date)
                    .accessibilityIdentifier("\(identifier).oneTimeExpires")
                Picker("For", selection: Binding { batch.environment } set: { oneTimeCodes?.environment = $0 }) {
                    ForEach(OfferCodeEnvironment.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("\(identifier).environment")
            }
        } header: {
            Text("One-time codes")
        } footer: {
            note(String(localized: "Apple makes unique codes, each redeemed once. Once it has, Save Codes… in Pricing saves them as a CSV file."))
        }
    }

    private static var inThreeMonths: Date {
        Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
