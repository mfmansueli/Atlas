//
//  EventArtworkFlow+Use.swift
//  Atlas
//

import Foundation

extension EventArtworkFlow {
    /// The id of the concept made from the person's own files.
    static let filesConceptID = "files"

    /// Use This Artwork: the concept (the one in the preview unless said)
    /// goes into every language of the event, in Review & Push, already
    /// accepted (the moving version where there is one, its first frame
    /// the still). Undo puts the queue back.
    @discardableResult
    func use(_ id: EventArtworkConcept.ID? = nil) async -> Bool {
        guard let concept = id.flatMap({ id in run.concepts.first { $0.id == id } }) ?? previewConcept, run.canUse(concept) else { return false }
        isWorking = true
        defer { isWorking = false }
        var reports: [String: InAppEventArtworkReport] = [:]
        var changes: [PendingChange] = []
        let source: ChangeSource = concept.isMadeByClaudeDesign ? .assistant(client: concept.client) : .you
        // Every language: the event's, and the ones its queued texts create.
        let existing = event.localizations.map(\.locale)
        let coming = builder.newLanguages(of: event.id, in: queue.changes(for: app.id, section: .inAppEvents)).filter { !existing.contains($0) }
        for locale in existing + coming {
            for kind in concept.kinds {
                guard let image = concept.video(kind, locale: locale) ?? concept.still(kind, locale: locale) else { continue }
                if reports[image.fileID] == nil {
                    reports[image.fileID] = await InAppEventArtworkReport.make(
                        fileID: image.fileID, appID: app.id, kind: kind, language: run.primaryLocale, in: directory
                    )
                }
                guard let report = reports[image.fileID], report.canQueue else { continue }
                var change = if let localization = event.localization(locale) {
                    builder.artworkChange(report, into: localization, of: event, source: source)
                } else {
                    builder.artworkChange(report, newLanguage: locale, of: event, source: source)
                }
                change.awaitingAcceptance = nil
                changes.append(change)
            }
        }
        guard !changes.isEmpty else {
            problem = String(localized: "Atlas couldn’t read this concept’s images. Make the artwork again, or choose files.")
            return false
        }
        problem = nil
        let before = run
        var previous: [PendingChange.ID: PendingChange?] = [:]
        for change in changes { previous[change.id] = queue.change(id: change.id) }
        queue.upsert(contentsOf: changes)
        studio.update(key) { run in
            run.usedConceptID = concept.id
            run.usedAt = now()
            run.pickedID = concept.id
            run.queuedChangeIDs = changes.map(\.id)
            run.isHidden = false
        }
        isChanging = false
        viewer = nil
        let undo = InAppEventsUndo(
            suggestions: [], previous: previous, artwork: key, previousConceptID: before.usedConceptID, previousChangeIDs: before.queuedChangeIDs
        )
        let what = concept.kinds.count > 1 ? String(localized: "Both images are in Review & Push.") : String(localized: "The image is in Review & Push.")
        onToast(ToastMessage(text: String(localized: "“\(concept.name)” is the artwork for \(event.referenceName). ") + what, canUndo: true), undo)
        return true
    }

    /// Choose Files…: the person's own card and details image (by their
    /// shape), a concept of their own, opened full size with where the
    /// App Store's text goes.
    func chooseFiles(_ urls: [URL]) async {
        isWorking = true
        defer { isWorking = false }
        var stills: [EventArtworkImage] = []
        var videos: [EventArtworkImage] = []
        var reports: [InAppEventArtworkReport] = []
        for url in urls.prefix(4) {
            guard let data = try? Data(contentsOf: url),
                  let id = try? InAppEventArtworkFiles.save(data, fileName: url.lastPathComponent, appID: app.id, in: directory),
                  let saved = InAppEventArtworkFiles.url(id: id, appID: app.id, in: directory),
                  let file = await InAppEventArtworkInspector.inspect(saved, fileName: url.lastPathComponent)
            else { continue }
            let kind: InAppEventMedia.Kind = file.pixelSize.isLandscape ? .card : .details
            guard let report = await InAppEventArtworkReport.make(fileID: id, appID: app.id, kind: kind, language: run.primaryLocale, in: directory)
            else { continue }
            let image = EventArtworkImage(kind: kind, fileID: id, path: saved.path(percentEncoded: false), isVideo: file.isVideo)
            if file.isVideo {
                videos.removeAll { $0.kind == kind }
                videos.append(image)
            } else {
                stills.removeAll { $0.kind == kind }
                stills.append(image)
            }
            reports.removeAll { $0.kind == kind && $0.file.isVideo == file.isVideo }
            reports.append(report)
        }
        // A video alone still shows: its poster stands in for the still.
        for video in videos where !stills.contains(where: { $0.kind == video.kind }) { stills.append(video) }
        guard !stills.isEmpty else {
            problem = String(localized: "Atlas couldn’t read those files. Choose PNG or JPEG images, or MOV or MP4 videos.")
            return
        }
        problem = nil
        let concept = EventArtworkConcept(
            id: Self.filesConceptID, name: String(localized: "Your files"), why: "", source: .files, client: "", stills: stills,
            videos: videos, checks: EventArtworkConceptChecks.make(reports, wordsInArt: false), arrivedAt: now()
        )
        var updated = run
        updated.concepts.removeAll { $0.id == Self.filesConceptID }
        updated.concepts.append(concept)
        updated.pickedID = concept.id
        if updated.step != .making { updated.step = .check }
        updated.isHidden = false
        if isStarted { studio.update(key) { $0 = updated } } else { studio.begin(updated) }
        isChanging = run.usedConceptID != nil
        openViewer(conceptID: concept.id, kind: concept.kinds.first ?? .card, locale: run.primaryLocale, showsTextArea: true)
    }
}
