//
//  AutopilotRecaptureRequest.swift
//  Atlas
//

import Foundation

/// The assistant asked to redo some captures (`request_recapture`) or a
/// product page's screens (`request_page_recapture`) while no run was open
/// for them. It waits in Screenshots for Accept, which opens the
/// capture-only run, or Decline. With Settings → Screenshots → "Let Claude
/// Code open capture-only runs" on it opens at once instead.
struct AutopilotRecaptureRequest: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var client: String
    var receivedAt: Date
    /// The captures to redo, as the plan's targets are.
    var targets: [AutopilotCaptureTarget] = []
    /// The App Preview's moments to record again, by screen ID.
    var momentIDs: [String] = []
    /// A product page's screens instead of the set's; nil for the set.
    var page: PageRecaptureTarget?
    var reason: String?
    var evidence: String?
    /// The plan and captures to open it from when the app has no saved
    /// Autopilot run, read from the set when it came; nil with a run.
    var fromCaptures: AutopilotRecapturePlanFromCaptures?

    /// The languages it redoes, in the order they came.
    var locales: [String] {
        if let page { return [page.locale] }
        var seen: Set<String> = []
        return targets.map(\.locale).filter { seen.insert($0).inserted }
    }

    var isEmpty: Bool { page == nil && targets.isEmpty && momentIDs.isEmpty }

    /// "Claude Code wants to redo 18 captures in ja: phrases rewritten in
    /// d038b58"; for a page, "… 2 screens of the Teachers page in de-DE".
    var headline: String {
        let what = page.map { page in
            page.slots.count == 1
                ? String(localized: "1 screen of the \(page.pageName) page in \(page.locale)")
                : String(localized: "\(page.slots.count) screens of the \(page.pageName) page in \(page.locale)")
        } ?? Self.title(captures: targets.count, locales: locales, moments: momentIDs.count)
        let lead = String(localized: "\(client) wants to redo \(what)")
        guard let reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty else { return lead }
        return "\(lead): \(reason)"
    }

    /// What this request leaves of `self` once `newer` asks for the same
    /// captures again: the newer one wins.
    func without(_ newer: AutopilotRecaptureRequest) -> AutopilotRecaptureRequest {
        var request = self
        if let page, let other = newer.page, page.isSamePage(as: other) {
            request.page = nil
        }
        request.targets.removeAll(where: newer.targets.contains)
        request.momentIDs.removeAll(where: newer.momentIDs.contains)
        return request
    }

    /// "18 captures in ja", "3 captures in 2 languages", "18 captures in
    /// ja and 1 App Preview moment", "2 App Preview moments".
    static func title(captures: Int, locales: [String], moments: Int) -> String {
        var parts: [String] = []
        if captures > 0 {
            let place = locales.count == 1 ? locales[0] : String(localized: "\(locales.count) languages")
            parts.append(captures == 1 ? String(localized: "1 capture in \(place)") : String(localized: "\(captures) captures in \(place)"))
        }
        if moments > 0 {
            parts.append(moments == 1 ? String(localized: "1 App Preview moment") : String(localized: "\(moments) App Preview moments"))
        }
        return parts.formatted(.list(type: .and))
    }
}
