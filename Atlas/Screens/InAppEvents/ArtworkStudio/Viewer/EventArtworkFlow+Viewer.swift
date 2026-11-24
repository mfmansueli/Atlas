//
//  EventArtworkFlow+Viewer.swift
//  Atlas
//

import Foundation

/// The full-size viewer (board 47): the concepts that are ready (or the
/// event's own images when there are none), ← → around them, Event Card
/// and Event Details, the App Store's text in a language of its own, Ask
/// for Changes and Use This Artwork. Every move shows the concept in the
/// page's preview too.
extension EventArtworkFlow {
    /// The concepts the viewer goes through: those that are in.
    var viewerConcepts: [EventArtworkConcept] { run.concepts }

    /// Opens the viewer on a concept (nil: the event's own images).
    func openViewer(conceptID: EventArtworkConcept.ID?, kind: InAppEventMedia.Kind, locale: String, showsTextArea: Bool = false) {
        let id = conceptID.flatMap { id in viewerConcepts.contains { $0.id == id } ? id : nil }
        viewer = EventArtworkViewer(conceptID: id, kind: kind, locale: locale, showsTextArea: showsTextArea)
        if let id { preview(id) }
    }

    func closeViewer() {
        viewer = nil
    }

    var viewerConcept: EventArtworkConcept? {
        guard let id = viewer?.conceptID else { return nil }
        return viewerConcepts.first { $0.id == id }
    }

    /// The concept's place among those that are in: "2 of 3".
    var viewerPosition: (index: Int, count: Int)? {
        let concepts = viewerConcepts
        guard let id = viewer?.conceptID, let index = concepts.firstIndex(where: { $0.id == id }) else { return nil }
        return (index + 1, concepts.count)
    }

    var viewerCanStep: Bool { viewer?.conceptID != nil && viewerConcepts.count > 1 }

    /// ← or →, round and round.
    func stepViewer(_ offset: Int) {
        let concepts = viewerConcepts
        guard viewerCanStep, let id = viewer?.conceptID, let index = concepts.firstIndex(where: { $0.id == id }) else { return }
        let next = concepts[((index + offset) % concepts.count + concepts.count) % concepts.count]
        showInViewer(next.id)
    }

    /// A thumbnail in the film, or a step: the page's preview follows.
    func showInViewer(_ id: EventArtworkConcept.ID) {
        guard viewer != nil, viewerConcepts.contains(where: { $0.id == id }) else { return }
        viewer?.conceptID = id
        viewer?.isAsking = false
        preview(id)
    }

    func setViewerKind(_ kind: InAppEventMedia.Kind) {
        viewer?.kind = kind
    }

    /// The still shown for the viewer's concept and `kind`, in its language.
    func viewerStill(_ kind: InAppEventMedia.Kind) -> EventArtworkImage? {
        guard let viewer, let concept = viewerConcept, let still = concept.still(kind, locale: viewer.locale) else { return nil }
        return still.kind == kind ? still : nil
    }

    /// The moving version shown instead of the still: the concept's video,
    /// or the person's own file when it's one.
    func viewerVideo(_ kind: InAppEventMedia.Kind) -> EventArtworkImage? {
        guard let viewer, let concept = viewerConcept else { return nil }
        if let video = concept.video(kind, locale: viewer.locale), video.kind == kind { return video }
        if let still = viewerStill(kind), still.isVideo { return still }
        return nil
    }

