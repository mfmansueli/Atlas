//
//  ClaudeCodePermissionsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// What each kind of run may do: Atlas's tools always, reading the
/// project for suggestions, and building and simulators for Autopilot only.
@Suite("Claude Code permissions")
struct ClaudeCodePermissionsTests {
    private let port: UInt16 = 47321

    @Test func eachPurposePicksItsPermissions() {
        #expect(ClaudeCodeRunPurpose.test.permissions == .atlasOnly)
        #expect(ClaudeCodeRunPurpose.autopilot.permissions == .autopilot)
        let reading: [ClaudeCodeRunPurpose] = [.ask(area: "Store Page"), .suggestEverything, .translation, .captions, .privacyScan]
        for purpose in reading {
            #expect(purpose.permissions == .readProject, "\(purpose.title)")
        }
        #expect(ClaudeCodeRunPurpose.ask(area: "Store Page").title == "Ask · Store Page")
        #expect(InAppEventArtworkAskPrompt.purpose(eventID: "6835869914").permissions == .eventArtwork)
        #expect(InAppEventArtworkAskPrompt.purpose(eventID: "1") != InAppEventArtworkAskPrompt.purpose(eventID: "2"))
    }

    /// Alba's New Year Challenge run was told to render with the project's
    /// script and upload, which it couldn't; its first step, a piped
    /// `git ls-files | grep …`, was refused. The run may now upload art the
    /// project has, and is told to redraw the rest as static HTML.
    @Test func eventArtUploadsOnlyToTheEventArtLink() {
        let rules = ClaudeCodePermissions.eventArtwork.allowRules(port: port)
        #expect(rules.contains("Read"))
        #expect(rules.contains("Bash(git ls-files:*)"))
        let commands = rules.filter { $0.hasPrefix("Bash(") && !$0.hasPrefix("Bash(git ") }
        // The prompt puts the link in quotes (it has ?name=), so the quoted
        // form has its own rule: rules match the command's text.
        #expect(commands == ["Bash(curl * http://127.0.0.1:47321/event-artwork/*)", "Bash(curl * 'http://127.0.0.1:47321/event-artwork/*)"])
        #expect(ClaudeCodePermissions.eventArtwork.denyRules.isEmpty)
        let prompt = ClaudeCodePermissions.eventArtwork.systemPrompt
        #expect(prompt.contains("curl -s --data-binary @<file> '<artworkUpload link from get_in_app_events>?name=<file name>'"))
        #expect(prompt.contains("JavaScript doesn't run in its renderer"))
        #expect(prompt.contains("continue this session in Terminal"))
        #expect(!ClaudeCodePermissions.readProject.allowRules(port: port).contains { $0.contains("event-artwork") })
    }

    @Test func readingRunsAreToldNotToChainCommands() {
        for permissions in [ClaudeCodePermissions.readProject, .eventArtwork] {
            #expect(permissions.systemPrompt.contains("Find files with Glob and Grep and read them with Read."))
            #expect(permissions.systemPrompt.contains("a pipe, ;, && or cd in front of it is refused"))
        }
        #expect(!ClaudeCodePermissions.atlasOnly.systemPrompt.contains("Glob"))
    }

    /// Apple asks for no border or gradient added to the media, not for art
    /// without color changes: the first run flattened Alba's sky.
    @Test func theArtPromptKeepsTheScenesColors() {
        let prompt = InAppEventArtworkAskPrompt.text(app: "Alba", appID: "1", event: "New Year", eventID: "2")
        #expect(prompt.contains("no border or gradient overlay of your own"))
        #expect(prompt.contains("color that belongs to the scene, like a sky, is fine"))
        #expect(!prompt.contains("No words, logos, borders or gradients"))
        #expect(prompt.contains("JavaScript doesn't run"))
        #expect(prompt.contains("Never push and never submit"))
    }

    /// The art is designed like Autopilot's HTML pages: from the
    /// app's look and design project, as a page Atlas renders still or as
    /// a seamless loop; a file the project renders still goes to the link.
    @Test func theArtPromptDesignsWithClaudeDesign() {
        let prompt = InAppEventArtworkAskPrompt.text(app: "Alba", appID: "1", event: "New Year", eventID: "2")
        #expect(prompt.contains("with Claude"))
        #expect(prompt.contains("`design`, the app's look and design language"))
        #expect(prompt.contains("design from what `design` gives, and never stop for it"))
        #expect(prompt.contains("loops seamlessly over 20 seconds"))
        #expect(prompt.contains("render_event_artwork and motion: true"))
        #expect(prompt.contains("--data-binary @<file>"))
    }

    @Test func theSetupTestOnlyUsesAtlas() {
        #expect(ClaudeCodePermissions.atlasOnly.tools.isEmpty)
        #expect(ClaudeCodePermissions.atlasOnly.allowRules(port: port) == ["mcp__atlas"])
    }

