//
//  ReviewShotsBanner.swift
//  Atlas
//

import SwiftUI

/// The banner above Pricing's cards about review screenshots (README —
/// Pricing: review screenshots): why a run stopped (the paywall wasn't
/// found, or showed no prices) with how to go on; the images a run made,
/// with Accept All n; else, when products miss one and Screenshots has no
/// capture of the paywall, Make Review Screenshots…. Nothing otherwise.
struct ReviewShotsBanner: View {
    @Bindable var viewModel: PricingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let run = viewModel.setup.runs.run(for: viewModel.app.id)
        Group {
            switch run?.phase {
            case let .paywallNotFound(tried)?:
                paywallNotFound(tried: tried)
            case let .noPrices(saw)?:
                noPrices(saw: saw)
            case .working?:
                EmptyView()
            case .ready?, nil:
                let suggested = viewModel.productsWithSuggestedReviewShot
                if suggested.count >= 2 {
                    arrived(suggested, client: run?.client)
                } else if run == nil {
                    missing
                }
            }
        }
        .aiFailureArrival(key: failureKey(run?.phase))
    }

    // MARK: - Missing, no capture

    @ViewBuilder private var missing: some View {
        let count = viewModel.productsMissingReviewShot.count
        if count > 0, viewModel.setup.paywallCapture == nil {
            // Nothing an assistant made yet: a neutral note with a warning
            // mark (Redesign, 23 November); only the button is AI.
            shell(isAI: false) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Palette.warn)
                    .accessibilityHidden(true)
                Text(missingText(count))
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button { viewModel.makeReviewScreenshots() } label: {
                    AIStartLabel(String(localized: "Make Review Screenshots…"))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("pricing.reviewShots.make")
            }
            .accessibilityIdentifier("pricing.reviewShots.banner")
        }
    }

    private func missingText(_ count: Int) -> String {
        let app = ReviewShotsAskPrompt.shortName(viewModel.app.name)
        return count == 1
            ? String(localized: "1 product needs a review screenshot. Autopilot can open \(app) in Simulator and capture it.")
            : String(localized: "\(count) products need a review screenshot. Autopilot can open \(app) in Simulator and capture each plan.")
    }

    // MARK: - Arrived

    private func arrived(_ products: [PricingProduct], client: String?) -> some View {
        shell(isAI: true) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            let maker = client ?? MCPClientKind.claudeCode.title
            Text("\(maker) made review screenshots for \(products.count) products. Check each below; nothing is sent until you push.")
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button { acceptAll() } label: {
                HStack(spacing: Spacing.xSmall) {
                    Text("Accept All")
                    SuggestionBadge(count: products.count)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityLabel(Text("Accept All, \(products.count) review screenshots"))
            .accessibilityIdentifier("pricing.reviewShots.acceptAll")
        }
        .accessibilityIdentifier("pricing.reviewShots.arrived")
    }

    private func acceptAll() {
        let accepted = viewModel.acceptAllReviewShots()
        viewModel.sayReviewShots(
            String(localized: "Accepted \(accepted.count) review screenshots. Nothing is sent yet.")
        ) { [viewModel] in
            viewModel.undoReviewShots(accepted)
        }
    }

    // MARK: - Stopped

    private func paywallNotFound(tried: String) -> some View {
        let count = viewModel.setup.runs.run(for: viewModel.app.id)?.products.count ?? viewModel.productsMissingReviewShot.count
        let client = viewModel.setup.runs.run(for: viewModel.app.id)?.client ?? MCPClientKind.claudeCode.title
        return stopped(title: String(localized: "\(client) couldn’t find the paywall")) {
            Text(notFoundText(tried: tried, count: count))
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.small) {
                Text("Where is it?")
                    .font(.callout)
                TextField("Where is it?", text: route, prompt: Text(routePrompt))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .onSubmit(tryAgain)
                    .accessibilityIdentifier("pricing.reviewShots.route")
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Not Now") { viewModel.dismissReviewShotsRun() }
                    .accessibilityIdentifier("pricing.reviewShots.notNow")
                Button(action: tryAgain) { AIStartLabel(String(localized: "Try Again")) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pricing.reviewShots.tryAgain")
            }
        }
        .accessibilityIdentifier("pricing.reviewShots.notFound")
    }

    /// Where is it?, kept on the model while the banner shows.
    private var route: Binding<String> {
        Binding { viewModel.setup.paywallRoute } set: { viewModel.setup.paywallRoute = $0 }
    }

    private var routePrompt: String {
        let app = ReviewShotsAskPrompt.shortName(viewModel.app.name)
        return String(localized: "Settings → \(app) Plus, or a link such as \(app.lowercased().filter(\.isLetter))://plus")
    }

    private func notFoundText(tried: String, count: Int) -> String {
        let app = ReviewShotsAskPrompt.shortName(viewModel.app.name)
        let what = tried.isEmpty ? String(localized: "It opened \(app) in Simulator, but nothing it tried led to a purchase screen.") : tried
        let products = count == 1 ? String(localized: "The product is as it was.") : String(localized: "The \(count) products are as they were.")
        return String(localized: "\(what) Nothing was captured. \(products)")
    }

    private func tryAgain() {
        viewModel.tryReviewShotsAgain()
    }

    private func noPrices(saw: String) -> some View {
        let run = viewModel.setup.runs.run(for: viewModel.app.id)
        let client = run?.client ?? MCPClientKind.claudeCode.title
        let app = ReviewShotsAskPrompt.shortName(viewModel.app.name)
        let count = run?.products.count ?? viewModel.productsMissingReviewShot.count
        let plans = viewModel.reviewShotsAskProducts.map(\.plan)
        return stopped(title: String(localized: "The paywall opened, but no prices showed"), caption: String(localized: "What it saw")) {
            let emptyPaywall = String(localized: "App Review would see an empty paywall, so nothing was captured.")
            Text(saw.isEmpty ? noPricesText(app: app, count: count) : saw + " " + emptyPaywall)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("\(client) can add a StoreKit configuration to \(app)’s Xcode project")
                    .font(.callout.weight(.semibold))
                Group {
                    Text("· \(app).storekit, with \(ListFormatter.localizedString(byJoining: plans)) at the U.S. prices in Pricing")
                    Text("· Set in the Run options of Atlas’s scheme. Apple: its products never reach App Store Connect or App Store-signed apps")
                    Text("· \(client) shows you the change in its own window before it saves it")
                }
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Raised inside the amber box, as the canvas's StoreKit note.
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Not Now") { viewModel.dismissReviewShotsRun() }
                    .accessibilityIdentifier("pricing.reviewShots.notNow")
                Button {
                    viewModel.dismissReviewShotsRun()
                    viewModel.makeReviewScreenshots(storeKit: true)
                } label: {
                    AIStartLabel(String(localized: "Add StoreKit Configuration…"))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("pricing.reviewShots.storeKit")
            }
        }
        .accessibilityIdentifier("pricing.reviewShots.noPrices")
    }

    private func noPricesText(app: String, count: Int) -> String {
        String(localized: """
        The App Store returned none of \(app)’s \(count) products, so nothing was captured. Finish setting them up in App Store Connect, \
        or activate the Paid Apps agreement.
        """)
    }

    // MARK: - Shells

    private func shell(isAI: Bool, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Spacing.small) {
            content()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(isAI ? Palette.aiSurface : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func stopped(title: String, caption: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Palette.warn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    if let caption {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                    }
                    Text(title)
                        .font(.body.weight(.semibold))
                }
            }
            content()
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A failure is amber, never purple (README — Design system, state
        // colours).
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// The stop on screen, so a new one slides in (effect 5); nil while
    /// the run hasn't stopped.
    private func failureKey(_ phase: ReviewShotsRun.Phase?) -> String? {
        switch phase {
        case .paywallNotFound?: "paywallNotFound"
        case .noPrices?: "noPrices"
        default: nil
        }
    }
}
