//
//  AppInformationDebugScenes+EncryptionKey.swift
//  Atlas
//

#if DEBUG
import SwiftUI

// Export Compliance's "Skip the question for every build" and the page's
// wording, on Lumen Journal (no project folder is read):
//
// - `info-key-ready`: Claude Code's exempt answers confirmed, so Add It
//   to the Project is on.
// - `info-key-running`: the same with its run going ("working on the
//   key").
// - `info-key-added`: Claude Code's report: added in project.pbxproj
//   (Lumen), Debug and Release, with its commit.
// - `info-key-failed`: Claude Code couldn't add it: Try Again.
// - `info-key-inferred`: nobody answered in Atlas; builds 44, 43 and 42
//   arrived answered: "Builds already answer it", inferred, with Check in
//   the Project….
// - `info-export-first`: a first version 1.0 in Prepare for Submission
//   whose build only says exempt: the bar says 1.0 isn't on the App Store
//   yet, the answers read Yes and exempt "from build 3's answer", and the
//   newest build still waits for its answer.
extension AppInformationDebugScenes {
    static let encryptionKeyIDs = [
        "info-key-ready", "info-key-running", "info-key-added", "info-key-failed", "info-key-inferred", "info-export-first",
    ]

    private static var lumen: StoreApp.ID { DebugFixtures.AppID.lumen }

    @MainActor
    static func encryptionKeyScene(_ id: String) -> AnyView? {
        guard encryptionKeyIDs.contains(id) else { return nil }
        let keys = EncryptionKeyStore.shared
        keys.removeReport(for: lumen)
        EncryptionKeyProjectCenter.shared.pin(.noFolder, for: lumen)
        var appInformation = DebugAppInformationServices()
        let confirms = ["info-key-ready", "info-key-running", "info-key-added", "info-key-failed"].contains(id)
        switch id {
        case "info-key-added": keys.setReport(report(.added))
        case "info-key-failed": keys.setReport(report(.couldNotAdd))
        case "info-key-inferred":
            appInformation.notes.setNotes(AppInformationNotes(), for: lumen)
            appInformation.sampleBuilds = ["44", "43", "42"].map { (number: String) in
                EncryptionKeyBuild(id: "lumen-build-\(number)", number: number, usesNonExemptEncryption: false)
            }
        case "info-export-first":
            appInformation.notes.setNotes(AppInformationNotes(), for: lumen)
            appInformation.lumenContent = firstVersion
            appInformation.sampleBuilds = [
                EncryptionKeyBuild(id: "lumen-build-4", number: "4", usesNonExemptEncryption: nil),
                EncryptionKeyBuild(id: "lumen-build-3", number: "3", usesNonExemptEncryption: false),
            ]
        default: break
        }
        appInformation.opening = DebugAppInformationServices.Opening { model in
            model.page = .exportCompliance
            if confirms { model.confirmExportEvidence() }
        }
        var services = WorkspaceServices.debug
        services.appInformation = appInformation
        let scene = DebugMainScene(services: services, section: .appInformation, pendingChanges: [])
        return id == "info-key-running" ? AnyView(scene.modifier(KeyRunGoing())) : AnyView(scene)
    }

    /// Claude Code's report on Lumen's key.
    static func report(_ status: EncryptionKeyReport.Status) -> EncryptionKeyReport {
        let place = EncryptionKeyReport.Place(
            file: "Lumen.xcodeproj/project.pbxproj", buildSetting: "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption",
            target: "Lumen", configurations: ["Debug", "Release"]
        )
        return status == .couldNotAdd
            ? EncryptionKeyReport(
                appID: lumen, status: .couldNotAdd,
                reason: "No target in Lumen.xcodeproj builds com.northpier.lumen: the project folder may be another app’s.",
                client: "Claude Code", date: DebugReleaseData.today
            )
            : EncryptionKeyReport(
                appID: lumen, status: status, value: .no, places: [place], commit: "4f2a9c1e7b", notes: nil,
                client: "Claude Code", date: DebugReleaseData.today
            )
    }

    /// Lumen 1.0 in Prepare for Submission, never on the App Store, with
    /// build 3 attached, which only says exempt.
    static var firstVersion: AppInformationContent {
        var content = DebugAppInformationContent.lumen(versionID: nil)
        let version = StorePageVersion(
            id: "lumen-v10", listingVersion: ListingVersion("1.0", state: .prepareForSubmission, isFirstVersion: true), platform: "IOS"
        )
        content.versions = [version]
        content.version = version
        content.ids.versionID = version.id
        content.export = ExportComplianceValues(buildID: "lumen-build-3", buildNumber: "3", usesNonExemptEncryption: false)
        return content
    }

    /// Add It to the Project's run, going as the scene opens.
    private struct KeyRunGoing: ViewModifier {
        @Environment(ClaudeCodeLauncher.self) private var launcher

        func body(content: Content) -> some View {
            content.task {
                guard launcher.latestRun(appID: DebugFixtures.AppID.lumen, purpose: .encryptionKey) == nil else { return }
                var run = ClaudeCodeRun(
                    id: UUID(), appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", purpose: .encryptionKey,
                    prompt: "Add the export compliance key", workingDirectory: ProjectFolderPath.expanded("~/Developer/Lumen"), startedAt: .now
                )
                run.phase = .working
                launcher.append(run)
            }
        }
    }
}
#endif
