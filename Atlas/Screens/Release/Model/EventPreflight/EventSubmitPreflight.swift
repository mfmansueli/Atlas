//
//  EventSubmitPreflight.swift
//  Atlas
//

import Foundation

/// What the Submit sheet says under a ticked In-App Event before it goes
/// to App Review with the version: what App Store Connect still needs
/// (Submit stays off until it's fixed or unticked: App Store Connect
/// refuses the whole submission otherwise; a date that has passed is one),
/// warnings about App Review's time (its card or start within two days),
/// warnings from the check of its deep link (the app doesn't open it, or
/// the build going is older than the one where it does), and a calm note
/// when nobody checked the link, or checked it before the event's start or
/// end moved (`dates`, the ones it will have).
struct EventSubmitPreflight: Hashable, Sendable {
    /// What blocks Submit: the "Before App Review" items still missing.
    var missing: [InAppEventReviewItem] = []
    /// App Review may not approve it before its card or its start: never
    /// a block.
    var reviewTime: [InAppEventReviewWarning] = []
    var warnings: [String] = []
    /// "Not checked: …": not a block.
    var note: String?
    /// The build where the app opens the link, when the one chosen is
    /// older and it's in the list: "Use Build 21".
    var newerBuild: ReleaseBuild?

    var blocks: Bool { !missing.isEmpty }

    /// Nobody checked the link in the code yet, or the check found it
    /// doesn't open: the row offers Check in the Code.
    var offersCheck = false
    /// The link opens nothing or not the event: the row offers Make It
    /// Work….
    var offersFix = false

    /// The preflight of `event`: `items` its "Before App Review" list,
    /// `link` whether the project claims its deep link and what an
    /// assistant found in the code, `builds` the one chosen and all of the
    /// version's, `pushesChanges` whether the changes waiting in Review &
    /// Push go first (then what waits there counts as done), `reviewTime`
    /// the warnings about App Review's time.
    static func check(
        _ event: InAppEvent, items: [InAppEventReviewItem], link: (claim: InAppEventLinkClaim, report: InAppEventDeepLinkReport?),
        builds: (selected: ReleaseBuild?, all: [ReleaseBuild]), pushesChanges: Bool, appName: String,
        reviewTime: [InAppEventReviewWarning] = [], dates: InAppEventDates? = nil, format: InAppEventDateText = .current
    ) -> Self {
        let (claim, report) = link
        var preflight = Self()
        preflight.reviewTime = reviewTime
        // What waits in Review & Push counts once it's pushed first; an
        // assistant's suggestion waits for Accept, so it doesn't.
        preflight.missing = items.filter { $0.state != .queued || !pushesChanges }
        let hasLink = !items.contains { $0.need == .deepLink && $0.state == .missing }
        guard hasLink, !claim.blocksSubmit else {
            preflight.offersFix = claim.blocksSubmit
            return preflight
        }
        guard let report else {
            preflight.offersCheck = true
            let claimText = claim.message(appName: appName).map { " \($0)" } ?? ""
            preflight.note = String(localized: "Not checked: nobody has tried its deep link in \(appName)’s code yet.\(claimText)")
            return preflight
        }
        if let stale = report.staleText(for: dates, format) {
            // Its dates moved since: a note to check again, never a block.
            preflight.offersCheck = true
            preflight.note = String(localized: "Checked before the dates changed. \(stale)")
        }
        if !report.opens {
            preflight.offersCheck = true
            preflight.offersFix = true
            let first = report.problems.first.map { " \($0)" } ?? ""
            preflight.warnings.append(String(localized: "\(report.client) found that \(appName) doesn’t open its deep link yet.\(first)"))
            return preflight
        }
        let isFree = (event.purchaseRequirement ?? .noCostAssociated) == .noCostAssociated
        if isFree, report.needsPremium {
            preflight.offersFix = true
            preflight.warnings.append(String(localized: "Its deep link lands on Premium, but the event is free. App Review rejects that."))
        }
        if let selected = builds.selected, report.isNewer(than: selected.number) == true, let checked = report.buildNumber {
            preflight.warnings.append(String(localized: "Build \(selected.number) is older than the build where \(appName) opens these links (\(checked))."))
            // That build, else the oldest one after it.
            preflight.newerBuild = builds.all.first { $0.isSelectable && $0.number == checked }
                ?? builds.all.filter { $0.isSelectable && $0.number.compare(checked, options: .numeric) == .orderedDescending }
                .min { $0.number.compare($1.number, options: .numeric) == .orderedAscending }
        }
        return preflight
    }
}
