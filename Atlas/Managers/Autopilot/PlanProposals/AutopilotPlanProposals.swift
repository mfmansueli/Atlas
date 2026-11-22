//
//  AutopilotPlanProposals.swift
//  Atlas
//

import Foundation

/// What assistants sent for an app's next plan outside a run: screens to
/// add, on the set or Apple Watch, changes to the plan's screens and
/// setup, and captures to redo. They wait until the person takes them: in
/// the plan, with Add to Plan for a screen and Accept or Reject for a
/// change; in Screenshots, with Accept or Decline for captures to redo.
struct AutopilotPlanProposals: Codable, Hashable, Sendable {
    /// Each `propose_screens` sent outside Suggest Screens, oldest first.
    var screens: [AutopilotScreenSuggestions] = []
    /// Each `update_capture_plan` sent outside a capture, oldest first.
    var changes: [AutopilotPlanChange] = []
    /// Each `request_recapture` and `request_page_recapture` waiting for
    /// Accept or Decline, oldest first; nil when there are none (and in
    /// archives from before them). Use `recaptureRequests`.
    var recaptures: [AutopilotRecaptureRequest]?

    var isEmpty: Bool { screens.isEmpty && changes.isEmpty && recaptureRequests.isEmpty }

    /// The captures the assistant asked to redo, oldest first.
    var recaptureRequests: [AutopilotRecaptureRequest] {
        get { recaptures ?? [] }
        set { recaptures = newValue.isEmpty ? nil : newValue }
    }

    /// The screens suggested for `display` (iPhone for the set's).
    func screens(on display: ScreenshotDisplayType) -> [AutopilotScreenSuggestions] {
        screens.filter { $0.device == display }
    }

    /// Screens still to add or dismiss, on every device.
    var openScreenCount: Int {
        screens.reduce(0) { $0 + $1.open.count }
    }

    /// Something waits for the person.
    var isWaiting: Bool { !changes.isEmpty || openScreenCount > 0 }

    /// The batch holding the suggested screen `id`.
    func batchIndex(holding id: String) -> Int? {
        screens.firstIndex { $0.items.contains { $0.id == id } }
    }
}
