//
//  ProductPageTestReadiness.swift
//  Atlas
//

import Foundation

/// What one placement can be tested with now, by the rules of “Test with
/// Product Page Optimization…” (`ProductPageTestModel`): the artwork the
/// page's control is, the languages whose current image still waits in
/// Review & Push, and the run's variant with its findings. Read by
/// `get_page_tests` and checked by `propose_page_test`.
struct ProductPageTestReadiness: Hashable, Sendable {
    var placement: ProductPageTestPlacement
    /// The artwork kind the placement shows; nil when Autopilot made none.
    var kind: AutopilotArtworkKind?
    /// Languages with the current image made, primary first.
    var controlLocales: [String]
    /// Languages whose current image waits in Review & Push: the test
    /// compares with what the page shows now, so it should go first.
    var waitingLocales: [String]
    /// The variant for this placement, once one was made.
    var variant: ExtrasArtworkVariant?

    init(extras: ScreenshotExtras?, placement: ProductPageTestPlacement, primary: String) {
        self.placement = placement
        let artwork = extras?.artwork ?? []
        let kind = AutopilotArtworkKind.storeArtwork.first { kind in
            artwork.contains { $0.kind == kind } && ProductPageTestPlacement.placements(for: kind).contains(placement)
        }
        self.kind = kind
        let files = artwork.filter { $0.kind == kind }
        controlLocales = Self.ordered(files.map(\.locale), primary: primary)
        let pushed = extras?.pushedChecksums ?? [:]
        let discarded = extras?.discardedChecksums ?? [:]
        waitingLocales = Self.ordered(
            files.filter { pushed[$0.id] != $0.fileID && discarded[$0.id] != $0.fileID }.map(\.locale), primary: primary
        )
        let role: ArtworkTextRole = placement == .header ? .header : .search
        if let made = extras?.variant, made.kind == kind, made.role == role {
            variant = made
        }
    }

    /// Both placements.
    static func all(extras: ScreenshotExtras?, primary: String) -> [ProductPageTestReadiness] {
        ProductPageTestPlacement.allCases.map { ProductPageTestReadiness(extras: extras, placement: $0, primary: primary) }
    }

    /// The languages the variant was rendered in, primary first.
    var variantLocales: [String] {
        let made = Set(variant?.files.map(\.locale) ?? [])
        return controlLocales.filter(made.contains) + (variant?.files.map(\.locale) ?? []).filter { !controlLocales.contains($0) }
    }

    /// The sizes Autopilot makes for this placement, for when App Store
    /// Connect's own list can't be read.
    var fallbackSizes: [PixelSize] { Self.fallbackSizes(for: placement) }

    static func fallbackSizes(for placement: ProductPageTestPlacement) -> [PixelSize] {
        AutopilotArtworkKind.storeArtwork.filter { ProductPageTestPlacement.placements(for: $0).contains(placement) }.map(\.pixelSize)
    }

    /// Whether App Store Connect takes an image of `size` for `placement`:
    /// by its reference data when it was read, else by Autopilot's sizes.
    static func takes(_ size: PixelSize, for placement: ProductPageTestPlacement, refData: AssetLibraryRefData?) -> Bool {
        if let refData, !refData.mappings.isEmpty {
            return !refData.placementGroups(for: placement.placementType, pixelSize: size, isVideo: false).isEmpty
        }
        return fallbackSizes(for: placement).contains(size)
    }

    /// "3840 × 1646 or 5244 × 2950", for a refusal.
    static func sizesTitle(for placement: ProductPageTestPlacement, refData: AssetLibraryRefData?) -> String {
        let exact = refData?.acceptedSizes(for: placement.placementType, isVideo: false) ?? []
        return (exact.isEmpty ? fallbackSizes(for: placement) : exact).map(\.title).formatted(.list(type: .or))
    }

    /// The variant's findings that break Apple's rules.
    var variantErrors: [ArtworkCheck] {
        (variant?.files ?? []).flatMap(\.errors)
    }

    /// Why the variant can't be a test's treatment now, or nil.
    var variantBlockReason: String? {
        let place = placement.title.lowercased()
        guard kind != nil else {
            return String(localized: """
            Autopilot made no \(place) artwork for this app, so there’s no variant to test. Use images from the app’s \
            library (treatment: library), or make the artwork with Autopilot first.
            """)
        }
        guard variant != nil else {
            return String(localized: "There’s no \(place) variant yet.")
        }
        if let error = variantErrors.first {
            return String(localized: "The variant breaks one of Apple’s rules: \(error.text) Send another with propose_artwork_variant.")
        }
        return nil
    }

    private static func ordered(_ codes: [String], primary: String) -> [String] {
        var seen: Set<String> = []
        let unique = codes.filter { seen.insert($0).inserted }
        return unique.filter { $0 == primary } + unique.filter { $0 != primary }
    }
}
