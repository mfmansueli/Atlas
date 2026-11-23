//
//  ProductPageTestProposer.swift
//  Atlas
//

import Foundation

/// Checks an assistant's proposed test against what App Store Connect and
/// “Test with Product Page Optimization…” allow, and makes the proposal
/// that waits for the person, or says why not and how to fix it. Apple
/// runs one test at a time, so a test that isn't over refuses a new one,
/// unless it's a draft whose deletion already waits in Review & Push.
struct ProductPageTestProposer {
    /// What the assistant sent.
    struct Input: Hashable, Sendable {
        var name: String?
        var placement: ProductPageTestPlacement
        var trafficProportion: Int?
        /// "variant" or "library".
        var treatment: String
        /// Library treatments: locale → asset ID.
        var assets: [String: String] = [:]
        /// Nil: every language the treatment has.
        var locales: [String]?
        var startsTest = false
        var reason: String
        var evidence: [String] = []
        var layers: SuggestionLayers?
    }

    enum Outcome: Hashable, Sendable {
        /// `asksForVariant`: no variant yet, so Atlas asks the run for one
        /// and the test waits for it. `notes` are what the assistant should
        /// know (the current image still waits, a delete goes first).
        case queued(ProductPageTestProposal, asksForVariant: Bool, notes: [String])
        case refused(code: String, reason: String)
    }

    var extras: ScreenshotExtras?
    var primaryLocale: String
    /// The app's tests, finished ones too.
    var tests: [ProductPageExperiment]
    /// Tests whose deletion waits in Review & Push.
    var queuedDeletions: Set<String> = []
    /// The app's library; nil when it couldn't be read.
    var library: [AssetLibraryFile]?
    /// What App Store Connect says about sizes; nil when it couldn't be
    /// read (Autopilot's sizes are checked instead).
    var refData: AssetLibraryRefData?
    /// The app has a finished Autopilot run to ask for a variant.
    var canAskForVariant = false
    var client: String
    var now: Date

    func propose(_ input: Input) -> Outcome {
        if let refusal = textRefusal(input) { return refusal }
        let traffic = input.trafficProportion ?? 50
        guard ProductPageTestProposal.trafficRange.contains(traffic) else {
            return .refused(code: "traffic_out_of_range", reason: String(localized: """
            trafficProportion is the percent of the page’s visitors who see the treatment: send a whole number from 1 to 100 \
            (50 splits them evenly).
            """))
        }
        var notes: [String] = []
        if let blocking = blockingTest {
            guard blocking.isDraft, queuedDeletions.contains(blocking.id) else { return .refused(code: "test_in_progress", reason: inProgress(blocking)) }
            notes.append(String(localized: "Deleting the draft “\(blocking.name ?? blocking.id)” waits in Review & Push: the person pushes that first."))
        }
        let readiness = ProductPageTestReadiness(extras: extras, placement: input.placement, primary: primaryLocale)
        if !readiness.waitingLocales.isEmpty {
            notes.append(String(localized: """
            The current \(input.placement.title.lowercased()) image still waits in Review & Push in \(readiness.waitingLocales.count) \
            languages: the test compares with what the page shows now, so the person should push it first.
            """))
        }
        let treatment: ProductPageTestTreatmentSource
        let locales: [String]
        let asksForVariant: Bool
        switch chosenTreatment(input, readiness: readiness) {
        case let .failure(refusal): return refusal.outcome
        case let .success(made): (treatment, locales, asksForVariant) = made
        }
        let sentName = input.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = sentName.isEmpty ? Self.defaultName(placement: input.placement, treatment: treatment) : sentName
        let proposal = ProductPageTestProposal(
            id: ProductPageTestProposal.makeID(), name: name, placement: input.placement, trafficProportion: traffic,
            treatment: treatment, locales: locales, startsTest: input.startsTest,
            reason: input.reason.trimmingCharacters(in: .whitespacesAndNewlines), evidence: input.evidence, client: client, receivedAt: now,
            layers: input.layers
        )
        return .queued(proposal, asksForVariant: asksForVariant, notes: notes)
    }

