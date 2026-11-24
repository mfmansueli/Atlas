//
//  NominationsViewModel+Suggestions.swift
//  Atlas
//

import Foundation

/// What's suggested on Nominations: Atlas's own (the type, the
/// description and known links, from what it knows), and assistants' new
/// nominations, changes to drafts and requests to submit or archive.
extension NominationsViewModel {
    // MARK: - Atlas's own

    /// The built-in suggestions for a draft's empty fields that weren't
    /// dismissed.
    func builtInSuggestions(for nomination: Nomination) -> [NominationBuiltInSuggestion] {
        NominationBuiltInSuggestion.suggestions(for: nomination, context: context).filter { !store.isDismissed($0.id, for: app.id) }
    }

    func builtInSuggestion(_ field: NominationField, for nomination: Nomination) -> NominationBuiltInSuggestion? {
        builtInSuggestions(for: nomination).first { $0.field == field }
    }

    func acceptBuiltIn(_ suggestion: NominationBuiltInSuggestion, useAndEdit: Bool = false) {
        let before = nomination(suggestion.nominationID)?.content
        update(suggestion.nominationID) { content in
            switch suggestion.field {
            case .type: content.type = suggestion.type
            case .description: content.description = suggestion.text
            default: break
            }
        }
        store.dismissBuiltIn(suggestion.id, for: app.id)
        let what = suggestion.field == .type
            ? String(localized: "type", comment: "kind:other")
            : String(localized: "description", comment: "kind:other")
        let text = useAndEdit
            ? String(localized: "The suggested description is in the field. Edit it as you like.", comment: "kind:toast")
            : String(localized: "Accepted the \(what). Nothing is sent until you push.", comment: "kind:toast")
        show(text) { [weak self] in
            guard let self, let before else { return }
            store.restoreBuiltIn(suggestion.id, for: app.id)
            update(suggestion.nominationID) { $0 = before }
        }
    }

    func dismissBuiltIn(_ suggestion: NominationBuiltInSuggestion) {
        store.dismissBuiltIn(suggestion.id, for: app.id)
        let what = suggestion.field == .type
            ? String(localized: "type", comment: "kind:other")
            : String(localized: "description", comment: "kind:other")
        show(String(localized: "Dismissed the suggested \(what).", comment: "kind:toast")) { [weak self] in
            guard let self else { return }
            store.restoreBuiltIn(suggestion.id, for: app.id)
        }
    }

    /// The links Atlas knows that the nomination doesn't have yet.
    func knownLinks(for nomination: Nomination) -> [NominationContext.KnownLink] {
        NominationBuiltInSuggestion.knownLinks(for: nomination, context: context)
    }

    /// How many suggestions wait on the section: assistants' and Atlas's.
    var suggestionCount: Int {
        let drafts = nominations(in: .draft)
        return store.count(for: app.id) + drafts.reduce(0) { $0 + builtInSuggestions(for: $1).count }
    }

    // MARK: - Assistants' nominations

    /// An assistant's changes to a draft, waiting on its page.
    func changeProposal(for nominationID: String) -> NominationProposal? {
        store.proposals(for: app.id).last { $0.nominationID == nominationID }
    }

    /// Accept on an assistant's nomination: a new one becomes a draft on
    /// this Mac marked "Suggested by <client>", changes apply to their
    /// draft; either way its Create or Update row goes to Review & Push.
    func acceptProposal(_ id: String) {
        guard let proposal = store.proposals(for: app.id).first(where: { $0.id == id }) else { return }
        let archive = store.archive(for: app.id)
        let before = queue.changes(for: app.id, section: .nominations)
        let nominationID: String
        if let existing = proposal.nominationID {
            nominationID = existing
            update(existing) { $0 = proposal.content }
        } else {
            var draft = Nomination.newDraft(appID: app.id, now: now())
            draft.content = proposal.content
            if !draft.content.appIDs.contains(app.id) { draft.content.appIDs.insert(app.id, at: 0) }
            draft.suggestedBy = proposal.client
            store.save(draft, for: app.id)
            nominationID = draft.id
        }
        store.removeProposal(id, for: app.id)
        let queued = addToReviewPush(nominationID, source: .assistant(client: proposal.client), layers: proposal.evidence.layers)
        selection = .nomination(nominationID)
        let text = queued
            ? String(localized: "Accepted. It’s in Review & Push as a draft. Nothing is sent until you push.", comment: "kind:toast")
            : String(localized: "Accepted as a draft on this Mac. Fix what it needs, then add it to Review & Push.", comment: "kind:toast")
        show(text) { [weak self] in
            guard let self else { return }
            store.load(archive, for: app.id)
            restore(before)
            selection = proposal.isNew ? nil : .nomination(nominationID)
        }
    }

    func dismissProposal(_ id: String) {
        let archive = store.archive(for: app.id)
        guard let proposal = store.removeProposal(id, for: app.id) else { return }
        if selection == .proposal(id) { selection = nil }
        show(String(localized: "Dismissed \(proposal.client)’s nomination.", comment: "kind:toast")) { [weak self] in
            guard let self else { return }
            store.load(archive, for: app.id)
        }
    }

    // MARK: - Assistants' requests

    func actionRequest(for nominationID: String) -> NominationActionRequest? {
        store.actionRequests(for: app.id, nominationID: nominationID).first
    }

    /// Accept on a request to submit or archive: the same confirmation the
    /// person's own button opens.
    func acceptActionRequest(_ request: NominationActionRequest) {
        selection = .nomination(request.nominationID)
        sheet = request.action == .submit ? .submit(request.nominationID) : .archive(request.nominationID)
    }

    func dismissActionRequest(_ request: NominationActionRequest) {
        store.removeActionRequest(request.id, for: app.id)
        show(String(localized: "Dismissed \(request.client)’s suggestion.", comment: "kind:toast")) { [weak self] in
            guard let self else { return }
            store.add(request, for: app.id)
        }
    }
}
