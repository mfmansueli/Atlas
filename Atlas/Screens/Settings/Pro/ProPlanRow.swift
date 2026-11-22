//
//  ProPlanRow.swift
//  Atlas
//

import SwiftUI

/// The top of Settings → Atlas Pro: the plan and when it renews, with
/// Manage Subscription…, or Free with See Atlas Pro….
struct ProPlanRow: View {
    let status: ProStatus
    let isPro: Bool
    let offers: [ProOffer]
    let showPlans: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            Image(systemName: isPro ? "checkmark.seal.fill" : "seal")
                .font(.title2)
                .foregroundStyle(isPro ? Palette.accent : Palette.label2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .accessibilityIdentifier("settings.pro.plan")
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.pro.detail")
            }
            Spacer(minLength: Spacing.medium)
            if isPro {
                if case .subscribed = status {
                    Button("Manage Subscription…") {
                        if let url = ProPlanRow.manageURL { NSWorkspace.shared.open(url) }
                    }
                    .accessibilityIdentifier("settings.pro.manage")
                }
            } else {
                Button("See Atlas Pro…", action: showPlans)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("settings.pro.seePlans")
            }
        }
        .padding(.vertical, Spacing.xxSmall)
    }

    /// The App Store's subscriptions page for this Apple Account.
    static let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")

    var title: String {
        switch status {
        case let .subscribed(plan, _, isTrial) where isTrial:
            String(localized: "Atlas Pro · \(plan.title) · free trial")
        case let .subscribed(plan, _, _):
            String(localized: "Atlas Pro · \(plan.title)")
        case .lifetime:
            String(localized: "Atlas Pro · Lifetime")
        case .free where isPro:
            String(localized: "Atlas Pro")
        case .free:
            String(localized: "Atlas Free")
        }
    }

    var detail: String {
        switch status {
        case let .subscribed(plan, until, _):
            ProPlanRow.renewalLine(plan: plan, until: until, price: offers.first { $0.plan == plan }?.displayPrice)
        case .lifetime:
            String(localized: "Bought once · billed by the App Store")
        case .free where isPro:
            String(localized: "Unlocked in this build.")
        case .free:
            String(localized: "Free does it one at a time. Pro does it all at once.")
        }
    }

    /// "Renews November 2, 2027 · $59.99 a year · billed by the App Store".
    static func renewalLine(plan: ProPlan, until: Date?, price: String?) -> String {
        var parts: [String] = []
        if let until { parts.append(String(localized: "Renews \(until.formatted(date: .long, time: .omitted))")) }
        if let price, plan == .monthly {
            parts.append(String(localized: "\(price) a month"))
        } else if let price {
            parts.append(String(localized: "\(price) a year"))
        }
        parts.append(String(localized: "billed by the App Store"))
        return parts.joined(separator: " · ")
    }
}