    /// "Header: Interface vs Outcome", "Search results: Interface vs Library image".
    static func defaultName(placement: ProductPageTestPlacement, treatment: ProductPageTestTreatmentSource) -> String {
        let treatmentName = switch treatment {
        case .variant: ProductPageTestRequest.defaultTreatmentName
        case .library: String(localized: "Library image")
        }
        return "\(placement.title): \(ProductPageTestRequest.defaultControlName) vs \(treatmentName)"
    }

    /// The app's iOS test that isn't over: App Store Connect runs one at a
    /// time and refuses a second draft.
    var blockingTest: ProductPageExperiment? {
        let platform = ProductPageExperimentRequests.platform
        return tests.first { !$0.isFinished && ($0.platform ?? platform) == platform }
    }

    /// The library images a placement's test can show: processed, and of
    /// a size App Store Connect takes there. Newest first, as listed.
    static func libraryCandidates(
        _ files: [AssetLibraryFile], placement: ProductPageTestPlacement, refData: AssetLibraryRefData?
    ) -> [AssetLibraryFile] {
        files.filter { file in
            guard file.media == .image, let size = file.pixelSize, !unusableStates.contains(file.state ?? "") else { return false }
            return ProductPageTestReadiness.takes(size, for: placement, refData: refData)
        }
    }

    /// Not uploaded, still processing or failed.
    static let unusableStates: Set<String> = ["AWAITING_UPLOAD", "UPLOAD_COMPLETE", "FAILED"]

    // MARK: - Checks

    private struct Refusal: Error {
        var code: String
        var reason: String

        var outcome: Outcome { .refused(code: code, reason: reason) }
    }

    private func textRefusal(_ input: Input) -> Outcome? {
        let reason = input.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if reason.isEmpty {
            return .refused(code: "no_reason", reason: String(localized: "Send reason: why this test, in a sentence the person reads."))
        }
        if let refusal = AssistantTextLimits.whyRefusal(reason, field: "reason") {
            return .refused(code: "too_long", reason: refusal)
        }
        let name = input.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.count > ProductPageTestProposal.maxName {
            return .refused(code: "too_long", reason: String(localized: "name is \(name.count) characters; keep it to \(ProductPageTestProposal.maxName)."))
        }
        return nil
    }

    private func inProgress(_ test: ProductPageExperiment) -> String {
        let name = test.name ?? test.id
        if test.isDraft {
            return String(localized: """
            “\(name)” is a draft, and App Store Connect runs one test at a time. Suggest deleting it first \
            (action: deleteDraft, testId: \(test.id)), then resend. The test waits for the delete.
            """)
        }
        return String(localized: """
        “\(name)” is \(test.stateTitle), and App Store Connect runs one test at a time. Propose this once it’s over: the \
        person stops a running test in App Store Connect (the API can’t stop one).
        """)
    }

    /// The treatment, its languages, and whether the run is asked for the
    /// variant.
    private func chosenTreatment(
        _ input: Input, readiness: ProductPageTestReadiness
    ) -> Result<(ProductPageTestTreatmentSource, [String], Bool), Refusal> {
        switch input.treatment {
        case "variant":
            variantTreatment(input, readiness: readiness)
        case "library":
            libraryTreatment(input).map { ($0.0, $0.1, false) }
        default:
            .failure(Refusal(code: "unknown_treatment", reason: String(localized: """
            treatment is "variant" (the Autopilot run's variant for this placement) or "library" (images already in the app's \
            library, with assets [{locale, assetId}] from get_page_tests).
            """)))
        }
    }

