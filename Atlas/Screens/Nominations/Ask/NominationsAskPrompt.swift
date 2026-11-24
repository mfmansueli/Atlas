//
//  NominationsAskPrompt.swift
//  Atlas
//

import Foundation

/// What Nominations asks Claude Code: suggest a nomination from what's
/// coming (the version in preparation, the app's events), or write a
/// draft's description. Everything comes back as suggestions; the
/// assistant never submits.
enum NominationsAskPrompt {
    /// The run's purpose, so the asking buttons find their own run.
    static var purpose: ClaudeCodeRunPurpose { .ask(area: String(localized: "Nominations", comment: "kind:section-title")) }

    static func suggest(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: purpose,
            prompt: String(localized: """
            Suggest a featuring nomination for \(app) in Atlas. Read get_nominations for what's already there, get_app_versions \
            and get_listing with fields ["whatsNew"] for the version being prepared, and get_in_app_events for what's coming. \
            Pick what Apple's editors would care about most: a new app is APP_LAUNCH, a version with real new features \
            APP_ENHANCEMENTS, an event or season NEW_CONTENT. Send one with propose_nomination: a name, a description of what \
            people can do (no links: links go in supplementalMaterialsUris), the start date, the devices, and the linked \
            events. Say why in one sentence with how far ahead it starts. Never submit; the person does.
            """, comment: "kind:other"),
            subject: String(localized: "Nominations · a new nomination", comment: "kind:other"),
            done: String(localized: "Done. The suggestion is at the top of Drafts.", comment: "kind:toast")
        )
    }

    static func describe(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: purpose,
            prompt: String(localized: """
            Write the descriptions of \(app)'s draft nominations in Atlas. Read get_nominations with state DRAFT, then for each \
            draft without a good description read the version being prepared (get_listing with fields ["whatsNew"]) and its \
            linked events (get_in_app_events). Write for Apple's editors: what's new, who it's for and why now, in plain \
            sentences, with no links and no promises of featuring. Send it with propose_nomination and the draft's \
            nominationId, changing only the description.
            """, comment: "kind:other"),
            subject: String(localized: "Nominations · descriptions", comment: "kind:other"),
            done: String(localized: "Done. Suggested descriptions wait on each draft.", comment: "kind:toast")
        )
    }
}