    /// The languages to read the App Store's text in: the primary one, the
    /// longest name, one in Chinese, Japanese or Korean, one right to left,
    /// the page's and the one shown; among the event's languages and the
    /// page's (`languages`, suggested ones too, shown as suggested).
    func viewerLocales(pageLocale: String, languages: [String] = []) -> [String] {
        let all = run.locales + languages.filter { !run.locales.contains($0) }
        let name = { (code: String) in self.event.localization(code)?.name.count ?? 0 }
        var picked = [run.primaryLocale]
        if let longest = all.max(by: { name($0) < name($1) }) { picked.append(longest) }
        if let cjk = all.first(where: { ["ja", "zh", "ko"].contains(String($0.prefix(2))) }) { picked.append(cjk) }
        if let rtl = all.first(where: { StoreLocaleCatalog.locale(code: $0)?.isRTL == true }) { picked.append(rtl) }
        if all.contains(pageLocale) || event.localization(pageLocale) != nil { picked.insert(pageLocale, at: 1) }
        // The one shown, when it's none of those.
        if let shown = viewer?.locale, all.contains(shown) { picked.append(shown) }
        var seen = Set<String>()
        return picked.filter { seen.insert($0).inserted }
    }

    /// The concept's name, or the event's for its own images.
    var viewerTitle: String {
        viewerConcept?.name ?? event.referenceName
    }

    /// "Concept 1 of 3 · Claude · Event card · 1920 × 1080 · moving
    /// version, 20 s loop".
    var viewerSubtitle: String {
        guard let viewer else { return "" }
        var parts: [String] = []
        if let position = viewerPosition, position.count > 1 { parts.append(String(localized: "Concept \(position.index) of \(position.count)")) }
        if let concept = viewerConcept {
            parts.append(concept.isMadeByClaudeDesign ? "Claude" : String(localized: "Your files"))
        }
        parts.append(viewer.kind == .card ? String(localized: "Event card · 1920 × 1080") : String(localized: "Event details · 1080 × 1920"))
        if viewerVideo(viewer.kind) != nil {
            parts.append(String(localized: "moving version, \(AutopilotArtworkMotion.loopSeconds) s loop"))
        }
        return parts.joined(separator: " · ")
    }

    /// The concept's reasoning, or what the event's own images are.
    var viewerWhy: String {
        if let concept = viewerConcept, !concept.why.isEmpty { return concept.why }
        if viewerConcept != nil { return String(localized: "Your card and details image, checked for the App Store.") }
        return String(localized: "Event card and event details for \(event.referenceName).")
    }

    /// What the viewer says under the art for the event's own images.
    var viewerChecks: String {
        viewerConcept == nil ? String(localized: "The images this event was submitted with.") : ""
    }

    /// The concept's checks, drawn each with its status symbol: "The path
    /// stays clear of the text", "Reads with the longest name"…; empty for
    /// the event's own images.
    var viewerCheckList: [EventArtworkConceptCheck] {
        viewerConcept?.checks ?? []
    }

    var viewerIsRevising: Bool { viewer?.conceptID != nil && viewer?.conceptID == run.revisingID }

    /// The concept shown is the one in Review & Push, as it was used.
    var viewerIsUsed: Bool {
        guard let concept = viewerConcept else { return false }
        return concept.id == run.usedConceptID && !run.canUse(concept)
    }

    /// Use This Artwork in the viewer: a concept that isn't the one used
    /// (or changed since), not being redrawn.
    var viewerCanUse: Bool {
        guard let concept = viewerConcept else { return false }
        return run.canUse(concept) && !isWorking
    }

    /// Ask for Changes: Claude's concepts, while nothing is drawn.
    var viewerCanAsk: Bool {
        guard let concept = viewerConcept else { return false }
        return concept.isMadeByClaudeDesign && run.revisingID == nil && run.step != .making
    }

    func openAsk() {
        guard viewerCanAsk, viewer?.isFull == false else { return }
        viewer?.isAsking = true
        if viewer?.request.isEmpty ?? true { viewer?.request = EventArtworkViewer.defaultRequest }
    }

    func closeAsk() {
        viewer?.isAsking = false
    }

    /// A chip: the request becomes "Warmer.".
    func useChip(_ chip: String) {
        viewer?.request = "\(chip)."
    }

    /// Send to Claude from the viewer: the panel closes and the
    /// image stays in view while it's redrawn.
    func sendViewerChanges() async {
        guard let viewer, let id = viewer.conceptID else { return }
        self.viewer?.isAsking = false
        self.viewer?.request = ""
        await sendChanges(viewer.request, to: id)
    }
}
