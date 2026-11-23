//
//  EncryptionKeyAskPrompt.swift
//  Atlas
//

import Foundation

/// What Add It to the Project starts Claude Code with, or copies: add the
/// export compliance key to the app target that ships, the way the project
/// is set up, so every build uploaded from then on answers App Store
/// Connect's question itself; then report it with `report_encryption_key`.
enum EncryptionKeyAskPrompt {
    static let purpose = ClaudeCodeRunPurpose.encryptionKey

    static func text(app: String, appID: String, bundleID: String, answer: EncryptionKeyAnswer) -> String {
        let key = EncryptionKeyAnswer.key
        let codeKey = EncryptionKeyAnswer.codeKey
        let value = answer.value.rawValue
        let start = String(localized: """
        \(app) (app \(appID), bundle ID \(bundleID)) answers App Store Connect’s export compliance question by hand for \
        every build. Its answer is settled in Atlas from \(answer.basisText): \(answer.value.meaning), so \(key) is \(value). \
        Add the key to the project so every build uploaded from now on answers it itself. get_export_compliance's \
        infoPlistKey says the same.
        """)
        let what = answer.value == .yes
            ? String(localized: """
            The encryption isn’t exempt, so the key is YES and \(codeKey) names the approved encryption declaration \
            \(answer.declarationID ?? ""): its code is \(answer.code ?? ""). With generated Info.plist settings that's \
            INFOPLIST_KEY_\(key) = YES and INFOPLIST_KEY_\(codeKey) = \(answer.code ?? ""); in an Info.plist, \
            <key>\(key)</key><true/> and <key>\(codeKey)</key><string>\(answer.code ?? "")</string>.
            """)
            : String(localized: """
            With generated Info.plist settings that's INFOPLIST_KEY_\(key) = NO; in an Info.plist, \
            <key>\(key)</key><false/>.
            """)
        let target = String(localized: """
        1. Find the app target that ships: the one whose PRODUCT_BUNDLE_IDENTIFIER is \(bundleID) (fill in $(…) \
        references and settings from .xcconfig files; with a workspace, look in each .xcodeproj).
        2. Add the key the way that target is set up. When it has GENERATE_INFOPLIST_FILE = YES, add the build setting \
        to every build configuration of that target (Debug, Release and any other), beside its other INFOPLIST_KEY_ \
        settings in project.pbxproj, or in the .xcconfig file its configurations use when that's where they are. \
        Otherwise add the key to the Info.plist its INFOPLIST_FILE names, in the file's own format. Not both. When a \
        key isn't one this Xcode generates from an INFOPLIST_KEY_ setting, put it in the target's Info.plist instead.
        3. Leave other targets alone: extensions, widgets, frameworks and test targets ship inside the app's upload, and \
        App Store Connect asks the question once for it. Only an embedded app with its own bundle that App Store \
        Connect reads in the upload too, such as a watchOS app, gets the same key the same way; name it in where.
        4. When the key is already there with \(value), change nothing and report alreadyThere. When it says the other \
        value, change it to \(value) (the answer is settled in Atlas), report added, and say in notes what it was.
        5. Check it: plutil -lint <the Info.plist>, or xcodebuild -showBuildSettings for the target. Don't build, \
        archive or upload: the person uploads the next build.
        """)
        let commit = String(localized: """
        Commit only when the project's own instructions (CLAUDE.md, AGENTS.md or CONTRIBUTING) say changes are \
        committed: then commit just these files with a short message and report the commit. Never push.
        """)
        let report = String(localized: """
        Then report it with report_encryption_key: status (added, alreadyThere, or couldNotAdd with reason), value \
        (\(value)), where (each file with its line, or the build setting, the target and its configurations), commit \
        when you made one, and notes. Never change App Store Connect: the person reviews everything in Atlas.
        """)
        return [start, what, target, commit, report].joined(separator: "\n\n")
    }
}
