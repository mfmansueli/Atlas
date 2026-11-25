//
//  ReviewShotsCardPanel.swift
//  Atlas
//

import SwiftUI

/// A product card's App Review screenshot (README — Pricing: review
/// screenshots): missing, with the Screenshots capture of the paywall to
/// use when there is one; waiting its turn or being captured in a run; the
/// assistant's image to accept or dismiss; accepted and waiting in Review &
/// Push; or in App Store Connect. Review Screenshot… (a file, by hand)
/// stays on every card that needs one.
struct ReviewShotsCardPanel: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        let state = viewModel.reviewShotState(for: product)
        Group {
            switch state {
            case .unknown:
                EmptyView()
            case let .missing(capture):
                missing(capture: capture)
            case let .failed(remote):
                warning(remote.title, detail: String(localized: "Apple refused the last screenshot. Choose another."))
            case let .notCaptured(miss):
                warning(String(localized: "Review screenshot missing"), detail: miss.text)
                    .accessibilityIdentifier("pricing.card.reviewShots.notCaptured")
            case let .queued(text):
                queued(text)
            case let .working(steps, step, client, plan):
                working(steps: steps, step: step, client: client, plan: plan)
            case let .suggested(item):
                suggested(item)
            case let .accepted(item):
                accepted(item)
            case let .uploaded(remote):
                uploaded(remote)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.card.reviewShots")
    }

    // MARK: - Missing

    private func missing(capture: ReviewShotsCapture?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            warning(
                String(localized: "Review screenshot missing"),
                detail: capture == nil
                    ? String(localized: "App Review needs a screenshot of the purchase screen. Until it has one, the product stays in Missing Metadata.")
                    : String(localized: "Screenshots already has a capture of the paywall.")
            )
            if let capture {
                captureBox(capture)
            }
        }
    }

    private func warning(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Palette.warn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Palette.label)
                    .accessibilityIdentifier("pricing.card.reviewScreenshot.state")
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            reviewScreenshotButton(String(localized: "Review Screenshot…"))
        }
    }

    private func captureBox(_ capture: ReviewShotsCapture) -> some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            ReviewShotThumbnail(
                url: capture.url(appID: viewModel.app.id, root: viewModel.setup.capturesRoot), width: 52,
                label: String(localized: "\(capture.title), from Screenshots")
            )
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(capture.title)
                    .font(.callout.weight(.semibold))
                Text(capture.origin)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                FlowLayout(spacing: Spacing.small) {
                    Button("Use This Capture") { useCapture(for: [product]) }
                        .rowActionButton()
                        .accessibilityLabel(Text("Use \(capture.title) for \(product.name)"))
                        .accessibilityIdentifier("pricing.card.reviewShots.useCapture")
                    let others = viewModel.productsMissingReviewShot
                    if others.count >= 2 {
                        Button(String(localized: "Use for All \(others.count)")) { useCapture(for: others) }
                            .help(String(localized: "One image for \(others.count) products. It must clearly show each."))
                            .accessibilityIdentifier("pricing.card.reviewShots.useForAll")
                    }
                }
                .padding(.top, Spacing.xxSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.medium)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.card.reviewShots.capture")
    }

    // MARK: - A run

    private func queued(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text("Next in this run")
                .font(.callout.weight(.semibold))
            Text(text)
                .font(.callout)
                .foregroundStyle(Palette.label2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pricing.card.reviewShots.queued")
    }

    private func working(steps: [String], step: String?, client: String, plan: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack(spacing: Spacing.xSmall) {
                // Effect 2: the card's still spark (`aiWorking`) shows it
                // works; nothing breathes here.
                Text("\(client) is capturing the \(plan) plan")
                    .font(.callout.weight(.semibold))
            }
            // Done steps with a checkmark, the current one with an
            // ellipsis (README-DS §13: symbols, not text characters).
            ForEach(steps, id: \.self) { done in
                Label(done, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            if let step {
                Label(step, systemImage: "ellipsis")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pricing.card.reviewShots.working")
    }

    // MARK: - Suggested

    private func suggested(_ item: ReviewShotItem) -> some View {
        let details = item.details
        return HStack(alignment: .top, spacing: Spacing.medium) {
            Button { viewModel.setup.reviewShotsPreviewProductID = product.id } label: {
                ReviewShotThumbnail(url: item.fileURL, width: 64, label: details?.heading ?? String(localized: "Review screenshot"))
            }
            .buttonStyle(.plain)
            .help(String(localized: "Show Larger"))
            .accessibilityLabel(Text("Show \(product.name)’s review screenshot larger"))
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.xSmall) {
                    Label("Suggested", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ai)
                    if let client = details?.client {
                        HStack(spacing: Spacing.xxSmall) {
                            AssistantMonogram(letters: ChangeSource.assistant(client: client).monogram ?? "AI")
                            Text(client).font(.subheadline)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Text(details?.heading ?? String(localized: "Review screenshot"))
                    .font(.callout.weight(.semibold))
                if let details, details.isFromAssistant {
                    Text(details.capturedLine())
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let checks = details?.checks, !checks.isEmpty {
                    FlowLayout(spacing: Spacing.small) {
                        ForEach(checks, id: \.self) { check in
                            Label(check, systemImage: "checkmark")
                                .font(.subheadline)
                                .foregroundStyle(Palette.label2)
                        }
                    }
                }
                HStack(spacing: Spacing.small) {
                    Button("Show Larger") { viewModel.setup.reviewShotsPreviewProductID = product.id }
                        .accessibilityIdentifier("pricing.card.reviewShots.showLarger")
                    Spacer(minLength: Spacing.small)
                    Button("Dismiss") { dismiss() }
                        .accessibilityIdentifier("pricing.card.reviewShots.dismiss")
                    Button("Accept") { accept() }
                        .rowActionButton()
                        .accessibilityIdentifier("pricing.card.reviewShots.accept")
                }
                .padding(.top, Spacing.xxSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.medium)
        .suggestionSurface(isSettling: isSettling, arrivalKey: item.changeID + item.summary, arrivedAt: item.arrivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggested review screenshot for \(product.name)"))
        .accessibilityIdentifier("pricing.card.reviewShots.suggested")
    }

    // MARK: - Accepted and uploaded

    private func accepted(_ item: ReviewShotItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            acceptedRow(item)
            if let offer = viewModel.reviewShotSizeOffer(for: product) {
                ReviewShotSizeOfferBox(viewModel: viewModel, product: product, offer: offer)
            }
        }
    }

    private func acceptedRow(_ item: ReviewShotItem) -> some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            ReviewShotThumbnail(url: item.fileURL, width: 44, label: item.details?.heading ?? String(localized: "Review screenshot"))
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.small) {
                    Text("Review screenshot")
                        .font(.callout.weight(.semibold))
                    Pill(text: String(localized: "Not pushed"), style: .accent)
                        .fixedSize()
                        .accessibilityIdentifier("pricing.card.reviewScreenshot.state")
                }
                Text(item.details?.acceptedLine ?? String(localized: "\(item.summary) · sent when you push"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            reviewScreenshotButton(String(localized: "Replace…"))
            Button("Undo") { undo() }
                .accessibilityLabel(Text("Undo \(product.name)’s review screenshot"))
                .accessibilityIdentifier("pricing.card.reviewShots.undo")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.card.reviewShots.accepted")
    }

    /// In App Store Connect: since when, the product's state as Atlas read
    /// it back (a pill), and why it's still Missing Metadata when it is.
    private func uploaded(_ remote: PurchaseReviewScreenshotState) -> some View {
        let state = remote.isUploaded ? viewModel.reviewShotProductState(for: product) : nil
        return HStack(alignment: .top, spacing: Spacing.medium) {
            if remote.isUploaded, let url = viewModel.reviewShotUploadedFile(for: product) {
                ReviewShotThumbnail(url: url, width: 44, label: String(localized: "\(product.name)’s review screenshot", comment: "kind:accessibility-label"))
            }
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                HStack(spacing: Spacing.small) {
                    Text("Review screenshot")
                        .font(.callout.weight(.semibold))
                    if let state {
                        Pill(text: state.title, style: state.pillStyle)
                            .fixedSize()
                            .accessibilityLabel(Text(String(localized: "In App Store Connect: \(state.title)", comment: "kind:accessibility-label")))
                            .accessibilityIdentifier("pricing.card.reviewShots.appleState")
                    }
                }
                Label(
                    remote.isUploaded ? viewModel.reviewShotUploadedLine(for: product) : remote.title,
                    systemImage: remote.isUploaded ? "checkmark.circle" : "clock"
                )
                .font(.subheadline)
                .foregroundStyle(remote.isUploaded ? Palette.ok : Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pricing.card.reviewScreenshot.state")
                if let cause = state?.cause {
                    Text(cause)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pricing.card.reviewShots.cause")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            reviewScreenshotButton(String(localized: "Replace…"))
        }
    }

    private func reviewScreenshotButton(_ title: String) -> some View {
        Button(title) { viewModel.openReviewScreenshot(for: product) }
            .accessibilityIdentifier("pricing.card.reviewScreenshot")
    }

    // MARK: - Actions

    private func useCapture(for products: [PricingProduct]) {
        do {
            try viewModel.useCapture(for: products)
            viewModel.sayReviewShots(viewModel.useCaptureToast(for: products)) { [viewModel] in
                viewModel.undoReviewShots(products)
            }
        } catch let error as PurchaseReviewScreenshotProblem {
            viewModel.sayReviewShots(error.localizedDescription, offersReview: false)
        } catch {
            let copy = AppleErrorCopy(String(localized: "The capture couldn’t be used.", comment: "kind:error"), error: error)
            viewModel.sayReviewShots(copy.text, offersReview: false)
        }
    }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: { [viewModel, product] in
            viewModel.acceptReviewShot(for: product)
            isSettling = false
            viewModel.sayReviewShots(String(localized: "\(product.name): review screenshot accepted. In Review & Push.")) {
                viewModel.undoReviewShot(for: product)
            }
        }
    }

    private func dismiss() {
        let id = viewModel.reviewShotChangeID(for: product)
        guard let change = viewModel.queue.change(id: id) else { return }
        let details = viewModel.setup.details.details(for: id)
        AIDecided.dismiss(reduceMotion: reduceMotion) { viewModel.dismissReviewShot(for: product) }
        viewModel.sayReviewShots(
            String(localized: "Dismissed. \(product.name) still needs a review screenshot."), offersReview: false
        ) { [viewModel] in
            viewModel.restoreReviewShot(change, details: details)
        }
    }

    private func undo() {
        viewModel.undoReviewShot(for: product)
        viewModel.sayReviewShots(String(localized: "Undone. Nothing was sent."), offersReview: false)
    }
}
