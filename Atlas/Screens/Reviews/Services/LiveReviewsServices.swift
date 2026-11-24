//
//  LiveReviewsServices.swift
//  Atlas
//

import Foundation

/// The real `ReviewsServices`: App Store Connect for the reviews and the
/// replies, the App Store's lookup for the ratings, Apple Translation for
/// the translations.
@MainActor
struct LiveReviewsServices: ReviewsServices {
    let client: AppStoreConnectClient
    var lookup = StoreRatingLookup()
    var translator: any ReviewTranslator = AppleReviewTranslator()

    /// How many versions' reviews are read to say which version a review
    /// is about: the one on the App Store and the one before.
    static let taggedVersions = 2

    func reviews(for app: StoreApp, after cursor: String?) async throws -> ReviewsPage {
        let document = try await client.customerReviewsPage(appID: app.id, next: cursor.flatMap(URL.init(string:)))
        var reviews = document.data.map { Self.review($0, in: document) }
        // Which version each review is about; a failure leaves them without.
        if let versions = try? await releasedVersions(of: app) {
            for version in versions.prefix(Self.taggedVersions) {
                guard let ids = try? await client.versionReviewIDs(versionID: version.id) else { continue }
                let tagged = Set(ids)
                for index in reviews.indices where reviews[index].version == nil && tagged.contains(reviews[index].id) {
                    reviews[index].version = version.attributes.versionString
                }
            }
        }
        return ReviewsPage(reviews: reviews, next: document.links?.next?.absoluteString, total: document.meta?.paging?.total)
    }

    func currentVersion(for app: StoreApp) async throws -> String? {
        try await releasedVersions(of: app).first?.attributes.versionString
    }

    func sendReply(_ text: String, to reviewID: AppReview.ID) async throws -> ReviewReply {
        let resource = try await client.createReviewResponse(reviewID: reviewID, body: text)
        return Self.reply(resource, fallbackText: text)
    }

    func deleteReply(_ replyID: ReviewReply.ID) async throws {
        try await client.deleteReviewResponse(id: replyID)
    }

    func ratings(for app: StoreApp, countries: Set<String>) async -> StoreRatings {
        await lookup.ratings(appID: app.id, countries: countries)
    }

    /// The versions people can have, newest first: the one on the App
    /// Store and the ones it replaced.
    private func releasedVersions(of app: StoreApp) async throws -> [AppStoreConnectResource<AppStoreVersionAttributes>] {
        try await client.appStoreVersions(appID: app.id)
            .filter { Self.releasedStates.contains($0.attributes.state ?? "") }
            .sorted { ($0.attributes.createdDate ?? "") > ($1.attributes.createdDate ?? "") }
    }

    private static let releasedStates: Set<String> = ["READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_VERSION"]

    // MARK: - Mapping

    static func review(_ resource: CustomerReviewsDocument.Review, in document: CustomerReviewsDocument) -> AppReview {
        let attributes = resource.attributes
        let title = attributes.title ?? ""
        let body = attributes.body ?? ""
        return AppReview(
            id: resource.id,
            territory: attributes.territory.flatMap { TerritoryCatalog.standard.territory(alpha3: $0)?.alpha2 } ?? "",
            rating: attributes.rating ?? 0,
            title: title,
            body: body,
            nickname: attributes.reviewerNickname ?? "",
            date: AppStoreConnectDate.date(attributes.createdDate) ?? .distantPast,
            languageCode: ReviewLanguage.code(of: [title, body].joined(separator: ". ")),
            reply: document.response(to: resource).map { reply($0, fallbackText: "") }
        )
    }

    static func reply(_ resource: AppStoreConnectResource<CustomerReviewResponseAttributes>, fallbackText: String) -> ReviewReply {
        ReviewReply(
            id: resource.id,
            text: resource.attributes.responseBody ?? fallbackText,
            date: AppStoreConnectDate.date(resource.attributes.lastModifiedDate) ?? .now,
            isPending: resource.attributes.state == CustomerReviewResponseAttributes.pendingState
        )
    }
}