    @Test func readingTheProjectAllowsOnlyReadOnlyGit() {
        let rules = ClaudeCodePermissions.readProject.allowRules(port: port)
        #expect(rules.contains("mcp__atlas"))
        #expect(rules.contains("Read"))
        #expect(rules.contains("Bash(git log:*)"))
        let commands = rules.filter { $0.hasPrefix("Bash(") }
        #expect(commands.allSatisfy { $0.hasPrefix("Bash(git ") }, "\(commands)")
        for writing in ["push", "commit", "reset", "checkout", "config"] {
            #expect(!rules.contains("Bash(git \(writing):*)"))
        }
    }

    @Test func autopilotAlsoBuildsAndUploadsOnlyToAtlas() {
        let rules = ClaudeCodePermissions.autopilot.allowRules(port: port)
        #expect(rules.contains("Bash(xcodebuild:*)"))
        #expect(rules.contains("Bash(xcrun simctl:*)"))
        let uploads = rules.filter { $0.contains("curl") }
        #expect(uploads == ["Bash(curl * http://127.0.0.1:47321/autopilot/*)"])
        #expect(ClaudeCodePermissions.autopilot.systemPrompt.contains("curl -s --data-binary"))
    }

    /// MB Admin's App Preview recordings were left out: recordVideo
    /// finishes its file only on SIGINT, and kill -INT was refused.
    @Test func autopilotCanStopARecordingAndNothingElse() {
        let rules = ClaudeCodePermissions.autopilot.allowRules(port: port)
        #expect(rules.contains("Bash(killall -INT simctl)"))
        #expect(!rules.contains { $0.hasPrefix("Bash(kill") && $0 != "Bash(killall -INT simctl)" })
        #expect(ClaudeCodePermissions.autopilot.systemPrompt.contains("with exactly killall -INT simctl"))
        #expect(AutopilotRun.recordingHow.contains("Stop it with exactly killall -INT simctl"))
        #expect(!AutopilotRun.recordingHow.contains("kill -INT <pid>"))
        #expect(!ClaudeCodePermissions.readProject.allowRules(port: port).contains("Bash(killall -INT simctl)"))
    }

    /// `VAR=value xcodebuild …` doesn't match `Bash(xcodebuild:*)`, so
    /// Autopilot is told so, how UI tests get their language instead, and
    /// how to report a refusal.
    @Test func autopilotKnowsWhatGetsRefused() {
        let prompt = ClaudeCodePermissions.autopilot.systemPrompt
        #expect(prompt.contains("VAR=value in front of it, cd or a pipe is refused"))
        #expect(prompt.contains("testArguments (-testLanguage, -testRegion)"))
        #expect(prompt.contains("report_capture_problem with refusedCommand"))
    }

    /// A run Atlas starts has only Atlas's MCP server, so it
    /// can't open Claude Design or Figma: it designs from the brief rather
    /// than stopping at Design.
    @Test func autopilotDesignsFromTheBriefWithoutStopping() {
        let prompt = ClaudeCodePermissions.autopilot.systemPrompt
        #expect(prompt.contains("Claude Design and Figma can't be opened from here."))
        #expect(prompt.contains("tried with render_artwork); when next_step hands you prompts, follow them"))
        #expect(prompt.contains("concepts with propose_artwork_concept and their changes and loops with revise_artwork_concept"))
        #expect(prompt.contains("don't stop because the design project can't be opened"))
        #expect(!ClaudeCodePermissions.readProject.systemPrompt.contains("Claude Design"))
    }

    /// Changing a simulator's displays (`simctl io … screenConfig`) left
    /// iPhone Duo's SpringBoard crashing on every start, so Autopilot may run
    /// any simctl command but that one, and the other runs deny nothing
    /// they could run anyway.
    @Test func autopilotMayNotChangeASimulatorsDisplays() {
        #expect(ClaudeCodePermissions.autopilot.denyRules == ["Bash(xcrun simctl io * screenConfig*)"])
        #expect(ClaudeCodePermissions.atlasOnly.denyRules.isEmpty)
        #expect(ClaudeCodePermissions.readProject.denyRules.isEmpty)
        let how = AutopilotRun.howToCapture(.iPhoneDuo) ?? ""
        #expect(how.contains("Never change its displays with xcrun simctl io … screenConfig"))
    }

    @Test func noRunMayEditFilesOrUseTheWeb() {
        for permissions in ClaudeCodePermissions.allCases {
            let everything = permissions.tools + permissions.allowRules(port: port)
            // Make It Work… is the one run that changes the project.
            let tools = permissions == .deepLinkWork ? ["NotebookEdit", "WebFetch", "WebSearch"] : ["Edit", "Write", "NotebookEdit", "WebFetch", "WebSearch"]
            for tool in tools {
                #expect(!everything.contains(tool), "\(permissions.title) allows \(tool)")
            }
            // Bash is available to some, but only for the commands allowed.
            #expect(!permissions.allowRules(port: port).contains("Bash"), "\(permissions.title) allows every command")
        }
    }

