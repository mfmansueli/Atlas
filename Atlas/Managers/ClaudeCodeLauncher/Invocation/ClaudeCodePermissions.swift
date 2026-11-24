//
//  ClaudeCodePermissions.swift
//  Atlas
//

import Foundation

/// What a run Atlas starts may do. Runs are unattended, so they're
/// started in Claude Code's restricted mode: the person's own settings
/// files (and their allow rules) are ignored, file tools stay inside the
/// project folder, only the tools named here are available, and anything
/// these rules don't allow is refused instead of asked.
enum ClaudeCodePermissions: Hashable, Sendable, CaseIterable {
    /// The setup test: Atlas's tools only.
    case atlasOnly
    /// Suggestions, translations and the privacy scan: read the project and
    /// its git history.
    case readProject
    /// Screenshot Autopilot: also build the app, drive the simulators and
    /// upload captures to Atlas.
    case autopilot
    /// An In-App Event's card and details page: read the project, and
    /// upload a file it already has to Atlas's event art link.
    case eventArtwork
    /// Capture Screens Again for a product page: read the project, build
    /// the app, run it in a simulator and upload captures to the page's
    /// link. Never changes the project.
    case pageCaptures
    /// Check in the Code: read the project, build the app and try an
    /// event's deep link in a simulator, without changing anything.
    case deepLinkCheck
    /// Make It Work…: also change the project so the app opens an
    /// event's deep link (the one run that may edit files, inside the
    /// project folder only), and bump its build number. Never archives or
    /// uploads.
    case deepLinkWork
    /// Add It to the Project on Export Compliance: read the project and
    /// add the export compliance key to the app target (its build settings
    /// or Info.plist), check it with plutil or xcodebuild's settings, and
    /// commit only when the project's own instructions say so. Never
    /// builds, archives, uploads or pushes.
    case encryptionKey
    /// Make Review Screenshots… in Pricing: read the project, build the
    /// app, open its paywall in a simulator and upload each capture to the
    /// review screenshot link. Never changes the project.
    case reviewShots
    /// Add StoreKit Configuration…: the same, and also add a StoreKit
    /// configuration to the project (and set it in the scheme's Run
    /// action) so the paywall shows prices in Simulator.
    case reviewShotsStoreKit

    /// `--tools`: the built-in tools available at all.
    var tools: [String] {
        switch self {
        case .atlasOnly: []
        case .readProject, .autopilot, .eventArtwork, .deepLinkCheck, .pageCaptures, .reviewShots: ["Read", "Grep", "Glob", "Bash"]
        case .deepLinkWork, .reviewShotsStoreKit, .encryptionKey: ["Read", "Grep", "Glob", "Edit", "Write", "Bash"]
        }
    }

    /// The `permissions.allow` rules passed with `--settings`.
    func allowRules(port: UInt16) -> [String] {
        let atlas = ["mcp__\(MCPEndpoint.serverName)"]
        let reading = ["Read", "Grep", "Glob"] + Self.gitCommands.map { "Bash(git \($0):*)" }
        switch self {
        case .atlasOnly:
            return atlas
        case .readProject:
            return atlas + reading
        case .eventArtwork:
            // Art goes to the event art upload link, and nowhere else.
            return atlas + reading + Self.uploadRules(port: port, path: "/event-artwork/")
        case .autopilot:
            let building = [
                "Bash(xcodebuild:*)",
                "Bash(xcrun simctl:*)",
                "Bash(xcrun xcresulttool:*)",
                "Bash(open -a Simulator:*)",
                "Bash(mkdir:*)",
                "Bash(ls:*)",
                "Bash(sleep:*)",
                "Bash(echo:*)",
                // Stops an App Preview's recordVideo the way Control-C does,
                // so the file is finished. Without it, MB Admin's App Preview
                // recordings were left out: kill -INT was refused.
                "Bash(\(Self.stopRecordingCommand))",
                // Captures go to Atlas's upload endpoint, and nowhere else.
                "Bash(curl * http://127.0.0.1:\(port)/autopilot/*)",
            ]
            return atlas + reading + building
        case .deepLinkCheck:
            return atlas + reading + Self.linkCommands
        case .pageCaptures:
            // Captures go to the page's upload link, and nowhere else. The
            // project's own screenshot UI tests leave theirs in a result
            // bundle, which xcresulttool exports.
            return atlas + reading + Self.linkCommands + ["Bash(xcrun xcresulttool:*)"]
                + Self.uploadRules(port: port, path: MCPEndpoint.pageShotsPath)
        case .deepLinkWork:
            return atlas + reading + ["Edit", "Write"] + Self.linkCommands
        case .encryptionKey:
            return atlas + reading + ["Edit", "Write"] + Self.keyCommands
        case .reviewShots, .reviewShotsStoreKit:
            // Captures go to the review screenshot link, and nowhere else.
            let capturing = atlas + reading + Self.linkCommands + ["Bash(xcrun xcresulttool:*)"]
                + Self.uploadRules(port: port, path: MCPEndpoint.reviewScreenshotPath)
            return self == .reviewShotsStoreKit ? capturing + ["Edit", "Write"] : capturing
        }
    }

