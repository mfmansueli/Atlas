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

    static func looksPurpose(pageName: String) -> ClaudeCodeRunPurpose {
        .pageLooks(pageName: pageName)
    }

    static func capturesPurpose(pageName: String) -> ClaudeCodeRunPurpose {
        .pageCaptures(pageName: pageName)
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

    /// A new look from Claude Design: three to choose from.
    static func looks(app: String, appID: String, page: String) -> String {
        String(localized: """
        The person wants a new look for the screenshots of the custom product page “\(page)” of \(app) (app \(appID)): \
        three looks to choose from, made for this page’s audience. Work in this order.
        1. Read get_page_screenshots with page “\(page)”: who the page is for, the plan and its captions, and `look`. \
        Read get_template for the default page’s template: its fields, fonts and per-slot designs.
        2. Design three looks that are clearly different from the default page’s and from each other (background, \
        colors, caption type, device frame), that read well in every language of the page, and that still feel like \
        \(app). Design them as Atlas templates from get_template’s fields: Claude Design and Figma can’t be opened from \
        here.
        3. Send each with propose_page_look: a name, a one-sentence rationale, base (default for the default page’s \
        template, or a starter) and the template fields or ops that change. Look at the preview it returns; send a \
        look again with the same name to fix it.
        Never push and never submit the page: the person chooses one of the three in Atlas.
        """)
    }

    /// Capture screens again: the screens that should show something else
    /// for this page.
    static func captures(app: String, appID: String, page: String) -> String {
        String(localized: """
        The person asked for some screens of the custom product page “\(page)” of \(app) (app \(appID)) to be captured \
        again, so they show what this page’s audience came for. Work in this order.
        1. Read get_page_screenshots with page “\(page)”: the page, the plan, the default set’s screens (their captures \
        are attached) and `recapture`, with its upload link and the devices and languages it needs.
        2. Choose at most \(PageShotsRecapture.maxScreens) screens whose capture should show something else for this \
        audience (the lock turned on, the kind of entries this page is about). Leave the others as they are.
        3. Look for the project’s screenshot UI tests first (Grep for XCUIScreen or screenshot in its UI test files): \
        they reach the screens that need taps and set up sample data. Run the ones for your screens with xcodebuild test \
        -only-testing:… -resultBundlePath <path>, with the values they read (a topic, an entry) given after xcodebuild as \
        build settings, NAME=value (their comments or the test scheme’s environment say which; nothing goes in front of \
        xcodebuild), and export the captures with xcrun xcresulttool export attachments. Without such \
        tests, build the app and run it in the Simulator with the app’s launch arguments, then save the screen with \
        xcrun simctl io booted screenshot. Use \(ScreenshotDisplayType.iPhone.deviceName) for iPhone, \
        \(ScreenshotDisplayType.iPad.deviceName) for iPad, turned the way `recapture` says (its devices’ orientation \
        and pixel size), in each language the set is made in (-testLanguage and -testRegion, or -AppleLanguages and \
        -AppleLocale).
        4. Send each PNG with curl -s --data-binary @file.png -H 'Content-Type: image/png' <uploadURL>, the link as is \
        (not in quotes), and name it with report_page_capture: \
        the screen’s number, the language, the device, the upload ID and what it shows now.
        Never push and never submit the page, and don’t change the app’s code: the person makes the set in Atlas.
        """)
    }
}