    private func variantTreatment(
        _ input: Input, readiness: ProductPageTestReadiness
    ) -> Result<(ProductPageTestTreatmentSource, [String], Bool), Refusal> {
        guard readiness.kind != nil else {
            return .failure(Refusal(code: "no_artwork", reason: readiness.variantBlockReason ?? ""))
        }
        guard let variant = readiness.variant else {
            guard canAskForVariant else {
                return .failure(Refusal(code: "no_variant", reason: String(localized: """
                There’s no \(input.placement.title.lowercased()) variant yet, and Atlas can’t ask for one: the app has no \
                finished Autopilot run. The person runs Autopilot (with the header and search artwork) first.
                """)))
            }
            return chosen(input.locales, from: readiness.controlLocales).map { (.variant(change: ""), $0, true) }
        }
        if let reason = readiness.variantBlockReason {
            return .failure(Refusal(code: "variant_breaks_rules", reason: reason))
        }
        return chosen(input.locales, from: readiness.variantLocales).map { (.variant(change: variant.change), $0, false) }
    }

    private func libraryTreatment(_ input: Input) -> Result<(ProductPageTestTreatmentSource, [String]), Refusal> {
        guard let library else {
            return .failure(Refusal(code: "library_unreadable", reason: String(localized: """
            Atlas couldn’t read the app’s library from App Store Connect. Try again, or use the variant (treatment: variant).
            """)))
        }
        guard !input.assets.isEmpty else {
            return .failure(Refusal(code: "no_assets", reason: String(localized: """
            Send assets: [{locale, assetId}], one image per language, from get_page_tests' testable.library.
            """)))
        }
        var assets: [ProductPageTestLibraryAsset] = []
        for (locale, assetID) in input.assets.sorted(by: { Self.isBefore($0.key, $1.key, primary: primaryLocale) }) {
            guard let file = library.first(where: { $0.id == assetID }) else {
                return .failure(Refusal(code: "unknown_asset", reason: String(localized: "The app’s library has no image “\(assetID)”. Use get_page_tests.")))
            }
            guard file.media == .image, let size = file.pixelSize else {
                return .failure(Refusal(code: "not_an_image", reason: String(localized: "“\(file.title)” isn’t an image: a test shows an image here.")))
            }
            if Self.unusableStates.contains(file.state ?? "") {
                return .failure(Refusal(code: "asset_not_ready", reason: String(localized: """
                “\(file.title)” is \(file.stateTitle.lowercased()) in the library: only a processed image can go on a test.
                """)))
            }
            if !ProductPageTestReadiness.takes(size, for: input.placement, refData: refData) {
                let sizes = ProductPageTestReadiness.sizesTitle(for: input.placement, refData: refData)
                return .failure(Refusal(code: "wrong_size", reason: String(localized: """
                “\(file.title)” is \(size.title); App Store Connect takes \(sizes) for the \(input.placement.title.lowercased()).
                """)))
            }
            assets.append(ProductPageTestLibraryAsset(locale: locale, assetID: file.id, name: file.title, pixelSize: size))
        }
        let locales = assets.map(\.locale)
        if let wanted = input.locales, Set(wanted) != Set(locales) {
            return .failure(Refusal(code: "locales_mismatch", reason: String(localized: """
            A library treatment needs one image per language: send assets for exactly the languages in locales, or leave locales out.
            """)))
        }
        return .success((.library(assets), locales))
    }

    /// The languages asked for, all of `available` when none were; a
    /// language the treatment doesn't have refuses it.
    private func chosen(_ wanted: [String]?, from available: [String]) -> Result<[String], Refusal> {
        guard let wanted, !wanted.isEmpty else {
            guard !available.isEmpty else {
                return .failure(Refusal(code: "no_languages", reason: String(localized: "The treatment has no language to test.")))
            }
            return .success(available)
        }
        let missing = wanted.filter { !available.contains($0) }
        guard missing.isEmpty else {
            let list = available.formatted(.list(type: .and))
            return .failure(Refusal(code: "unknown_locale", reason: String(localized: """
            The treatment has no \(missing.formatted(.list(type: .and))). It has \(list): send some of those, or leave locales out for all.
            """)))
        }
        return .success(available.filter(wanted.contains))
    }

    private static func isBefore(_ lhs: String, _ rhs: String, primary: String) -> Bool {
        if lhs == primary { return rhs != primary }
        if rhs == primary { return false }
        return lhs < rhs
    }
}
