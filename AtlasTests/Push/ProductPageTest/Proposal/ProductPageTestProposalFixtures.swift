//
//  ProductPageTestProposalFixtures.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// What a proposed test is checked against: Autopilot's header and search
/// artwork in English, German and French (`ExtrasReviewFixtures`), the
/// Outcome header variant, the app's tests and images in its library.
@MainActor
enum ProductPageTestProposalFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_500)
    static let headerSize = PixelSize(width: 3840, height: 1646)

    /// The extras with the header variant, or without one.
    static func extras(variant: ExtrasArtworkVariant? = ExtrasReviewFixtures.variant()) -> ScreenshotExtras {
        var extras = ExtrasReviewFixtures.extras(previews: false)
        extras.variant = variant
        return extras
    }

    static let draft = ProductPageExperiment(
        id: "exp-draft", name: "Icons", platform: "IOS", state: "PREPARE_FOR_SUBMISSION", trafficProportion: 30
    )
    static let running = ProductPageExperiment(id: "exp-run", name: "Screens", platform: "IOS", state: "APPROVED", trafficProportion: 50)
    static let over = ProductPageExperiment(id: "exp-old", name: "Old", platform: "IOS", state: "COMPLETED", trafficProportion: 50)

    /// A processed header image per language, one still processing, a
    /// search-sized one and a video.
    static let library: [AssetLibraryFile] = [
        file("lib-en", name: "Morning · en-US · Header", size: headerSize),
        file("lib-de", name: "Morning · de-DE · Header", size: headerSize),
        file("lib-busy", name: "Busy · en-US · Header", size: headerSize, state: "UPLOAD_COMPLETE"),
        file("lib-small", name: "Small header", size: PixelSize(width: 2000, height: 1000)),
        file("lib-video", name: "Loop", size: headerSize, media: .video),
    ]

    static func file(
        _ id: String, name: String, size: PixelSize, state: String = "PREPARE_FOR_SUBMISSION", media: AssetLibraryMedia = .image
    ) -> AssetLibraryFile {
        AssetLibraryFile(
            id: id, media: media, referenceName: name, fileName: "\(id).png", fileSize: 1000, state: state, createdDate: nil,
            thumbnailTemplate: nil, pixelSize: size
        )
    }

    static func proposer(
        extras: ScreenshotExtras? = extras(), tests: [ProductPageExperiment] = [over], queuedDeletions: Set<String> = [],
        library: [AssetLibraryFile]? = library, canAskForVariant: Bool = false
    ) -> ProductPageTestProposer {
        ProductPageTestProposer(
            extras: extras, primaryLocale: "en-US", tests: tests, queuedDeletions: queuedDeletions, library: library,
            refData: AssetLibraryRefDataSample.refData, canAskForVariant: canAskForVariant, client: "Claude Code", now: now
        )
    }

    static func input(
        placement: ProductPageTestPlacement = .header, treatment: String = "variant", traffic: Int? = nil, assets: [String: String] = [:],
        locales: [String]? = nil, name: String? = nil, reason: String = "Search visitors leave the page quickly."
    ) -> ProductPageTestProposer.Input {
        ProductPageTestProposer.Input(
            name: name, placement: placement, trafficProportion: traffic, treatment: treatment, assets: assets, locales: locales,
            reason: reason, evidence: ["analytics: page views to downloads 2.1%"]
        )
    }

    /// A pending header proposal of the variant.
    static func proposal(
        id: String = "pt-1", client: String = "Claude Code", placement: ProductPageTestPlacement = .header,
        treatment: ProductPageTestTreatmentSource = .variant(change: "A calm morning page"), locales: [String] = ExtrasReviewFixtures.locales
    ) -> ProductPageTestProposal {
        ProductPageTestProposal(
            id: id, name: "Header: Editor vs Calm morning", placement: placement, trafficProportion: 30, treatment: treatment, locales: locales,
            reason: "Search visitors leave the page quickly.", evidence: ["analytics: page views to downloads 2.1%"], client: client,
            receivedAt: now
        )
    }
}
#endif
