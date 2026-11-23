//
//  ProductPageExperiment.swift
//  Atlas
//

import Foundation

/// A Product Page Optimization test (`appStoreVersionExperiments`, v2):
/// the app's current page is its control, and its treatments share the
/// traffic it gets.
struct ProductPageExperiment: Hashable, Sendable, Identifiable {
    var id: String
    var name: String?
    var platform: String?
    var state: String?
    var trafficProportion: Int?
    /// Whether App Review must approve it before it runs.
    var reviewRequired: Bool?
    var startDate: Date?
    var endDate: Date?

    init(
        id: String, name: String? = nil, platform: String? = nil, state: String? = nil, trafficProportion: Int? = nil,
        reviewRequired: Bool? = nil, startDate: Date? = nil, endDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.state = state
        self.trafficProportion = trafficProportion
        self.reviewRequired = reviewRequired
        self.startDate = startDate
        self.endDate = endDate
    }

    init(_ resource: ScreenshotAPIResource<ProductPageExperimentAttributes>) {
        let attributes = resource.attributes
        self.init(
            id: resource.id, name: attributes?.name, platform: attributes?.platform, state: attributes?.state,
            trafficProportion: attributes?.trafficProportion, reviewRequired: attributes?.reviewRequired,
            startDate: AppStoreConnectDate.date(attributes?.startDate), endDate: AppStoreConnectDate.date(attributes?.endDate)
        )
    }

    /// States a test is over in. Every other one, a draft included, is in
    /// the way of a new test: App Store Connect runs one at a time and
    /// refuses a second draft (409 `STATE_ERROR`).
    static let finishedStates: Set<String> = ["COMPLETED", "STOPPED"]

    var isFinished: Bool { state.map(Self.finishedStates.contains) ?? false }

    /// A draft: the only state Atlas proposes deleting a test in.
    var isDraft: Bool { state == "PREPARE_FOR_SUBMISSION" }

    /// "a draft", "in review", "running"…, for "already has a test, …".
    var stateTitle: String {
        switch state {
        case "PREPARE_FOR_SUBMISSION": String(localized: "a draft")
        case "READY_FOR_REVIEW", "WAITING_FOR_REVIEW": String(localized: "waiting for review")
        case "IN_REVIEW": String(localized: "in review")
        case "ACCEPTED": String(localized: "approved, not started")
        case "APPROVED": String(localized: "running")
        case "REJECTED": String(localized: "rejected")
        case "COMPLETED": String(localized: "completed")
        case "STOPPED": String(localized: "stopped")
        default: state ?? String(localized: "in an unknown state")
        }
    }
}
