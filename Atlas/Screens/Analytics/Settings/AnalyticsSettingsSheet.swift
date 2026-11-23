//
//  AnalyticsSettingsSheet.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Analytics settings: the vendor number, which apps have reports turned
/// on (and stopping them), and when reports are downloaded.
struct AnalyticsSettingsSheet: View {
    let store: AnalyticsStore
    /// Every app in the library, by ID and name.
    let apps: [(id: StoreApp.ID, name: String)]
    var focus: AnalyticsSettingsFocus?
    /// Stops Apple's reports for one app; returns what went wrong.
    let onStop: (StoreApp.ID) async -> String?
    let onVendorNumberChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vendorNumber = ""
    @State private var stoppingAppID: StoreApp.ID?
    @State private var isStopping = false
    @State private var errorMessage: String?
    @FocusState private var isVendorFocused: Bool

    static let reportsURL = URL(string: "https://appstoreconnect.apple.com/itc/payments_and_financial_reports")!

    var body: some View {
        VStack(spacing: 0) {
            Form {
                vendorSection
                appsSection
                Section {
                    Picker("Download reports", selection: Binding(get: { store.settings.refreshMode }, set: { store.setRefreshMode($0) })) {
                        ForEach(AnalyticsRefreshMode.allCases) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text("Reports stay and are analyzed on this Mac. Apple’s numbers are 1 to 2 days behind.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Done") { commitVendorNumber(); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("analytics.settings.done")
            }
            .padding(Spacing.medium)
        }
        .frame(width: 560, height: 520)
        .onAppear {
            vendorNumber = store.settings.vendorNumber
            isVendorFocused = focus == .vendorNumber
        }
        // A container of its own: otherwise its identifier replaces Done's.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.settings")
    }

    private var vendorSection: some View {
        Section {
            TextField("Vendor number", text: $vendorNumber, prompt: Text("8 digits, e.g. 85012345"))
                .focused($isVendorFocused)
                .onSubmit(commitVendorNumber)
                .accessibilityIdentifier("analytics.settings.vendorNumber")
            if store.settings.keyCannotReadSales || focus == .salesRole {
                Label {
                    Text("""
                    Needs an Admin, Finance or Sales key: add one in Settings → Account, or change this key’s role in \
                    Users and Access.
                    """)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warnMark)
                }
                .font(.callout)
            }
            if let error = store.salesError {
                Label(error, systemImage: "exclamationmark.octagon.fill").font(.callout).foregroundStyle(Palette.err)
            }
        } header: {
            Text("Sales and Trends")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text("""
                Trials, paid starts, renewals, cancellations and proceeds need your vendor number.
                """)
                Text("""
                App Store Connect → Payments and Financial Reports → Reports: top left, under your legal entity’s name.
                """)
                Button("Open Payments and Financial Reports") { NSWorkspace.shared.open(Self.reportsURL) }
                    .buttonStyle(.link)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appsSection: some View {
        Section("Reports by app") {
            ForEach(apps, id: \.id) { app in
                let setup = store.setup(for: app.id)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                            if let history = history(for: app.id) {
                                Text(history).font(.subheadline).monospacedDigit().foregroundStyle(Palette.label2)
                            }
                        }
                        Spacer()
                        Text(Self.status(setup)).foregroundStyle(Palette.label2)
                        if setup != .off, setup != .keyCannotAsk {
                            Button("Stop Asking Apple for Reports…") { stoppingAppID = app.id }
                                .controlSize(.regular)
                                .disabled(stoppingAppID != nil)
                                .accessibilityIdentifier("analytics.settings.stop")
                        }
                    }
                    if stoppingAppID == app.id { confirmation(for: app) }
                }
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.octagon.fill").font(.callout).foregroundStyle(Palette.err)
            }
        }
    }

    /// Inline, so it says what happens before anything does.
    private func confirmation(for app: (id: StoreApp.ID, name: String)) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Apple stops new reports for \(app.name) from tomorrow. Downloaded ones stay here. Restarting takes 1 to 2 days.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Keep Reports") { stoppingAppID = nil }
                Button("Stop Reports") {
                    Task {
                        isStopping = true
                        errorMessage = await onStop(app.id)
                        isStopping = false
                        stoppingAppID = nil
                    }
                }
                .disabled(isStopping)
                .accessibilityIdentifier("analytics.settings.stop.confirm")
            }
            .controlSize(.regular)
        }
        .padding(10)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.field))
    }

    /// "Asked Nov 10 at 15:04 · Last checked today at 08:12", for apps
    /// that have been asked for.
    private func history(for appID: StoreApp.ID) -> String? {
        let record = store.record(for: appID)
        guard let asked = record.askedOn else { return nil }
        let askedText = String(localized: "Asked \(AnalyticsText.moment(asked, now: store.now()))")
        guard let checked = record.lastChecked else { return askedText + " · " + String(localized: "Not checked yet") }
        return askedText + " · " + String(localized: "Last checked \(AnalyticsText.moment(checked, now: store.now()))")
    }

    private static func status(_ setup: AnalyticsSetup) -> String {
        switch setup {
        case .off: String(localized: "Off")
        case .waiting: String(localized: "Waiting for Apple")
        case .keyCannotAsk: String(localized: "Needs an Admin key")
        case .ready: String(localized: "On")
        }
    }

    private func commitVendorNumber() {
        let trimmed = vendorNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != store.settings.vendorNumber else { return }
        store.setVendorNumber(trimmed)
        onVendorNumberChanged()
    }
}
