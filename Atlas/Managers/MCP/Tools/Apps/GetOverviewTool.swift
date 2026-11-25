//
//  GetOverviewTool.swift
//  Atlas
//

import Foundation

/// `get_overview`: one app at a glance, as Atlas's Overview shows it: the
/// store page (version, languages, what's missing, machine-translated or
/// over the limit), pricing (products, countries at Apple's price or set by
/// hand, held back), App Information (age rating, App Privacy, App Review
/// contact), what waits in Review & Push per section, and the suggestions
/// and reviews waiting. Each part that can't be read says so. Read-only.
struct GetOverviewTool: MCPTool {
    var reviews = ReviewsStore.shared

    let definition = MCPToolDefinition(
        name: "get_overview",
        title: "Get an app's overview",
        description: """
        Reads one app at a glance, as Atlas's Overview shows it: storePage (the version being prepared and its state, \
        how many languages, completeness 0–1, fields missing, machine-translated or over the limit), pricing \
        (subscriptions and in-app purchases with their base price, countries at Apple's equalized price or set by \
        hand, countries where the price likely holds people back), appInformation (age rating, App Privacy, \
        privacy URLs missing, App Review contact complete), waiting (changes in Review & Push per section), \
        suggestionsToReview, reviews needing a reply, and appReview (the App Review checks' last report: risks, the \
        most serious three; get_review_risks has the evidence and fixes). A part Atlas couldn't read has an error instead. Start here \
        to decide what to work on, then read the section's own get_ tool. Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let services = context.workspace.services
        async let storePage = Self.part { try await Self.json(services.storePage.summary(for: app)) }
        async let pricing = Self.part { try await Self.json(services.pricing.summary(for: app)) }
        async let information = Self.part { try await Self.json(services.appInformation.summary(for: app)) }
        let changes = context.workspace.changes.changes(for: app.id)
        var waiting: [String: JSONValue] = [:]
        for section in AppWorkspaceSection.allCases {
            let count = changes.count { $0.section == section }
            if count > 0 { waiting[section.rawValue] = .int(count) }
        }
        let archive = reviews.archive(for: app.id)
        var result: [String: JSONValue] = await [
            "appId": .string(app.id),
            "app": .string(app.name),
            "storePage": storePage,
            "pricing": pricing,
            "appInformation": information,
            "pricingMode": .string(context.workspace.pricingModes.mode(for: app.id).rawValue),
            "waiting": .object(waiting),
            "waitingTotal": .int(changes.count),
            "suggestionsToReview": .int(context.workspace.suggestions?.toReview(for: app.id).count ?? 0),
        ]
        result["appReview"] = Self.appReview(ReviewRiskCenter.shared.lastReport(for: app.id))
        if archive.fetchedAt != nil {
            result["reviews"] = ["needReply": .int(archive.needsReplyCount), "repliesSuggested": .int(archive.openSuggestionCount)]
        }
        return .read(.object(result), target: String(localized: "\(app.name) · Overview", comment: "kind:other"))
    }

    /// The App Review checks' last report, short: how many risks, the most
    /// serious three, and when it ran. get_review_risks has the rest.
    static func appReview(_ report: ReviewRiskReport?) -> JSONValue {
        guard let report else {
            return ["checked": false, "next": "Call get_review_risks to check what App Review may reject."]
        }
        return [
            "checked": true,
            "checkedAt": .string(report.checkedAt.ISO8601Format()),
            "summary": .string(report.summary),
            "risks": .int(report.risks.count),
            "blocksReview": .int(report.blockingCount),
            "notChecked": .int(report.notChecked.count),
            "top": .array(report.risks.prefix(3).map { risk in
                ["title": .string(risk.title), "guideline": .string(risk.guideline), "level": .string(risk.level.rawValue)]
            }),
            "next": "Call get_review_risks for the evidence and the fix of each.",
        ]
    }

    /// A part of the overview, or why it couldn't be read.
    private static func part(_ read: @MainActor () async throws -> JSONValue) async -> JSONValue {
        do {
            return try await read()
        } catch {
            return ["error": .string(error.localizedDescription)]
        }
    }

    static func json(_ summary: StorePageSummary) -> JSONValue {
        [
            "version": summary.versionString.map(JSONValue.string) ?? .null,
            "state": summary.versionState.map(JSONValue.string) ?? .null,
            "editable": .bool(summary.hasEditableVersion),
            "languages": .int(summary.localeCount),
            "locales": .array(summary.localeCodes.map(JSONValue.string)),
            "completeness": .double((summary.completeness * 100).rounded() / 100),
            "missingFields": .int(summary.missingCount),
            "machineTranslated": .int(summary.machineTranslatedCount),
            "overLimit": .int(summary.overLimitCount),
        ]
    }

    static func json(_ summary: PricingSummary) -> JSONValue {
        [
            "subscriptionGroups": .int(summary.groupCount),
            "subscriptions": .int(summary.subscriptionCount),
            "inAppPurchases": .int(summary.inAppPurchaseCount),
            "products": .array(summary.products.map { product in
                [
                    "productId": .string(product.id),
                    "name": .string(product.name),
                    "duration": .string(product.duration),
                    "basePrice": product.basePrice.map(JSONValue.string) ?? .null,
                    "inAppPurchase": .bool(product.isInAppPurchase),
                ]
            }),
            "countriesFor": summary.reportedProductName.map(JSONValue.string) ?? .null,
            "equalizedCountries": .int(summary.equalizedTerritoryCount),
            "customCountries": .int(summary.customTerritoryCount),
            "heldBackCountries": summary.heldBackTerritoryCount.map(JSONValue.int) ?? .null,
            "baseCountry": .string(summary.baseTerritoryName),
        ]
    }

    static func json(_ summary: AppInformationSummary) -> JSONValue {
        var object: [String: JSONValue] = [
            "ageRating": summary.ageRating.map(JSONValue.string) ?? .null,
            "category": summary.category.map(JSONValue.string) ?? .null,
            "appPrivacy": [
                "worksheet": .string(summary.privacy.worksheetTitle),
                "openQuestions": .int(summary.privacy.openQuestionCount),
            ],
            "appReviewComplete": .bool(summary.isAppReviewComplete),
        ]
        if let urls = summary.privacyURLs {
            object["privacyPolicyMissing"] = .int(urls.missingPolicyCount)
        }
        return .object(object)
    }
}
