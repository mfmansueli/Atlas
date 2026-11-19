//
//  AccountsSalesSection.swift
//  Atlas
//

import SwiftUI

/// Settings → Accounts → "Sales and analytics": the vendor number
/// Analytics reads sales, trials and proceeds with, for the key in use,
/// off with the reason when its role can't read them; and the way to the
/// apps Atlas asks Apple to make reports for.
struct AccountsSalesSection: View {
    let session: AppSession
    @Environment(AnalyticsStore.self) private var analytics: AnalyticsStore?
    @State private var draft = ""

    var body: some View {
        Section {
            if let analytics, let keyID = session.currentKeyID {
                vendorRow(analytics, keyID: keyID)
            }
            LabeledContent {
                Button("Open in Analytics") { AtlasLifecycle.shared.open(.currentSection(.analytics)) }
                    .accessibilityIdentifier("settings.openAnalytics")
            } label: {
                SettingsRowLabel(title: "Reports by app", caption: String(localized: "Which apps Atlas asks Apple to make reports for."))
            }
        } header: {
            Text("Sales and analytics")
        } footer: {
            Text("""
            Find the vendor number in App Store Connect → Payments and Financial Reports, under your team name. Removing a key \
            removes its apps from Atlas. Nothing changes in App Store Connect.
            """)
            .font(.caption)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func vendorRow(_ analytics: AnalyticsStore, keyID: String) -> some View {
        let canRead = session.checks[keyID]?.salesAccess != .notAllowed
        let team = session.keys.first { $0.keyID == keyID }?.teamName ?? keyID
        return LabeledContent {
            TextField("Vendor number", text: $draft, prompt: Text(verbatim: "8XXXXXXX"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .disabled(!canRead)
                .onSubmit { analytics.setVendorNumber(draft) }
                .onChange(of: draft) { analytics.setVendorNumber(draft) }
                .accessibilityIdentifier("settings.vendorNumber")
        } label: {
            SettingsRowLabel(
                title: "Vendor number · \(team)",
                caption: canRead
                    ? String(localized: "Sales readable with key \(keyID).")
                    : String(localized: "Needs a key with the Admin, Finance or Sales role.")
            )
        }
        .onAppear { draft = analytics.settings.vendorNumber }
    }
}