    /// Uploads to one of Atlas's links, with the link as is or in single
    /// quotes: rules match the command's text, so `'http://…'` doesn't
    /// match `http://…`, and Gratitude's captures were refused that way.
    static func uploadRules(port: UInt16, path: String) -> [String] {
        let link = "http://127.0.0.1:\(port)\(path)"
        return ["Bash(curl * \(link)*)", "Bash(curl * '\(link)*)"]
    }

    /// What checking a deep link may run: build the app, run it in a
    /// simulator and open the link there.
    static let linkCommands = [
        "Bash(xcodebuild:*)",
        "Bash(xcrun simctl:*)",
        "Bash(open -a Simulator:*)",
        "Bash(mkdir:*)",
        "Bash(ls:*)",
        "Bash(sleep:*)",
        "Bash(echo:*)",
    ]

    /// What adding the export compliance key may run: check the Info.plist
    /// and the target's build settings, and commit the change when the
    /// project's own instructions say changes are committed.
    static let keyCommands = [
        "Bash(plutil -lint *)",
        "Bash(plutil -p *)",
        "Bash(xcodebuild -list*)",
        "Bash(xcodebuild -showBuildSettings*)",
        "Bash(xcodebuild -project * -list*)",
        "Bash(xcodebuild -project * -showBuildSettings*)",
        "Bash(xcodebuild -workspace * -showBuildSettings*)",
        "Bash(git add:*)",
        "Bash(git commit:*)",
    ]

    /// What a deep link run may never do: send a build to App Store
    /// Connect.
    static let uploadCommands = [
        "Bash(xcodebuild -exportArchive*)",
        "Bash(xcodebuild * -exportArchive*)",
        "Bash(xcrun altool:*)",
        "Bash(xcrun notarytool:*)",
    ]

    /// The `permissions.deny` rules, which win over the allow rules.
    ///
    /// Autopilot may run any `xcrun simctl` command, but not change a
    /// simulator's displays: trying to open iPhone Duo with `simctl io …
    /// screenConfig --display=1 power off`, an assistant left its display
    /// configuration invalid, and the simulator's SpringBoard crashed again
    /// on every start until the simulator was restarted.
    var denyRules: [String] {
        switch self {
        case .atlasOnly, .readProject, .eventArtwork: []
        case .autopilot: ["Bash(xcrun simctl io * screenConfig*)"]
        case .deepLinkCheck, .deepLinkWork, .pageCaptures, .reviewShots, .reviewShotsStoreKit:
            Self.uploadCommands + ["Bash(xcrun simctl io * screenConfig*)"]
        case .encryptionKey:
            Self.uploadCommands + ["Bash(xcodebuild archive*)", "Bash(xcodebuild * archive*)", "Bash(git push:*)"]
        }
    }

    /// The one command that stops a recording: it can only interrupt
    /// simulator commands, and never the shell running it (as `pkill -f`
    /// would).
    static let stopRecordingCommand = "killall -INT simctl"

    /// Read-only git subcommands.
    static let gitCommands = ["log", "show", "diff", "tag", "describe", "rev-parse", "ls-files", "status", "branch"]

