//
//  ReleaseViewModel+Submit.swift
//  Atlas
//

import Foundation

// The Submit sheet: What's New in every language, what's missing, and
// Submit for Review itself.
extension ReleaseViewModel {
    /// "Submit Lumen Journal 1.4 for App Review".
    var submitTitle: String {
        String(localized: "Submit \(versionName) for App Review")
    }

    /// "iOS · 12 languages".
    var submitSubtitle: String {
        var parts: [String] = []
        if let platform = content?.version.platformTitle { parts.append(platform) }
        if let count = content?.locales.count, count > 0 { parts.append(ReviewText.languages(count)) }
        return parts.joined(separator: " · ")
    }

    // MARK: - What's New

    /// One row per language of the version; empty for a first version,
    /// which has no What's New.
    var whatsNewRows: [WhatsNewRow] {
        WhatsNewRow.rows(for: content, appID: app.id, queue: queue, suggestions: suggestions)
    }

    /// "What’s New · 11 of 12 languages".
    var whatsNewTitle: String {
        let rows = whatsNewRows
        let ready = rows.count { !$0.isMissing }
        return String(localized: "What’s New · \(ready) of \(ReviewText.languages(rows.count))")
    }

    /// Accept on a suggested What's New: accepted as the Store Page does
    /// it, so it waits in Review & Push with the other changes.
    func accept(_ suggestion: FieldSuggestion) async {
        guard let model = await storePageModel?() else {
            submitFailure = nil
            submitError = String(localized: "Couldn’t read the Store Page. Accept the suggestion there.")
            return
        }
        model.acceptSuggestion(suggestion)
        // The Store Page's own toast isn't on screen here.
        model.toast = nil
    }

    // MARK: - Encryption

    /// The build carries no answer and none was given before.
    var needsEncryptionAnswer: Bool { options.encryption == nil }

    // MARK: - What's missing

    /// What stops Submit, in the footer's words: "add What’s New in
    /// Swedish", "answer the encryption question".
    var blockers: [String] {
        guard let status else { return [] }
        var blockers: [String] = []
        if selectedBuild == nil {
            let hasOneReady = status.builds.contains(where: \.isSelectable)
            blockers.append(hasOneReady ? String(localized: "choose a build") : String(localized: "upload a build from Xcode"))
        }
        let rows = whatsNewRows
        let missing = rows.filter(\.isMissing)
        if let first = missing.first {
            blockers.append(missing.count == 1
                ? String(localized: "add What’s New in \(first.locale.name)")
                : String(localized: "add What’s New in \(first.locale.name) and \(missing.count - 1) more"))
        }
        if needsEncryptionAnswer { blockers.append(String(localized: "answer the encryption question")) }
        if options.timing == .scheduled, options.releaseDate <= now() { blockers.append(String(localized: "pick a release date that’s still ahead")) }
        if !options.pushesChanges, rows.contains(where: { $0.state == .notPushed }) {
            blockers.append(String(localized: "push the changes (What’s New is among them)"))
        }
        if !status.isReviewInformationComplete { blockers.append(String(localized: "complete the App Review information")) }
        blockers += eventBlockers
        return blockers
    }

    var canSubmit: Bool {
        status != nil && blockers.isEmpty && !isSubmitting
    }

    /// "To submit, add What’s New in Swedish and answer the encryption
    /// question."
    var footerText: String {
        if let submitProgress { return submitProgress }
        let blockers = blockers
        guard !blockers.isEmpty else { return String(localized: "App Review usually takes about a day. You can cancel until review starts.") }
        return String(localized: "To submit, \(blockers.formatted(.list(type: .and))).")
    }

    /// "Push and Submit for Review" when changes go with it.
    var submitButtonTitle: String {
        pendingCount > 0 && options.pushesChanges ? String(localized: "Push and Submit for Review") : String(localized: "Submit for Review")
    }

    /// "Over 7 days, to people with automatic updates…".
    var phasedDetail: String {
        guard options.isPhased else { return String(localized: "Everyone with automatic updates gets \(versionString) on the first day.") }
        return String(localized: """
        Automatic updates over 7 days: 1%, 2%, 5%, 10%, 20%, 50%, then everyone. Anyone can download it. You can pause.
        """)
    }

    // MARK: - Submitting

