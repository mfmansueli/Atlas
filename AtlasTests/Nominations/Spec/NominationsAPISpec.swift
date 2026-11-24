//
//  NominationsAPISpec.swift
//  AtlasTests
//

import Foundation

/// What App Store Connect API 4.6.1 (Apple's `openapi.oas.json`)
/// allows for `/v1/nominations`, copied from the spec: `GET`'s query
/// parameters with their allowed values and maxima, the attributes and
/// relationships `POST` and `PATCH` take, and the resources a page
/// includes. Tests check what Atlas sends and reads against it.
enum NominationsAPISpec {
    struct Parameter {
        var required = false
        /// The values a comma-separated list may hold; nil for free text.
        var values: [String]?
        var maximum: Int?
    }

    /// `GET /v1/nominations`.
    static let listParameters: [String: Parameter] = [
        "filter[type]": Parameter(values: ["APP_LAUNCH", "APP_ENHANCEMENTS", "NEW_CONTENT"]),
        "filter[state]": Parameter(required: true, values: ["DRAFT", "SUBMITTED", "ARCHIVED"]),
        "filter[hasInAppEvents]": Parameter(values: nil),
        "filter[relatedApps]": Parameter(values: nil),
        "sort": Parameter(values: [
            "lastModifiedDate", "-lastModifiedDate", "publishStartDate", "-publishStartDate", "publishEndDate",
            "-publishEndDate", "name", "-name", "type", "-type",
        ]),
        "fields[nominations]": Parameter(values: [
            "name", "type", "description", "createdDate", "lastModifiedDate", "submittedDate", "state", "publishStartDate",
            "publishEndDate", "deviceFamilies", "locales", "supplementalMaterialsUris", "hasInAppEvents",
            "launchInSelectMarketsFirst", "notes", "preOrderEnabled", "relatedApps", "createdByActor", "lastModifiedByActor",
            "submittedByActor", "inAppEvents", "supportedTerritories",
        ]),
        "fields[apps]": Parameter(values: [
            "accessibilityUrl", "name", "bundleId", "sku", "primaryLocale", "isOrEverWasMadeForKids", "subscriptionStatusUrl",
            "subscriptionStatusUrlVersion", "subscriptionStatusUrlForSandbox", "subscriptionStatusUrlVersionForSandbox",
            "contentRightsDeclaration", "streamlinedPurchasingEnabled", "groupPurchaseInvitationMode", "accessibilityDeclarations",
            "appEncryptionDeclarations", "appStoreIcon", "ciProduct", "betaTesters", "betaGroups", "appStoreVersions",
            "appTags", "preReleaseVersions", "betaAppLocalizations", "builds", "betaLicenseAgreement", "betaAppReviewDetail",
            "appInfos", "appClips", "appPricePoints", "endUserLicenseAgreement", "appPriceSchedule", "appAvailabilityV2",
            "inAppPurchases", "subscriptionGroups", "retentionMessages", "gameCenterEnabledVersions", "performanceOverviews",
            "perfPowerMetrics", "appCustomProductPages", "inAppPurchasesV2", "promotedPurchases", "appEvents",
            "reviewSubmissions", "subscriptionGracePeriod", "customerReviews", "customerReviewSummarizations",
            "gameCenterDetail", "appStoreVersionExperimentsV2", "alternativeDistributionKey", "analyticsReportRequests",
            "marketplaceSearchDetail", "buildUploads", "backgroundAssets", "assetLibrary", "betaFeedbackScreenshotSubmissions",
            "betaFeedbackCrashSubmissions", "searchKeywords", "webhooks", "androidToIosAppMappingDetails",
        ]),
        "fields[actors]": Parameter(values: ["actorType", "userFirstName", "userLastName", "userEmail", "apiKeyId"]),
        "fields[appEvents]": Parameter(values: [
            "referenceName", "badge", "eventState", "deepLink", "purchaseRequirement", "primaryLocale", "priority",
            "purpose", "territorySchedules", "archivedTerritorySchedules", "localizations",
        ]),
        "fields[territories]": Parameter(values: ["currency"]),
        "limit": Parameter(values: nil, maximum: 200),
        "include": Parameter(values: [
            "relatedApps", "createdByActor", "lastModifiedByActor", "submittedByActor", "inAppEvents", "supportedTerritories",
        ]),
        "limit[inAppEvents]": Parameter(values: nil, maximum: 50),
        "limit[relatedApps]": Parameter(values: nil, maximum: 50),
        "limit[supportedTerritories]": Parameter(values: nil, maximum: 200),
    ]

