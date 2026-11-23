//
//  PageShotsStudio+Recapture.swift
//  Atlas
//

import Foundation

/// Capture screens again (board 52): the assistant runs the app in the
/// Simulator, sends the PNGs of the screens that should show something
/// else for this page to the run's upload link and names them with
/// report_page_capture. The default page's captures don't change.
extension PageShotsStudio {
    /// The person turned Capture Screens Again on or off. Off forgets what
    /// was captured for the page.
    func setRecapture(_ isOn: Bool, for key: PageShotsRun.Key) {
        update(key) { run in
            if isOn {
                if run.recapture == nil { run.recapture = PageShotsRecapture(uploadToken: AutopilotCenter.makeToken()) }
            } else {
                run.recapture = nil
            }
        }
    }

    /// The assistant was asked to capture the screens.
    func askedForCaptures(_ key: PageShotsRun.Key, claudeRunID: UUID?) {
        update(key) { run in
            run.recapture?.claudeRunID = claudeRunID
            run.recapture?.askedAt = .now
            run.recapture?.problem = nil
        }
    }

    /// The run whose upload link this is, while it takes captures.
    func run(uploadToken token: String) -> PageShotsRun? {
        guard !token.isEmpty else { return nil }
        return runs.values.first { $0.recapture?.uploadToken == token && $0.stage != .used }
    }

    /// A PNG arrived at `run`'s upload link.
    func registerUpload(_ file: CaptureFile, for run: PageShotsRun) -> PageShotsUpload {
        let upload = PageShotsUpload(id: "pu-" + UUID().uuidString.lowercased().prefix(12), runID: run.id, file: file)
        uploads[upload.id] = upload
        return upload
    }

    /// A screen captured again: it takes the place of the one sent before
    /// for the same screen, language and device. Nil, with why, when the
    /// person didn't ask or it'd be a fourth screen.
    func receive(capture: PageShotsNewCapture, for key: PageShotsRun.Key) -> String? {
        guard let recapture = runs[key]?.recapture else {
            return String(localized: "No recapture was asked for. Use the default set’s captures.")
        }
        let slots = Set(recapture.slots)
        if !slots.contains(capture.slot), slots.count >= PageShotsRecapture.maxScreens {
            let numbers = recapture.slots.map { String($0 + 1) }.formatted(.list(type: .and))
            return String(localized: """
            Already recaptured: screens \(numbers). A page recaptures at most \(PageShotsRecapture.maxScreens). Resend \
            one of those.
            """)
        }
        update(key) { run in
            run.recapture?.captures.removeAll {
                $0.slot == capture.slot && $0.locale == capture.locale && $0.displayType == capture.displayType
            }
            run.recapture?.captures.append(capture)
            run.recapture?.problem = nil
        }
        return nil
    }

    /// The person put a screen back to the default page's capture.
    func forgetCaptures(slot: Int, for key: PageShotsRun.Key) {
        update(key) { run in run.recapture?.captures.removeAll { $0.slot == slot } }
    }

    /// A captures session ended: without a capture, it says so calmly.
    func captureSessionEnded(_ session: ClaudeCodeRun) -> Bool {
        guard let run = runs.values.first(where: { $0.appID == session.appID && $0.recapture?.claudeRunID == session.id })
        else { return false }
        update(run.key) { run in
            run.recapture?.claudeRunID = nil
            if run.recapture?.captures.isEmpty == true {
                let assistant = run.plan?.source ?? MCPClientKind.claudeCode.title
                run.recapture?.problem = String(localized: """
                \(assistant) sent no capture, so the set uses the default page’s. Ask again or leave it.
                """)
            }
        }
        return true
    }
}