    /// Pushes the app's changes first when asked to, then submits. Stops
    /// at the first thing App Store Connect refuses, and says what.
    /// Returns whether the version was submitted.
    @discardableResult
    func submit() async -> Bool {
        guard canSubmit, let status, let build = selectedBuild else { return false }
        isSubmitting = true
        submitError = nil
        submitFailure = nil
        defer {
            isSubmitting = false
            submitProgress = nil
        }
        var pushed = 0
        if options.pushesChanges, pendingCount > 0 {
            guard let count = await pushChanges() else {
                submitFailure = SubmitFailureNote(text: submitError ?? "", date: now())
                return false
            }
            pushed = count
            // What the push wrote (an event's new dates, a deep link): the
            // queue no longer has it, so the checks and a refusal's words
            // need App Store Connect's events as they are now.
            await readEvents()
        }
        submitProgress = String(localized: "Submitting \(versionString)…")
        let answer = options.encryption
        let plan = SubmissionPlan(
            appID: app.id, versionID: status.version.id, platform: status.version.platform, buildID: build.id,
            attachedBuildID: status.attachedBuildID,
            usesNonExemptEncryption: answer?.usesNonExemptEncryption == build.usesNonExemptEncryption ? nil : answer?.usesNonExemptEncryption,
            timing: options.releaseTiming, isPhased: options.isPhased,
            eventIDs: tickedEvents.map(\.id)
        )
        do {
            try await services.release.submit(plan)
        } catch {
            // The events as they are now, to name a date that has passed.
            if error is SubmissionFailure { await readEvents() }
            let failure = error as? SubmissionFailure
            let text = failure.map { Self.failureText($0, events: events, plan: plan, versionString: versionString, now: now()) }
                ?? AppleErrorCopy(String(localized: "The version wasn’t submitted.", comment: "kind:error"), error: error).text
            submitError = text
            submitFailure = SubmitFailureNote(
                text: text, date: now(), pastDateEventIDs: failure.flatMap { Self.onlyPastDateEventIDs($0, plan: plan) }, events: events
            )
            // Some of it may have gone: what App Store Connect has now,
            // so the sheet and the next try start from there.
            await refreshStatus()
            return false
        }
        if let answer { saveEncryption(answer) }
        store.setEventIDs(plan.eventIDs, for: app.id)
        proposals.settle(.submit, appID: app.id, versionID: plan.versionID)
        ReleaseNotifier.shared.requestAuthorization()
        onMessage(Self.submittedText(versionName, pushed: pushed))
        await load()
        onChanged()
        return true
    }

    /// "Lumen Journal 1.4 is submitted, with 4 pushed changes. App Review
    /// usually takes about a day."
    static func submittedText(_ versionName: String, pushed: Int) -> String {
        switch pushed {
        case 0: String(localized: "\(versionName) submitted. App Review usually takes a day.")
        case 1: String(localized: "\(versionName) submitted with 1 pushed change. App Review usually takes a day.")
        default: String(localized: "\(versionName) submitted with \(pushed) pushed changes. App Review usually takes a day.")
        }
    }

    /// Pushes this app's changes and waits. Nil, with the reason in
    /// `submitError`, when any of them didn't go: nothing is submitted
    /// then, so App Review never sees half of what was edited.
    private func pushChanges() async -> Int? {
        guard !push.isRunning else {
            submitError = String(localized: "A push is still running. Submit again when it has finished.")
            return nil
        }
        let changes = queue.changes(for: app.id)
        let blocked = changes.count(where: \.isBlocked)
        guard blocked == 0 else {
            submitError = blocked == 1
                ? String(localized: "1 change can’t be pushed yet. Fix it in Review & Push, or untick pushing the changes.")
                : String(localized: "\(blocked) changes can’t be pushed yet. Fix them in Review & Push, or untick pushing the changes.")
            return nil
        }
        submitProgress = changes.count == 1 ? String(localized: "Pushing 1 change…") : String(localized: "Pushing \(changes.count) changes…")
        push.dismissFinished()
        push.push(changes)
        await push.waitUntilFinished()
        let failed = push.failedCount
        let left = queue.count(for: app.id)
        guard failed == 0, left == 0 else {
            submitError = String(localized: "\(max(failed, left)) changes couldn’t be pushed, so nothing was submitted. Review & Push says why.")
            return nil
        }
        let done = push.doneCount
        push.dismissFinished()
        return done
    }

    /// Keeps the answer in App Information → Export Compliance.
    private func saveEncryption(_ answer: EncryptionAnswer) {
        let notesStore = services.appInformation.notes
        var notes = notesStore.notes(for: app.id)
        guard notes.exportAnswers != answer.answers else { return }
        notes.exportAnswers = answer.answers
        notesStore.setNotes(notes, for: app.id)
    }

    /// Ticks or unticks an event that goes with the version, and
    /// remembers it for In-App Events' "Goes with 1.4".
    func setEvent(_ id: InAppEvent.ID, goesWithVersion: Bool) {
        if goesWithVersion {
            options.eventIDs.insert(id)
        } else {
            options.eventIDs.remove(id)
        }
        store.setEventIDs(offeredEvents.map(\.id).filter(options.eventIDs.contains), for: app.id)
    }
}