    /// What Claude is told about running unattended, after Claude Code's own
    /// system prompt.
    var systemPrompt: String {
        var lines = [
            "Atlas, a Mac app, started this Claude Code session for the person, without a terminal.",
            "Nobody is watching it live: don't ask questions, and don't wait for an answer.",
            "Permission prompts are refused automatically, so stay within the allowed tools: Atlas's MCP tools"
                + (self == .atlasOnly ? "." : ", reading files in this project and read-only git commands."),
            "Never push or change App Store Connect directly; everything goes through Atlas's tools, and the person reviews it there.",
            "If something you need is refused or missing, say so in one sentence in your last message and finish.",
        ]
        if [.readProject, .eventArtwork, .deepLinkCheck, .deepLinkWork, .encryptionKey, .pageCaptures, .reviewShots, .reviewShotsStoreKit]
            .contains(self)
        {
            lines.append(
                "Find files with Glob and Grep and read them with Read. Run each allowed command on its own: "
                    + "a pipe, ;, && or cd in front of it is refused."
            )
        }
        if self == .eventArtwork {
            lines.append(
                "For an In-App Event's art you may also upload a file that's already in this project, with exactly: "
                    + "curl -s --data-binary @<file> '<artworkUpload link from get_in_app_events>?name=<file name>'. "
                    + "You can't run scripts or write files here, so when the project draws its visuals in code (a render "
                    + "script, Canvas or shader code), redraw them as one static page of HTML, CSS and inline SVG for "
                    + "render_event_artwork: JavaScript doesn't run in its renderer. If the project's own renderer would make "
                    + "better art, such as a video loop, give its command in one sentence in your last message, for the "
                    + "person to continue this session in Terminal."
            )
        }
        if self == .deepLinkCheck || self == .deepLinkWork {
            lines.append(
                "To try a deep link you may also run xcodebuild, xcrun simctl, open -a Simulator, mkdir, ls, sleep and echo, "
                    + "each on its own: build for a simulator, install and launch the app with xcrun simctl, and open the link "
                    + "with xcrun simctl openurl booted '<link>'. Never archive, export or upload a build: the person uploads it."
            )
        }
        if self == .pageCaptures {
            lines.append(
                "To capture a product page's screens you may also run xcodebuild, xcrun simctl, xcrun xcresulttool, "
                    + "open -a Simulator, mkdir, ls, sleep and echo, each on its own. When the project has screenshot UI tests "
                    + "(they tap to the screens that need it), run the ones you need with xcodebuild test -only-testing:… "
                    + "-resultBundlePath <path>, giving the values they read as build settings after it (NAME=value: the tests' "
                    + "comments or the test scheme's environment say which), "
                    + "and export the captures with xcrun xcresulttool export attachments. Otherwise build for a simulator, "
                    + "install and launch the app with xcrun simctl (launch arguments such as -AppleLanguages go after the "
                    + "bundle ID), and save each screen with xcrun simctl io booted screenshot <file>. "
                    + "Upload each with exactly: curl -s --data-binary @<file> -H 'Content-Type: image/png' "
                    + "<uploadURL from get_page_screenshots' recapture>, then name it with report_page_capture. "
                    + "Run xcodebuild in the foreground and wait for it. You can't edit the "
                    + "project: set screens up with the app's own launch arguments and sample data, and if a screen can't be "
                    + "shown that way, say so in your last message. Never archive, export or upload a build."
            )
        }
        if self == .reviewShots || self == .reviewShotsStoreKit {
            lines.append(Self.reviewShotsPrompt)
            lines.append(
                self == .reviewShots
                    ? "You can't edit the project here: when the paywall can't be reached or shows no prices, say so with "
                    + "report_review_screenshot_run."
                    : "You may edit and write files in this project only, to add the StoreKit configuration and set it in the "
                    + "Run action of the scheme you build. Keep the change small, and say in your last message which files you "
                    + "changed. Never commit or push."
            )
        }
        if self == .deepLinkCheck {
            lines.append("Don't change the project: you can't edit files here. Say what to change in report_deep_link_check's problems.")
        }
        if self == .deepLinkWork {
            lines.append(
                "You may edit and write files in this project only, to make the app open the deep link. Keep the change "
                    + "small and in the project's own style, add a test when the project has tests, and say in your last "
                    + "message which files you changed. Never commit or push."
            )
        }
        if self == .encryptionKey {
            lines.append(
                "You may edit and write files in this project only, to add the export compliance key to the app target's "
                    + "build settings or Info.plist: change nothing else. To check it you may also run plutil -lint, plutil -p, "
                    + "xcodebuild -list and xcodebuild -showBuildSettings, each on its own; never build, archive, export or "
                    + "upload. Commit (git add and git commit of the files you changed) only when the project's own "
                    + "instructions, such as its CLAUDE.md, say changes are committed. Never push."
            )
        }
        if self == .autopilot {
            lines.append(
                "For screenshots you may also run xcodebuild, xcrun simctl, xcrun xcresulttool, open -a Simulator, mkdir, ls, sleep and echo, "
                    + "and stop an App Preview recording (xcrun simctl io … recordVideo, started in the background) with exactly "
                    + "\(Self.stopRecordingCommand). "
                    + "Upload each capture with exactly: curl -s --data-binary @<file> -H 'Content-Type: image/png' <upload URL from get_capture_plan>. "
                    + "Run each command on its own, without chaining other commands. "
                    + "Run xcodebuild in the foreground and wait for it, however long it takes: only an App Preview recording goes in "
                    + "the background. This session ends when your turn ends and what runs in the background ends with it, so never "
                    + "finish a turn waiting for something to report back. "
                    + "Each command must start with one of those programs: VAR=value in front of it, cd or a pipe is refused. "
                    + "UI tests get their language and region from the locale's testArguments (-testLanguage, -testRegion) "
                    + "and anything else from their scheme or test plan. "
                    + "If a command is refused, don't try it in another form: report_capture_problem with refusedCommand, "
                    + "with what to change in the project as proposedFix, and go on with the other screens. "
                    + "You can't edit the project here, so a fix that changes it (a test, a scheme, sample data) is reported once, "
                    + "with changesProject: true and the file and line in proposedFix. "
                    + "When get_capture_plan's appLook isn't known, read the app's design language in the project and send it "
                    + "with report_app_support's look before choosing screens: every design in the run starts from it. "
                    + "Before capturing, check: " + AutopilotPreflight.checks.joined(separator: " ")
            )
            lines.append(
                "Claude Design and Figma can't be opened from here. When next_step says design, design the directions from "
                    + "get_design_brief (the picks, captions, canvases and the design project's summary when it has one) "
                    + "and send each with propose_direction (with the header and search pages when the brief has artworkDesign, "
                    + "tried with render_artwork); when next_step hands you prompts, follow them and send the header and search "
                    + "concepts with propose_artwork_concept and their changes and loops with revise_artwork_concept; "
                    + "don't stop because the design project can't be opened."
            )
        }
        return lines.joined(separator: "\n")
    }