    /// Check in the Code only reads and tries the link in a simulator;
    /// Make It Work… may also edit the project. Neither may upload a build.
    @Test func deepLinkRunsTryTheLinkButNeverUpload() {
        let eventID = "6740000000"
        #expect(InAppEventDeepLinkAskPrompt.purpose(.check, eventID: eventID).permissions == .deepLinkCheck)
        #expect(InAppEventDeepLinkAskPrompt.purpose(.makeItWork, eventID: eventID).permissions == .deepLinkWork)
        let check = ClaudeCodePermissions.deepLinkCheck
        let work = ClaudeCodePermissions.deepLinkWork
        #expect(!check.tools.contains("Edit"))
        #expect(!check.allowRules(port: port).contains("Write"))
        #expect(work.tools.contains("Edit"))
        #expect(work.allowRules(port: port).contains("Write"))
        for permissions in [check, work] {
            let rules = permissions.allowRules(port: port)
            #expect(rules.contains("Bash(xcrun simctl:*)"))
            #expect(rules.contains("Bash(xcodebuild:*)"))
            #expect(permissions.denyRules.contains("Bash(xcrun altool:*)"))
            #expect(permissions.denyRules.contains("Bash(xcodebuild * -exportArchive*)"))
            #expect(permissions.systemPrompt.contains("xcrun simctl openurl booted"))
            #expect(permissions.systemPrompt.contains("Never archive, export or upload a build"))
        }
        #expect(work.systemPrompt.contains("Never commit or push."))
        #expect(check.systemPrompt.contains("Don't change the project"))
        // Other runs never build.
        #expect(!ClaudeCodePermissions.readProject.allowRules(port: port).contains("Bash(xcodebuild:*)"))
    }

    @Test func theSystemPromptSaysNobodyIsWatching() {
        for permissions in ClaudeCodePermissions.allCases {
            let prompt = permissions.systemPrompt
            #expect(prompt.contains("don't ask questions"))
            #expect(prompt.contains("Never push"))
        }
        #expect(!ClaudeCodePermissions.readProject.systemPrompt.contains("xcodebuild"))
    }

    /// Make Screenshots for This Page: the plan and the looks only read the
    /// project; capturing screens again also builds and runs the app, and
    /// uploads only to the page's link. Each has a purpose of its own, so
    /// the launcher never hands one the other's session.
    @Test func pageCapturesBuildAndUploadOnlyToThePagesLink() {
        let plan = PageShotsPrompt.purpose(pageName: "Gratitude")
        let looks = PageShotsPrompt.looksPurpose(pageName: "Gratitude")
        let captures = PageShotsPrompt.capturesPurpose(pageName: "Gratitude")
        #expect(Set([plan, looks, captures]).count == 3)
        #expect(plan.isPageScreenshots && looks.isPageScreenshots && captures.isPageScreenshots)
        #expect(plan.permissions == .readProject)
        #expect(looks.permissions == .readProject)
        #expect(captures.permissions == .pageCaptures)

        let rules = ClaudeCodePermissions.pageCaptures.allowRules(port: port)
        #expect(rules.contains("Bash(xcodebuild:*)"))
        #expect(rules.contains("Bash(xcrun simctl:*)"))
        #expect(rules.contains("Bash(curl * http://127.0.0.1:\(port)/page-shots/*)"))
        // Rules match the text: a link in quotes needs its own rule.
        #expect(rules.contains("Bash(curl * 'http://127.0.0.1:\(port)/page-shots/*)"))
        let otherLinks = rules.filter { $0.contains("/autopilot/") || $0.contains("/event-artwork/") }
        #expect(otherLinks.isEmpty)
        #expect(ClaudeCodePermissions.pageCaptures.denyRules.contains("Bash(xcrun altool:*)"))
        #expect(ClaudeCodePermissions.pageCaptures.systemPrompt.contains("xcrun simctl io booted screenshot"))
    }

    /// Alba's Topics and My Phrases screens need taps, which only its
    /// screenshot UI tests make: the captures session may run them and
    /// export what they attach.
    @Test func pageCapturesMayRunTheProjectsScreenshotTests() {
        let rules = ClaudeCodePermissions.pageCaptures.allowRules(port: port)
        #expect(rules.contains("Bash(xcrun xcresulttool:*)"))
        let system = ClaudeCodePermissions.pageCaptures.systemPrompt
        #expect(system.contains("-only-testing"))
        #expect(system.contains("build settings after it"))
        #expect(system.contains("xcrun xcresulttool export attachments"))
        let prompt = PageShotsPrompt.captures(app: "Alba", appID: "6825428345", page: "Gratitude")
        #expect(prompt.contains("screenshot UI tests"))
        #expect(prompt.contains("NAME=value"))
        // A TEST_RUNNER_ variable only works in front of xcodebuild, which
        // the session can't run.
        #expect(!prompt.contains("TEST_RUNNER_") && !system.contains("TEST_RUNNER_"))
        // Reading the project alone still can't export results.
        #expect(!ClaudeCodePermissions.readProject.allowRules(port: port).contains("Bash(xcrun xcresulttool:*)"))
    }
}
