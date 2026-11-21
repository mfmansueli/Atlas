//
//  PageShotsFlow+Look.swift
//  Atlas
//

import Foundation

/// Plan's Look and Capture Screens Again (board 52): another template, a
/// new look from Claude Design (a stop where the person chooses one of
/// three), and the screens the assistant captures again. Each asks the
/// assistant in a session of its own, so the plan's isn't stopped.
extension PageShotsFlow {
    /// What the set is drawn from as it'll be made: the run's Look and its
    /// screens captured again.
    var shownSource: PageShotsSource? { source?.applying(run) }

    /// The template the default page's set uses.
    var defaultTemplateName: String { source?.document.template?.name ?? run?.templateName ?? "" }

    // MARK: - Look

    /// The person chose the Look. A new look asks for three the first
    /// time.
    func choose(look: PageShotsLook) async {
        studio.choose(look: look, for: key)
        guard look.isClaudeDesign, let design = run?.design, design.candidates.isEmpty, design.claudeRunID == nil else { return }
        await askForLooks()
    }

    func pick(lookID: String) {
        studio.pick(lookID: lookID, for: key)
    }

    /// Asks the assistant for three looks (again).
    func askForLooks() async {
        let prompt = PageShotsPrompt.looks(app: app.name, appID: app.id, page: page.name)
        let id = await askForHelp(prompt, purpose: PageShotsPrompt.looksPurpose(pageName: page.name))
        studio.askedForLooks(key, claudeRunID: id)
    }

    // MARK: - Capture Screens Again

    /// The person turned Capture Screens Again on (the assistant is asked)
    /// or off.
    func setRecapture(_ isOn: Bool) async {
        // Off stops the session capturing before what it sent is forgotten.
        if !isOn, let id = run?.recapture?.claudeRunID { stopClaude(id) }
        studio.setRecapture(isOn, for: key)
        guard isOn, let recapture = run?.recapture, recapture.captures.isEmpty, recapture.claudeRunID == nil else { return }
        await askForCaptures()
    }

    func askForCaptures() async {
        let prompt = PageShotsPrompt.captures(app: app.name, appID: app.id, page: page.name)
        let id = await askForHelp(prompt, purpose: PageShotsPrompt.capturesPurpose(pageName: page.name))
        studio.askedForCaptures(key, claudeRunID: id)
    }

    /// The default page's capture again for a screen.
    func forgetCaptures(slot: Int) {
        studio.forgetCaptures(slot: slot, for: key)
    }

    /// Starts the assistant with `prompt`, or copies it when Atlas can't.
    /// Each has a purpose of its own: the launcher hands back the session
    /// already going for the same purpose.
    private func askForHelp(_ prompt: String, purpose: ClaudeCodeRunPurpose) async -> UUID? {
        copiedPrompt = nil
        let id = await launch(purpose, prompt)
        if id == nil {
            copiedPrompt = prompt
            copy(prompt)
        }
        return id
    }

    /// Stops every session still working on the run.
    func stopSessions() {
        guard let run else { return }
        run.claudeRunIDs.forEach(stopClaude)
    }
}
