//
//  MCPPageTests.swift
//  Atlas
//

import Foundation

/// An app's Product Page Optimization as the page test tools see it: its
/// screenshot document (the extras, the variant and the proposed tests),
/// and App Store Connect's tests and asset library through Review & Push's
/// services. Reading never writes to App Store Connect; saving a proposal
/// goes through the screenshot services, so Review & Push shows it the
/// next time it plans the app.
@MainActor
struct MCPPageTests {
    /// Where the tools reach App Store Connect's tests and library: Review
    /// & Push's extras services. Tests swap it.
    typealias Provider = @MainActor (MCPWorkspace) -> (any ExtrasPushProviding)?

    let app: StoreApp
    let services: any ScreenshotsServices
    let primary: StoreLocale
    var document: ScreenshotsDocument
    let provider: (any ExtrasPushProviding)?

    static func provider(in workspace: MCPWorkspace) -> (any ExtrasPushProviding)? {
        (workspace.services.screenshots as? any ScreenshotPushProviding)?.pushing as? any ExtrasPushProviding
    }

    static func load(app identifier: String, in workspace: MCPWorkspace, provider: Provider) async throws -> MCPPageTests {
        let app = try await workspace.app(matching: identifier)
        let services = workspace.services.screenshots
        let primary = app.primaryLocale.flatMap(StoreLocaleCatalog.locale(code:)) ?? .englishUS
        do {
            let document = try await services.loadDocument(for: app, primaryLocale: primary)
            return MCPPageTests(app: app, services: services, primary: primary, document: document, provider: provider(workspace))
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s screenshots: \(error.localizedDescription)"))
        }
    }

    /// "Lumen Journal · Product Page Optimization".
    var target: String { String(localized: "\(app.name) · Product Page Optimization") }

    var extras: ScreenshotExtras? { document.extras }

    /// Each placement's artwork, variant and what blocks it.
    var readiness: [ProductPageTestReadiness] {
        ProductPageTestReadiness.all(extras: extras, primary: primary.code)
    }

    /// The app has a finished Autopilot run that can be asked for a
    /// variant.
    var canAskForVariant: Bool {
        services.autopilot?.run(for: app.id)?.stage == .ready
    }

    // MARK: - App Store Connect

    /// Why the tests can't be read, when they can't.
    static let unavailable = String(localized: """
    Atlas can’t reach Product Page Optimization with these services. Ask the person to open Atlas with their App Store Connect key.
    """)

    func tests() async throws -> [ProductPageExperiment] {
        guard let provider else { throw MCPToolError.unavailable(Self.unavailable) }
        do {
            return try await provider.productPageTesting.productPageExperiments(appID: app.id)
        } catch {
            throw MCPToolError.unavailable(String(localized: "App Store Connect didn’t list \(app.name)’s tests: \(ProductPageTestRun.text(for: error))"))
        }
    }

    /// A test's treatments, each with its languages and their artwork.
    func treatments(of test: ProductPageExperiment) async throws -> [(ProductPageTreatment, [ProductPageTreatmentLocalization])] {
        guard let tester = provider?.productPageTesting else { return [] }
        var result: [(ProductPageTreatment, [ProductPageTreatmentLocalization])] = []
        for treatment in try await tester.productPageTreatments(experimentID: test.id) {
            try await result.append((treatment, tester.productPageTreatmentLocalizations(treatmentID: treatment.id)))
        }
        return result
    }

    /// The app's library, or why it couldn't be read.
    func library() async -> (files: [AssetLibraryFile]?, error: String?) {
        guard let provider else { return (nil, Self.unavailable) }
        do {
            return try await (provider.assetLibraryFiles.assetLibraryFiles(appID: app.id), nil)
        } catch {
            return (nil, String(localized: "The app’s library couldn’t be read: \(ProductPageTestRun.text(for: error))"))
        }
    }

    /// What App Store Connect says about each placement's sizes; nil when
    /// it couldn't be read.
    func refData() async -> AssetLibraryRefData? {
        try? await provider?.assetLibrary.assetLibraryRefData()
    }

    // MARK: - Saving

    /// Changes the app's extras (making them when Autopilot made none)
    /// and saves the document.
    mutating func changeExtras(now: Date, _ change: (inout ScreenshotExtras) -> Void) async throws {
        var extras = document.extras ?? .holdingProposals(at: now)
        change(&extras)
        document.extras = extras
        do {
            try await services.saveDocument(document, for: app)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t save \(app.name)’s proposed test: \(error.localizedDescription)"))
        }
    }
}
