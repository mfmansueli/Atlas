//
//  ScreenshotStudioModel+RecaptureRequests.swift
//  Atlas
//

import AppKit
import Foundation

/// The assistant's requests to redo captures, shown in Screenshots with
/// Accept and Decline. Accept opens the capture-only run and starts Claude
/// Code on it; a product page's request turns on the page's Capture
/// Screens Again and starts Claude Code on its captures.
extension ScreenshotStudioModel {
    var recaptureRequests: [AutopilotRecaptureRequest] {
        autopilot?.recaptureRequests(for: app.id) ?? []
    }

    func acceptRecapture(_ request: AutopilotRecaptureRequest) async {
        guard let autopilot else { return }
        if let page = request.page {
            await acceptPageRecapture(request, page: page)
            return
        }
        do {
            try autopilot.acceptRecapture(request.id, appID: app.id, fromCaptures: recapturePlanFromCaptures)
        } catch let error as AutopilotError {
            screenshots.notice = error.localizedDescription
            return
        } catch {
            screenshots.notice = AppleErrorCopy(String(localized: "The request wasn’t accepted.", comment: "kind:error"), error: error).text
            return
        }
        openAutopilot()
        continueRun()
    }

    /// With no saved Autopilot run, the plan a capture-only run is made
    /// from: the set's captures as they are now. Nil with a run, or when
    /// the set has no captures.
    var recapturePlanFromCaptures: AutopilotRecapturePlanFromCaptures? {
        guard let autopilot, autopilot.redoesFromCaptures(appID: app.id), let document = screenshots.document else { return nil }
        let open = autopilot.run(for: app.id).flatMap { $0.stage == .plan ? $0.plan : nil }
        return AutopilotRecapturePlanFromCaptures(
            document: document, primaryLocale: screenshots.context.primaryLocale.code, versionString: screenshots.context.version.versionString,
            proposals: autopilot.planProposals(for: app.id), openPlan: open
        )
    }

    func declineRecapture(_ request: AutopilotRecaptureRequest) {
        autopilot?.declineRecapture(request.id, appID: app.id)
    }

    private func acceptPageRecapture(_ request: AutopilotRecaptureRequest, page: PageRecaptureTarget) async {
        let source: PageShotsSource
        do {
            source = try await PageShotsSource.load(app: app, services: screenshots.services)
        } catch {
            screenshots.notice = AppleErrorCopy(String(localized: "The page’s screenshots didn’t load.", comment: "kind:error"), error: error).text
            return
        }
        if let problem = source.problem {
            screenshots.notice = problem
            return
        }
        let studio = PageShotsStudio.shared
        let key = studio.openRecapture(page, reason: request.reason, app: app, source: source)
        autopilot?.removeRecaptureRequest(request.id, appID: app.id)
        await studio.makeSimulator(for: page, key: key, simulators: simulators)
        let prompt = PageShotsPrompt.captures(app: app.name, appID: app.id, page: page.pageName)
        if let launcher, launcher.canStart,
           let id = await launcher.start(PageShotsPrompt.capturesPurpose(pageName: page.pageName), appID: app.id, appName: app.name, prompt: prompt)
        {
            studio.askedForCaptures(key, claudeRunID: id)
            screenshots.notice = String(localized: "Claude Code is capturing \(page.pageName)’s screens again.")
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
            studio.askedForCaptures(key, claudeRunID: nil)
            screenshots.notice = String(localized: "Prompt copied. Paste it into Claude Code to recapture \(page.pageName)’s screens.")
        }
    }
}