    /// What a review screenshot run is told about capturing a paywall
    /// without tapping, and uploading.
    static let reviewShotsPrompt = """
    To capture purchase screens you may also run xcodebuild, xcrun simctl, xcrun xcresulttool, open -a Simulator, \
    mkdir, ls, sleep and echo, each on its own. You can't tap in the Simulator from here: open the paywall and select \
    a plan with the app's own deep links (xcrun simctl openurl booted '<link>'), launch arguments or debug scenes \
    (they go after the bundle ID in xcrun simctl launch), or its UI tests (xcodebuild test -only-testing:… \
    -resultBundlePath <path>, then xcrun xcresulttool export attachments). When no way selects a plan, a capture where \
    the product's plan and price show on the paywall is fine: planShown is then the selected plan's name. Save each \
    screen with xcrun simctl io booted screenshot <file>. Upload each with exactly: curl -s --data-binary @<file> \
    -H 'Content-Type: image/png' '<reviewScreenshotUploadURL from get_subscriptions>?name=<file name>'. \
    Run xcodebuild in the foreground and wait for it. Never buy anything, and never archive, export or upload a build.
    """

    /// For Settings: "Suggestions, translations, privacy".
    var title: String {
        switch self {
        case .atlasOnly: String(localized: "Setup test")
        case .readProject: String(localized: "Suggestions, translations, privacy")
        case .autopilot: String(localized: "Screenshot Autopilot")
        case .eventArtwork: String(localized: "In-App Event art")
        case .deepLinkCheck: String(localized: "In-App Event deep link check")
        case .deepLinkWork: String(localized: "In-App Event deep link fix")
        case .encryptionKey: String(localized: "Export compliance key")
        case .pageCaptures: String(localized: "Custom Product Page captures")
        case .reviewShots: String(localized: "Pricing review screenshots")
        case .reviewShotsStoreKit: String(localized: "Pricing review screenshots with StoreKit")
        }
    }

    /// For Settings: what it may do, in words.
    var detail: String {
        switch self {
        case .atlasOnly: String(localized: "Atlas’s tools only")
        case .readProject: String(localized: "Atlas’s tools, reading the project, read-only git")
        case .autopilot: String(localized: "Also xcodebuild, xcrun simctl and uploads to Atlas")
        case .eventArtwork: String(localized: "Reading the project, and uploads of its art to Atlas")
        case .deepLinkCheck: String(localized: "Reading the project, xcodebuild and xcrun simctl; never uploads")
        case .deepLinkWork: String(localized: "Also edits files in the project folder; never uploads")
        case .encryptionKey: String(localized: "Edits the app target’s build settings or Info.plist; never builds, uploads or pushes")
        case .pageCaptures: String(localized: "Reading the project, xcodebuild, xcrun simctl and uploads of captures to Atlas")
        case .reviewShots: String(localized: "Reading the project, xcodebuild, xcrun simctl and uploads of review screenshots to Atlas")
        case .reviewShotsStoreKit: String(localized: "Also adds a StoreKit configuration in the project folder; never uploads a build")
        }
    }
}