    /// What the spec lists but Apple's server refuses: `fields[actors]=actorType`
    /// answered 400 PARAMETER_ERROR.INVALID "'actorType' is not a valid
    /// field name" (24 Nov 2026).
    static let refusedByApple: [String: Set<String>] = ["fields[actors]": ["actorType"]]

    /// `Nomination.attributes` and `Nomination.relationships`.
    static let nominationAttributes: Set<String> = [
        "name", "type", "description", "createdDate", "lastModifiedDate", "submittedDate", "state", "publishStartDate",
        "publishEndDate", "deviceFamilies", "locales", "supplementalMaterialsUris", "hasInAppEvents",
        "launchInSelectMarketsFirst", "notes", "preOrderEnabled",
    ]
    static let nominationRelationships: Set<String> = [
        "relatedApps", "createdByActor", "lastModifiedByActor", "submittedByActor", "inAppEvents", "supportedTerritories",
    ]
    static let types: Set<String> = ["APP_LAUNCH", "APP_ENHANCEMENTS", "NEW_CONTENT"]
    static let states: Set<String> = ["DRAFT", "SUBMITTED", "ARCHIVED"]
    static let deviceFamilies: Set<String> = ["IPHONE", "IPAD", "APPLE_TV", "APPLE_WATCH", "MAC", "VISION"]

    /// `NominationCreateRequest` (`POST`).
    static let createAttributes: Set<String> = [
        "name", "type", "description", "submitted", "publishStartDate", "publishEndDate", "deviceFamilies",
        "locales", "supplementalMaterialsUris", "hasInAppEvents", "launchInSelectMarketsFirst", "notes",
        "preOrderEnabled",
    ]
    static let createRequiredAttributes: Set<String> = ["submitted", "publishStartDate", "name", "description", "type"]
    static let createRelationships: Set<String> = ["relatedApps", "inAppEvents", "supportedTerritories"]
    static let createRequiredRelationships: Set<String> = ["relatedApps"]

    /// `NominationUpdateRequest` (`PATCH`).
    static let updateAttributes: Set<String> = [
        "name", "type", "description", "submitted", "archived", "publishStartDate", "publishEndDate",
        "deviceFamilies", "locales", "supplementalMaterialsUris", "hasInAppEvents", "launchInSelectMarketsFirst",
        "notes", "preOrderEnabled",
    ]
    static let updateRelationships: Set<String> = ["relatedApps", "inAppEvents", "supportedTerritories"]

    /// The attributes of what a page includes: `actors`, `appEvents`,
    /// `territories` and the `apps` attributes Atlas reads (`name`).
    static let actorAttributes: Set<String> = ["actorType", "userFirstName", "userLastName", "userEmail", "apiKeyId"]
    static let actorTypes: Set<String> = ["USER", "API_KEY", "XCODE_CLOUD", "APPLE"]
    static let appEventAttributes: Set<String> = [
        "referenceName", "badge", "eventState", "deepLink", "purchaseRequirement", "primaryLocale", "priority",
        "purpose", "territorySchedules", "archivedTerritorySchedules",
    ]
    static let territoryAttributes: Set<String> = ["currency"]
    static let appAttributes: Set<String> = [
        "accessibilityUrl", "name", "bundleId", "sku", "primaryLocale", "isOrEverWasMadeForKids", "subscriptionStatusUrl",
        "subscriptionStatusUrlVersion", "subscriptionStatusUrlForSandbox", "subscriptionStatusUrlVersionForSandbox",
        "contentRightsDeclaration", "streamlinedPurchasingEnabled", "groupPurchaseInvitationMode",
    ]
}
