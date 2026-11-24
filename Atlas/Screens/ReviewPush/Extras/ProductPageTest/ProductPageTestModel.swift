//
//  ProductPageTestModel.swift
//  Atlas
//

import Foundation
import Observation

/// “Test with Product Page Optimization…” for one placement: asks the
/// run's design source for a variant with one idea changed (the current
/// image shows the interface, the variant the outcome), shows it rendered
/// and checked in every language, then makes the test through the API, or
/// exports both variants with the steps to make it by hand. It never says
/// a test was made when it wasn't: only `ProductPageTestOutcome.created`
/// does.
@MainActor
@Observable
final class ProductPageTestModel: Identifiable {
    enum Phase: Hashable {
        /// Nothing asked yet.
        case intro
        /// Waiting for the design source's variant.
        case asking
        case variantReady
        case testing
        case finished
    }

    /// One language: the current image and the variant, with the
    /// variant's findings.
    struct LocaleRow: Hashable, Identifiable {
        var locale: String
        var name: String
        var control: URL?
        var treatment: URL?
        var checks: [ArtworkCheck]
        /// A proposed treatment from the app's library: the image's name.
        var libraryName: String?

        var id: String { locale }
    }

    let id = UUID()
    let placement: ProductPageTestPlacement
    let kind: AutopilotArtworkKind
    private(set) var plan: ExtrasReviewPlan
    var phase: Phase
    var run: ProductPageTestRun?
    /// Why the variant can't be asked for, or that the person asks their
    /// assistant themselves.
    var notice: String?
    /// The assistant asked for the variant (the run's client).
    var assistantName: String?
    /// The Claude Code Atlas started for the variant, if it did.
    var launchedRunID: ClaudeCodeRun.ID?
    /// Atlas is starting Claude Code: nobody's idle yet.
    private(set) var isStarting = false
    /// The test an assistant proposed (`propose_page_test`), which the
    /// sheet opens prefilled with; nil when the person opened it.
    let proposal: ProductPageTestProposal?
    /// Sends the test to App Review once it's made; the proposal's choice
    /// to start with, off otherwise.
    var startsTest: Bool
    #if DEBUG
    /// DEBUG scenes: asks as soon as the sheet opens.
    var asksOnAppear = false
    #endif

    /// Records that the person made the proposed test, with the outcome's
    /// line, so it leaves Review & Push.
    @ObservationIgnored var onProposalMade: @MainActor (ProductPageTestProposal.ID, String) async -> Void = { _, _ in }
    @ObservationIgnored let environment: ProductPageTestEnvironment?
    @ObservationIgnored let fileURL: (_ fileID: String, _ pathExtension: String) -> URL
    @ObservationIgnored let exportFolder: URL
    /// Reads the app's extras again, once the variant is in.
    @ObservationIgnored let loadExtras: () async -> ScreenshotExtras?

    /// The sheet's first line.
    static let explanation = String(localized: """
    Tests one idea. Apple splits traffic between your page and this treatment; results show in App Store Connect.
    """)

    init(
        plan: ExtrasReviewPlan, placement: ProductPageTestPlacement, environment: ProductPageTestEnvironment?,
        fileURL: @escaping (String, String) -> URL, exportFolder: URL, loadExtras: @escaping () async -> ScreenshotExtras?,
        proposal: ProductPageTestProposal? = nil
    ) {
        self.plan = plan
        self.placement = placement
        kind = plan.kind(for: placement) ?? (placement == .header ? .header : .search)
        self.environment = environment
        self.fileURL = fileURL
        self.exportFolder = exportFolder
        self.loadExtras = loadExtras
        self.proposal = proposal
        startsTest = proposal?.startsTest ?? false
        phase = .intro
        if variant != nil || usesLibrary { phase = .variantReady }
    }

    var role: ArtworkTextRole { placement == .header ? .header : .search }
    var controlName: String { ProductPageTestRequest.defaultControlName }
    var treatmentName: String { usesLibrary ? String(localized: "Library image") : ProductPageTestRequest.defaultTreatmentName }

