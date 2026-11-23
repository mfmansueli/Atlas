//
//  NewInAppPurchaseSheet.swift
//  Atlas
//

import SwiftUI

/// Create In-App Purchase: its type, reference name and product ID, its
/// display name and description in the app's primary language, its price
/// in the United States, and what App Review gets (notes and the review
/// screenshot). It looks like Create Subscription. Add to Review & Push
/// queues it; the push creates it. Add with a problem scrolls to the first
/// field that has one and puts the cursor there.
struct NewInAppPurchaseSheet: View {
    let appID: StoreApp.ID
    let appName: String
    let problems: (NewInAppPurchase) -> [NewSubscriptionProblem]
    let onCancel: () -> Void
    let onAdd: (NewInAppPurchase) -> Void

    @State private var draft: NewInAppPurchase
    @State private var priceText: String
    @State private var showsMissing = false
    @State private var scrollTarget: NewSubscriptionField?
    @FocusState private var focusedField: NewSubscriptionField?

    init(
        appID: StoreApp.ID,
        appName: String,
        initial: NewInAppPurchase,
        problems: @escaping (NewInAppPurchase) -> [NewSubscriptionProblem],
        onCancel: @escaping () -> Void,
        onAdd: @escaping (NewInAppPurchase) -> Void
    ) {
        self.appID = appID
        self.appName = appName
        self.problems = problems
        self.onCancel = onCancel
        self.onAdd = onAdd
        _draft = State(initialValue: initial)
        _priceText = State(initialValue: initial.price.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
    }

    private var purchase: NewInAppPurchase {
        var purchase = draft
        purchase.price = NewSubscription.price(from: priceText)
        return purchase
    }

    private var currentProblems: [NewSubscriptionProblem] {
        var problems = problems(purchase)
        if !priceText.trimmingCharacters(in: .whitespaces).isEmpty, purchase.price == nil {
            problems.removeAll { $0 == .missing(.price) }
            problems.append(.invalidPrice)
        }
        return problems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollViewReader { proxy in
                Form {
                    purchaseSection
                    storeSection
                    priceSection
                    reviewSection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .onChange(of: scrollTarget) {
                    guard let scrollTarget else { return }
                    withAnimation { proxy.scrollTo(scrollTarget, anchor: .center) }
                    focusedField = scrollTarget
                    self.scrollTarget = nil
                }
            }
            Divider()
            footer
        }
        .frame(width: 560)
        .frame(minHeight: 420, idealHeight: 640, maxHeight: 700)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.newInAppPurchase")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("New in-app purchase")
                .font(.title2.weight(.semibold))
            Text("For \(appName). It waits in Review & Push; nothing is created in App Store Connect until you push.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.xLarge)
    }

    // MARK: - Sections

    private var purchaseSection: some View {
        Section {
            Picker("Type", selection: $draft.kind) {
                ForEach(NewInAppPurchaseKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .accessibilityIdentifier("pricing.newInAppPurchase.kind")
            field(.referenceName, text: $draft.referenceName)
            field(.productID, text: $draft.productID, monospaced: true)
            if draft.kind.supportsFamilySharing {
                Toggle("Family Sharing", isOn: $draft.isFamilySharable)
                    .accessibilityIdentifier("pricing.newInAppPurchase.familySharing")
            }
        } header: {
            Text("In-app purchase")
        } footer: {
            note("The product ID is what \(appName)’s code buys. It can’t be changed or used again. Family Sharing can’t be turned off once it’s on.")
        }
    }

    private var storeSection: some View {
        Section {
            field(.purchaseName, text: $draft.displayName)
            field(.purchaseDescription, text: $draft.description, prompt: String(localized: "What it unlocks"), isMultiline: true)
        } header: {
            Text("On the App Store · \(draft.locale.name)")
        } footer: {
            note("Shown on the purchase sheet. Add other languages in Store Page → In-App Texts after the push.")
        }
    }

    private var priceSection: some View {
        Section {
            LabeledContent {
                HStack(spacing: Spacing.xSmall) {
                    TextField("Price", text: $priceText, prompt: Text(verbatim: "149.99"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .focused($focusedField, equals: .price)
                        .accessibilityIdentifier("pricing.newInAppPurchase.price")
                    Text(verbatim: "USD")
                        .foregroundStyle(Palette.label2)
                }
            } label: {
                Text("Price in the United States")
            }
            .id(NewSubscriptionField.price)
            problemText(for: .price)
        } header: {
            Text("Price")
        } footer: {
            note("Every other country or region gets Apple’s equalized price, and the purchase is available everywhere.")
        }
    }

    private var reviewSection: some View {
        Section {
            field(.reviewNote, text: $draft.reviewNote, prompt: String(localized: "Optional: how App Review finds the purchase"), isMultiline: true)
            ReviewScreenshotSlot(appID: appID, file: $draft.reviewScreenshot)
        } header: {
            Text("App Review")
        } footer: {
            note("The review screenshot shows App Review the purchase in the app. Without it the purchase stays in Missing Metadata.")
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            Text("Submit it for App Review with the app’s next version.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("pricing.newInAppPurchase.cancel")
            Button("Add to Review & Push", action: add)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("pricing.newInAppPurchase.add")
        }
        .buttonBorderShape(.capsule)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }

    // MARK: - Fields

    private func field(
        _ field: NewSubscriptionField,
        text: Binding<String>,
        prompt: String? = nil,
        monospaced: Bool = false,
        isMultiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Group {
                    if isMultiline {
                        TextField(field.title, text: text, prompt: prompt.map { Text($0) }, axis: .vertical)
                            .lineLimit(2...5)
                    } else {
                        TextField(field.title, text: text, prompt: prompt.map { Text($0) })
                    }
                }
                .font(monospaced ? .body.monospaced() : .body)
                .focused($focusedField, equals: field)
                .accessibilityIdentifier("pricing.newInAppPurchase.\(field.rawValue)")
                if let limit = field.limit, limit <= 100 {
                    let count = NewSubscription.trimmed(text.wrappedValue).count
                    Text(verbatim: "\(count)/\(limit)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(count > limit ? Palette.err : Palette.label2)
                }
            }
            problemText(for: field)
            if let inAppField = field.inAppTextField {
                let issues = StoreTextGuidelineCheck.issues(in: text.wrappedValue, for: inAppField)
                if !issues.isEmpty {
                    InlineMessage.warning(issues.map(\.message).joined(separator: "\n"))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pricing.newInAppPurchase.\(field.rawValue).guideline")
                }
            }
        }
        .id(field)
    }

    @ViewBuilder
    private func problemText(for field: NewSubscriptionField) -> some View {
        if let problem = currentProblems.first(where: { $0.field == field && (showsMissing || !Self.isMissing($0)) }) {
            Text(problem.message)
                .font(.subheadline)
                .foregroundStyle(Palette.err)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pricing.newInAppPurchase.\(field.rawValue).problem")
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func isMissing(_ problem: NewSubscriptionProblem) -> Bool {
        if case .missing = problem { return true }
        return false
    }

    private func add() {
        guard let first = currentProblems.first else {
            onAdd(purchase)
            return
        }
        showsMissing = true
        scrollTarget = first.field
    }
}
