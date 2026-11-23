//
//  ReviewScreenshotSheet.swift
//  Atlas
//

import SwiftUI

/// Review Screenshot… for one subscription or in-app purchase: what App
/// Store Connect has, the new file, and Add to Review & Push. The push
/// replaces the one it had. Without a screenshot the product stays in
/// Missing Metadata and StoreKit doesn't return it.
struct ReviewScreenshotSheet: View {
    let appID: StoreApp.ID
    let target: PurchaseSetupTarget
    /// What App Store Connect has; nil when it's a new product or unread.
    let current: PurchaseReviewScreenshotState?
    let onCancel: () -> Void
    let onAdd: (PurchaseReviewScreenshotFile) -> Void

    @State private var file: PurchaseReviewScreenshotFile?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Review screenshot")
                    .font(.title2.weight(.semibold))
                Text("For \(target.name). Nothing is sent until you push.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.xLarge)
            Form {
                Section {
                    ReviewScreenshotSlot(appID: appID, file: $file)
                } header: {
                    Text("App Review")
                } footer: {
                    Text(footer)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pricing.reviewScreenshotSheet.cancel")
                Button("Add to Review & Push") { if let file { onAdd(file) } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(file == nil)
                    .accessibilityIdentifier("pricing.reviewScreenshotSheet.add")
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .frame(width: 480)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.reviewScreenshotSheet")
    }

    private var footer: String {
        let what = String(localized: "The purchase as the app shows it, usually the paywall. App Review checks it before approving.")
        guard let current else { return what }
        switch current {
        case .missing:
            return what + " " + String(localized: "App Store Connect has none, so the product is in Missing Metadata.")
        case .uploaded, .processing, .failed:
            return what + " " + String(localized: "It replaces “\(current.fileName ?? "")”.")
        }
    }
}