    /// The proposed treatment is images already in the app's library.
    var usesLibrary: Bool { !(proposal?.treatment.libraryAssets.isEmpty ?? true) }

    /// "Header: Interface vs Outcome", or the proposal's name.
    var testName: String {
        proposal?.name ?? String(localized: "\(placement.title): \(controlName) vs \(treatmentName)", comment: "kind:other")
    }

    /// The share of the page's visitors who see the treatment, in percent.
    var trafficProportion: Int { proposal?.trafficProportion ?? 50 }

    /// The variant for this placement, once one was made.
    var variant: ExtrasArtworkVariant? {
        guard let variant = plan.variant, variant.kind == kind, variant.role == role else { return nil }
        return variant
    }

    /// Primary language first; a proposal's languages only.
    var rows: [LocaleRow] {
        let assets = proposal?.treatment.libraryAssets ?? []
        var codes = assets.isEmpty ? plan.artwork.filter { $0.kind == kind }.map(\.locale) : assets.map(\.locale)
        if let proposal { codes = codes.filter(proposal.locales.contains) }
        let ordered = codes.filter { $0 == plan.primaryLocale } + codes.filter { $0 != plan.primaryLocale }
        return ordered.map { code in
            let control = plan.artwork.first { $0.kind == kind && $0.locale == code }
            let treatment = usesLibrary ? nil : variant?.files.first { $0.kind == kind && $0.locale == code }
            return LocaleRow(
                locale: code, name: ExtrasReviewPlanner.name(of: code), control: control.map { fileURL($0.fileID, "png") },
                treatment: treatment.map { fileURL($0.fileID, "png") }, checks: treatment?.checks ?? [],
                libraryName: assets.first { $0.locale == code }?.name
            )
        }
    }

    /// When the proposal asked the run for its variant and it isn't in
    /// yet, the sheet opens waiting for it.
    func adoptRequest(of run: AutopilotRun?) {
        guard phase == .intro, proposal != nil, let request = run?.variantRequest, request.role == role, request.kind == kind else { return }
        assistantName = run?.client
        phase = .asking
    }

    var variantErrors: [ArtworkCheck] { rows.flatMap(\.checks).filter(\.isError) }

    /// The current image still waits in Review & Push: the test's control
    /// is what the page shows now, so it should go first.
    var controlWaits: Bool { plan.controlWaits(placement) }

    var canCreateTest: Bool { createBlockReason == nil && phase == .variantReady }

    /// Why Create Test is off, or nil.
    var createBlockReason: String? {
        if usesLibrary {
            guard !rows.isEmpty else { return String(localized: "The suggestion has no language to test.") }
        } else if variant == nil {
            return String(localized: "The variant isn’t in yet.")
        }
        if let error = variantErrors.first {
            return String(localized: "The variant breaks one of Apple’s rules: \(error.text) Ask for another.")
        }
        guard environment != nil else { return String(localized: "These services can’t make tests in App Store Connect.") }
        return nil
    }

    // MARK: - Asking

    /// Asks the run's design source for the variant, and starts Claude
    /// Code for it when Atlas can.
    func ask(center: AutopilotCenter?, launcher: ClaudeCodeLauncher?) async {
        notice = nil
        guard let center, center.requestVariant(appID: plan.appID, role: role, kind: kind) else {
            notice = String(localized: "Screenshot Autopilot has no finished run for \(plan.appName) to ask. Run it again, then come back here.")
            return
        }
        assistantName = center.run(for: plan.appID)?.client
        phase = .asking
        launchedRunID = nil
        await startClaudeCode(center: center, launcher: launcher)
    }

    /// Starts Claude Code again for the variant still asked for, after it
    /// stopped or was stopped before sending it.
    func continueAsking(center: AutopilotCenter?, launcher: ClaudeCodeLauncher?) async {
        guard phase == .asking, let center, center.run(for: plan.appID)?.variantRequest != nil else { return }
        notice = nil
        await startClaudeCode(center: center, launcher: launcher)
    }

