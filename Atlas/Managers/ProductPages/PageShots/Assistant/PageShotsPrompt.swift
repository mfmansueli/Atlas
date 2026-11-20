//
//  PageShotsPrompt.swift
//  Atlas
//

import Foundation

/// What Make Screenshots for This Page starts Claude Code with (or copies
/// when Atlas can't start it here): read the run, find what this page's
/// audience came for in the project, choose the order and write the
/// captions, then send the plan. Ask for Changes gets its own prompt.
enum PageShotsPrompt {
    static func purpose(pageName: String) -> ClaudeCodeRunPurpose {
        .pageScreenshots(pageName: pageName)
    }

    static func plan(app: String, appID: String, page: String, languages: Int) -> String {
        String(localized: """
        The person asked Atlas for the custom product page “\(page)” of \(app) (app \(appID)) to have its own \
        screenshots: the default set’s screens in another order, with captions written for this page’s audience, in \
        \(languages) languages. Work in this order.
        1. Read get_page_screenshots with page “\(page)”: who the page is for, its brief, keywords and promotional text, \
        the default set’s screens (their captures are attached) and their captions, the languages and the rules.
        2. Look in the project with Glob, Grep and Read for what each screen does for this audience, so the captions say \
        it in the app’s own words.
        3. Choose the order that tells this page’s story (its first three show in search results) and write a caption \
        for each screen in the primary language, then in the others: translated for meaning, as short.
        4. Send it with propose_page_screenshots: the primary language first, then the other languages a few at a time \
        with the same screens. Fix every caption it lists in `refused` and send it again.
        Never push and never submit the page: the person looks at the plan in Atlas and makes the set.
        """)
    }

    static func change(app: String, appID: String, page: String, request: String) -> String {
        String(localized: """
        The person looked at the screenshots Atlas made for the custom product page “\(page)” of \(app) (app \(appID)) \
        and asked for a change: “\(request)”. Read get_page_screenshots with page “\(page)”: its run has the plan and the \
        change. Change only what they asked and send the plan again with propose_page_screenshots: every screen in the \
        new order, with every language’s captions for the ones whose words change (the others keep theirs). Atlas lays \
        the set out again. Never push and never \
        submit the page.
        """)
    }
}
