//
//  MCPPageTestsJSON.swift
//  Atlas
//

import Foundation

/// The page test tools' JSON: App Store Connect's tests with their
/// treatments, what each placement can be tested with now, and the tests
/// assistants proposed.
enum MCPPageTestsJSON {
    /// What `get_page_tests` says about results, which the API doesn't give.
    static let resultsNote = String(localized: """
    App Store Connect’s API doesn’t give a test’s results (impressions, conversion rate, improvement, confidence): \
    they’re in App Store Connect → Product Page Optimization. A treatment the person applied to the page after the \
    test shows appliedToPage.
    """)

    /// The rules every proposal follows.
    static let rules = String(localized: """
    App Store Connect runs one test at a time: a test that isn’t over (a draft included) refuses another until it ends \
    or the draft is deleted. Atlas tests one placement at a time (header or searchResults) with one treatment against \
    the live page; trafficProportion is the percent of visitors who see the treatment (1 to 100). The person creates \
    the test from Review & Push; it stays a draft unless they send it to App Review. Atlas proposes deleting a draft \
    only: a running test is stopped in App Store Connect (the API can’t).
    """)

    static func test(_ test: ProductPageExperiment, treatments: [(ProductPageTreatment, [ProductPageTreatmentLocalization])]?) -> JSONValue {
        var json: [String: JSONValue] = [
            "testId": .string(test.id),
            "name": test.name.map(JSONValue.string) ?? .null,
            "state": test.state.map(JSONValue.string) ?? .null,
            "stateTitle": .string(test.stateTitle),
            "isOver": .bool(test.isFinished),
            "results": .null,
        ]
        if let traffic = test.trafficProportion { json["trafficProportion"] = .int(traffic) }
        if let platform = test.platform { json["platform"] = .string(platform) }
        if let required = test.reviewRequired { json["reviewRequired"] = .bool(required) }
        if let start = test.startDate { json["startDate"] = .string(start.formatted(.iso8601)) }
        if let end = test.endDate { json["endDate"] = .string(end.formatted(.iso8601)) }
        if let treatments {
            json["treatments"] = .array(treatments.map { treatment, localizations in
                var item: [String: JSONValue] = [
                    "treatmentId": .string(treatment.id),
                    "name": treatment.name.map(JSONValue.string) ?? .null,
                    "languages": .array(localizations.map(language)),
                ]
                if let promoted = treatment.promotedDate { item["appliedToPage"] = .string(promoted.formatted(.iso8601)) }
                return .object(item)
            })
        } else {
            json["treatments"] = "Left out: pass testId to read this test's treatments."
        }
        return .object(json)
    }

    private static func language(_ localization: ProductPageTreatmentLocalization) -> JSONValue {
        [
            "locale": localization.locale.map(JSONValue.string) ?? .null,
            "placements": .array(localization.placements.map { placement in
                var item: [String: JSONValue] = [
                    "placement": .string(placementName(placement.placementType)),
                ]
                if let group = placement.placementGroup { item["placementGroup"] = .string(group) }
                if let state = placement.state { item["state"] = .string(state) }
                if let asset = placement.asset {
                    item["assetId"] = .string(asset.id)
                    item["media"] = .string(asset.media.rawValue)
                }
                return .object(item)
            }),
        ]
    }

    /// "header", "searchResults", or Apple's type (screenshots, App
    /// Previews) as it is.
    static func placementName(_ type: String?) -> String {
        guard let type else { return "unknown" }
        return ProductPageTestPlacement.allCases.first { $0.placementType == type }?.rawValue ?? type
    }

    static func testable(
        _ readiness: ProductPageTestReadiness, canAskForVariant: Bool, library: [AssetLibraryFile]?, refData: AssetLibraryRefData?
    ) -> JSONValue {
        var json: [String: JSONValue] = ["placement": .string(readiness.placement.rawValue)]
        if let kind = readiness.kind {
            json["artwork"] = [
                "kind": .string(kind.rawValue),
                "pixelSize": .string(kind.pixelSize.title),
                "languages": .array(readiness.controlLocales.map(JSONValue.string)),
                "waitingInReviewAndPush": .array(readiness.waitingLocales.map(JSONValue.string)),
            ]
        } else {
            json["artwork"] = .null
        }
        if let variant = readiness.variant {
            json["variant"] = [
                "change": .string(variant.change),
                "idea": .string(variant.idea),
                "languages": .array(readiness.variantLocales.map(JSONValue.string)),
                "errors": .array(readiness.variantErrors.map { JSONValue.string($0.text) }),
                "client": .string(variant.client),
                "madeAt": .string(variant.madeAt.formatted(.iso8601)),
            ]
        } else {
            json["variant"] = .null
        }
        if let reason = readiness.variantBlockReason {
            json["variantBlockedBecause"] = .string(reason)
            if readiness.kind != nil, readiness.variant == nil {
                json["askForVariant"] = canAskForVariant
                    ? "propose_page_test with treatment: variant asks the Autopilot run for one; then next_step says design_variant."
                    : "The app has no finished Autopilot run to ask for a variant."
            }
        }
        if let library {
            let candidates = ProductPageTestProposer.libraryCandidates(library, placement: readiness.placement, refData: refData)
            json["library"] = .array(candidates.prefix(maxLibraryItems).map(libraryItem))
            if candidates.count > maxLibraryItems { json["libraryLeftOut"] = .int(candidates.count - maxLibraryItems) }
        }
        return .object(json)
    }

    static let maxLibraryItems = 20

    private static func libraryItem(_ file: AssetLibraryFile) -> JSONValue {
        var item: [String: JSONValue] = [
            "assetId": .string(file.id),
            "name": .string(file.title),
            "state": .string(file.stateTitle),
        ]
        if let size = file.pixelSize { item["pixelSize"] = .string(size.title) }
        if let locale = locale(in: file.referenceName) { item["locale"] = .string(locale) }
        if let date = file.createdDate { item["uploadedAt"] = .string(date.formatted(.iso8601)) }
        return .object(item)
    }

    /// The language an Atlas reference name carries ("Autopilot · de-DE ·
    /// Header 21:9"), if any.
    static func locale(in referenceName: String?) -> String? {
        referenceName?.components(separatedBy: " · ").lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { StoreLocaleCatalog.locale(code: $0) != nil }
    }

    static func proposal(_ proposal: ProductPageTestProposal) -> JSONValue {
        var json: [String: JSONValue] = [
            "proposalId": .string(proposal.id),
            "name": .string(proposal.name),
            "placement": .string(proposal.placement.rawValue),
            "status": .string(proposal.status.rawValue),
            "treatment": .string(proposal.treatment.toolValue),
            "trafficProportion": .int(proposal.trafficProportion),
            "locales": .array(proposal.locales.map(JSONValue.string)),
            "startsTest": .bool(proposal.startsTest),
            "reason": .string(proposal.reason),
            "client": .string(proposal.client),
            "receivedAt": .string(proposal.receivedAt.formatted(.iso8601)),
        ]
        if !proposal.evidence.isEmpty { json["evidence"] = .array(proposal.evidence.map(JSONValue.string)) }
        proposal.layers?.add(to: &json)
        let assets = proposal.treatment.libraryAssets
        if !assets.isEmpty {
            json["assets"] = .array(assets.map { ["locale": .string($0.locale), "assetId": .string($0.assetID), "name": .string($0.name)] })
        }
        if let outcome = proposal.outcome { json["outcome"] = .string(outcome) }
        if let decided = proposal.decidedAt { json["decidedAt"] = .string(decided.formatted(.iso8601)) }
        return .object(json)
    }
}
