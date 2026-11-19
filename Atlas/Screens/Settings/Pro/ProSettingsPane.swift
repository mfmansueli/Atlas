//
//  ProSettingsPane.swift
//  Atlas
//

import StoreKit
import SwiftUI

/// Settings → Atlas Pro (board 48): the plan, what Pro includes next to
/// what Free does, and Restore Purchases / Redeem a Code….
struct ProSettingsPane: View {
    @Environment(ProGate.self) private var pro
    @State private var isRedeeming = false
    @State private var restoreMessage: String?

    var body: some View {
        Form {
            SettingsPaneHeader(pane: .pro)
            Section {
                ProPlanRow(status: pro.entitlements.status, isPro: pro.entitlements.isPro, offers: pro.entitlements.offers) {
                    pro.showPlansInSettings()
                }
            }
            Section(pro.entitlements.isPro ? "Included" : "What Pro adds") {
                ForEach(ProSettingsPane.includes, id: \.id) { item in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Image(systemName: pro.entitlements.isPro ? "checkmark" : "plus")
                            .foregroundStyle(pro.entitlements.isPro ? Palette.positive : Palette.label2)
                            .frame(width: 16)
                            .accessibilityHidden(true)
                        SettingsRowLabel(title: item.title, caption: item.free)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.pro.includes")
            Section {
                HStack {
                    Button("Restore Purchases") { Task { await restore() } }
                        .accessibilityIdentifier("settings.pro.restore")
                    Button("Redeem a Code…") { isRedeeming = true }
                        .accessibilityIdentifier("settings.pro.redeem")
                    Spacer()
                }
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("settings.pro.restoreMessage")
                }
            } footer: {
                Text("""
                AI runs on your own assistant or API key, so Pro’s price never includes AI usage. If Pro ends, everything you made \
                stays and stays editable.
                """)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .offerCodeRedemption(isPresented: $isRedeeming)
        .task { await pro.entitlements.loadOffers() }
    }

    private func restore() async {
        let restored = await pro.entitlements.restore()
        restoreMessage = restored
            ? String(localized: "Atlas Pro is restored.")
            : String(localized: "No Atlas Pro purchase was found for this Apple Account.")
    }

    struct Included {
        let title: LocalizedStringKey
        let free: String?
        let id = UUID()
    }

    static let includes: [Included] = [
        Included(title: "Every app and every account", free: String(localized: "Free: 1 app, 1 account")),
        Included(title: "Accept All Languages, Accept All Pages, Translate All", free: String(localized: "Free: one at a time")),
        Included(title: "All 14 screenshot templates on every device", free: String(localized: "Free: 3 templates, iPhone and iPad")),
        Included(
            title: "Autopilot, and artwork from Claude",
            free: String(localized: "Screenshots, App Preview, headers, event images")
        ),
        Included(title: "Recommended prices for 175 countries", free: String(localized: "Setting any price yourself is free")),
        Included(title: "Retention messages and offers", free: nil),
        Included(
            title: "Suggested replies to reviews, and Reply to All",
            free: String(localized: "Free: read, translate and reply by hand")
        ),
    ]
}