    private func startClaudeCode(center: AutopilotCenter, launcher: ClaudeCodeLauncher?) async {
        guard let launcher, launcher.canStart else {
            notice = String(localized: "Ask your assistant to continue \(plan.appName)’s run: next_step says what to design.")
            return
        }
        isStarting = true
        defer { isStarting = false }
        guard let id = await AutopilotContinuation.start(appID: plan.appID, appName: plan.appName, center: center, launcher: launcher) else {
            notice = String(localized: "Ask your assistant to continue \(plan.appName)’s run: next_step says what to design.")
            return
        }
        launchedRunID = id
    }

    func cancelAsking(center: AutopilotCenter?) {
        center?.cancelVariant(appID: plan.appID)
        phase = variant == nil ? .intro : .variantReady
        notice = nil
    }

    /// What's done and what's left while it waits for the variant; empty
    /// when nothing's asked.
    func steps(of run: AutopilotRun?) -> [ProductPageTestAskingStep] {
        guard phase == .asking, let request = run?.variantRequest else { return [] }
        return ProductPageTestAskingStep.steps(
            for: request, assistant: assistantName ?? run?.client ?? String(localized: "the assistant"),
            placement: placement.title.lowercased(), direction: plan.directionName.isEmpty ? nil : plan.directionName,
            languageCount: rows.count
        )
    }

    /// The Claude Code working on the variant: the one Atlas started
    /// for it, else the run's latest since it was asked for.
    func session(in launcher: ClaudeCodeLauncher?, run: AutopilotRun?) -> ClaudeCodeRun? {
        guard let launcher else { return nil }
        if let started = launcher.run(launchedRunID) { return started }
        guard let askedAt = run?.variantRequest?.askedAt else { return nil }
        return launcher.latestRun(appID: plan.appID, purpose: .autopilot, since: askedAt)
    }

    /// Nobody's working on the variant Atlas could start Claude Code
    /// for: it stopped (or was stopped) before sending it.
    func isIdle(session: ClaudeCodeRun?, run: AutopilotRun?, canStart: Bool) -> Bool {
        guard phase == .asking, canStart, !isStarting, let request = run?.variantRequest, request.receivedAt == nil else { return false }
        return session?.isActive != true
    }

    /// Picks up the variant once the assistant sent it.
    func reload() async {
        guard let extras = await loadExtras() else { return }
        plan.variant = extras.variant
        if phase == .asking, variant != nil {
            phase = .variantReady
            notice = nil
        }
    }

    // MARK: - The test

    /// What the run makes: each language the variant was rendered in (or
    /// the proposal's library image is for), with its current image for
    /// the export.
    var request: ProductPageTestRequest? {
        let assets = proposal?.treatment.libraryAssets ?? []
        let locales = rows.compactMap { row -> ProductPageTestLocale? in
            if usesLibrary {
                guard let asset = assets.first(where: { $0.locale == row.locale }) else { return nil }
                return ProductPageTestLocale(
                    locale: row.locale, treatmentFile: nil, treatmentPixelSize: asset.pixelSize, controlFile: row.control, libraryAsset: asset.asset
                )
            }
            guard let treatment = row.treatment else { return nil }
            return ProductPageTestLocale(locale: row.locale, treatmentFile: treatment, treatmentPixelSize: kind.pixelSize, controlFile: row.control)
        }
        guard !locales.isEmpty else { return nil }
        return ProductPageTestRequest(
            appID: plan.appID, appName: plan.appName, placement: placement, testName: testName, treatmentName: treatmentName,
            trafficProportion: trafficProportion, locales: locales, startsTest: startsTest, exportFolder: exportFolder
        )
    }

    /// Creates the test (a draft the person starts in App Store Connect,
    /// unless they send it to App Review), or exports both variants when
    /// the API can't. A proposed test made either way leaves Review & Push.
    func createTest() {
        guard canCreateTest, let environment, let request else { return }
        let run = ProductPageTestRun(request: request, environment: environment)
        run.onFinish = { [weak self] run in
            guard let self else { return }
            phase = .finished
            guard let proposal, let outcome = run.outcome else { return }
            switch outcome {
            case .created, .exported: await onProposalMade(proposal.id, outcome.detail)
            case .testInProgress, .failed: break
            }
        }
        self.run = run
        phase = .testing
        run.start()
    }
}
