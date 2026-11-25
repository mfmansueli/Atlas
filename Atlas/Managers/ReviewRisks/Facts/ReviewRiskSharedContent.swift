//
//  ReviewRiskSharedContent.swift
//  Atlas
//

import Foundation

/// What several parts of the facts start from, read once per check run:
/// the store page and App Information of the version, the products, their
/// texts, App Compliance's availability and the privacy URLs. A part that
/// couldn't be read is nil, with Apple's reason in `errors`.
struct ReviewRiskSharedContent: Sendable {
    var storePage: StorePageContent?
    var appInformation: AppInformationContent?
    var catalog: PricingCatalog?
    var inAppTexts: InAppTextsContent?
    var compliance: ComplianceContent?
    var privacyURLs: PrivacyURLsContent?
    /// Why a part couldn't be read, in the person's words, by part name
    /// ("storePage", "appInformation", "catalog", "inAppTexts",
    /// "compliance", "privacyURLs").
    var errors: [String: String] = [:]

    init() {}

    @MainActor
    static func load(_ app: StoreApp, services: WorkspaceServices) async -> ReviewRiskSharedContent {
        var shared = ReviewRiskSharedContent()
        do { shared.storePage = try await services.storePage.content(for: app, versionID: nil) } catch {
            shared.errors["storePage"] = reason(error)
        }
        do {
            shared.appInformation = try await services.appInformation.content(for: app, versionID: shared.storePage?.version.id)
        } catch {
            shared.errors["appInformation"] = reason(error)
        }
        do { shared.catalog = try await services.pricing.catalog(for: app) } catch { shared.errors["catalog"] = reason(error) }
        do { shared.inAppTexts = try await services.storePage.inAppTexts(for: app) } catch { shared.errors["inAppTexts"] = reason(error) }
        do { shared.compliance = try await services.appInformation.compliance(for: app) } catch { shared.errors["compliance"] = reason(error) }
        do { shared.privacyURLs = try await services.appInformation.privacyURLs(for: app) } catch {
            shared.errors["privacyURLs"] = reason(error)
        }
        return shared
    }

    /// Apple's error in the person's words, never raw.
    static func reason(_ error: any Error) -> String {
        AppleErrorCopy(String(localized: "Atlas couldn’t read it from App Store Connect.", comment: "kind:error"), error: error).text
    }
}
