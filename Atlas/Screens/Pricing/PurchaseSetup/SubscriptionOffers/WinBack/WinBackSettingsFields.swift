//
//  WinBackSettingsFields.swift
//  Atlas
//

import SwiftUI

/// A win-back offer's settings, in New Win-Back Offer… and Edit…: who's
/// eligible (months paid, months since they left, months between offers),
/// when it runs, its priority and whether Apple promotes it on the App
/// Store. `startIsFixed` locks the start of an offer that has started.
struct WinBackSettingsFields: View {
    @Binding var settings: WinBackOfferSettings
    let identifier: String
    var startIsFixed = false

    private var months: ClosedRange<Int> { SubscriptionOfferRules.eligibilityMonths }

    var body: some View {
        Section {
            Stepper(value: $settings.eligibility.paidMonths, in: months) {
                Text("Paid at least \(settings.eligibility.paidMonths) months")
            }
            .accessibilityIdentifier("\(identifier).paidMonths")
            Stepper(value: minimum, in: months) {
                Text("Left at least \(settings.eligibility.sinceLastSubscribed.lowerBound) months ago")
            }
            .accessibilityIdentifier("\(identifier).sinceMinimum")
            Stepper(value: maximum, in: months) {
                Text("Left at most \(settings.eligibility.sinceLastSubscribed.upperBound) months ago")
            }
            .accessibilityIdentifier("\(identifier).sinceMaximum")
            Toggle("Wait between offers", isOn: hasWait)
                .accessibilityIdentifier("\(identifier).hasWait")
            if let wait = settings.eligibility.waitMonths {
                Stepper(value: Binding { wait } set: { settings.eligibility.waitMonths = $0 }, in: months) {
                    Text("\(wait) months between offers")
                }
                .accessibilityIdentifier("\(identifier).waitMonths")
            }
        } header: {
            Text("Who can get it")
        } footer: {
            note(settings.eligibility.summary)
        }
        Section {
            DatePicker("Starts", selection: $settings.startDate, displayedComponents: .date)
                .disabled(startIsFixed)
                .accessibilityIdentifier("\(identifier).start")
            Toggle("End date", isOn: hasEnd)
                .accessibilityIdentifier("\(identifier).hasEnd")
            if let end = settings.endDate {
                DatePicker("Ends", selection: Binding { end } set: { settings.endDate = $0 }, displayedComponents: .date)
                    .accessibilityIdentifier("\(identifier).end")
            }
        } header: {
            Text("When")
        } footer: {
            note(startIsFixed
                ? String(localized: "It has started, so its start stays.")
                : String(localized: "Without an end it runs until you end it."))
        }
        Section {
            Picker("Priority", selection: $settings.priority) {
                ForEach(WinBackOfferPriority.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("\(identifier).priority")
            Picker("Shown", selection: $settings.promotionIntent) {
                ForEach(WinBackPromotionIntent.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("\(identifier).promotion")
        } header: {
            Text("Where Apple shows it")
        } footer: {
            note(String(localized: "Apple shows high-priority win-back offers first."))
        }
    }

    private var minimum: Binding<Int> {
        Binding {
            settings.eligibility.sinceLastSubscribed.lowerBound
        } set: { value in
            settings.eligibility.sinceLastSubscribed = value...max(value, settings.eligibility.sinceLastSubscribed.upperBound)
        }
    }

    private var maximum: Binding<Int> {
        Binding {
            settings.eligibility.sinceLastSubscribed.upperBound
        } set: { value in
            settings.eligibility.sinceLastSubscribed = min(value, settings.eligibility.sinceLastSubscribed.lowerBound)...value
        }
    }

    private var hasWait: Binding<Bool> {
        Binding { settings.eligibility.waitMonths != nil } set: { settings.eligibility.waitMonths = $0 ? 6 : nil }
    }

    private var hasEnd: Binding<Bool> {
        Binding {
            settings.endDate != nil
        } set: {
            settings.endDate = $0 ? Calendar.current.date(byAdding: .month, value: 1, to: settings.startDate) : nil
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
