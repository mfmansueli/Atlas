//
//  ProjectLinkClaimsReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which links an app's project claims, read by Atlas itself from fixture
/// folders shaped like Alba's (`Alba.xcodeproj` with an old-style
/// `project.pbxproj`, `Alba/SupportFiles/Info.plist`,
/// `Alba/SupportFiles/Alba.entitlements`): a URL scheme declared, an
/// `applinks:` domain declared, nothing declared (Alba 1.2.0 as it is),
/// and an Info.plist generated from build settings alone.
@Suite("Project link claims")
struct ProjectLinkClaimsReaderTests {
    private static let infoPath = "Alba/SupportFiles/Info.plist"
    private static let entitlementsPath = "Alba/SupportFiles/Alba.entitlements"

    /// Alba's app target's Release settings, over the project's
    /// `SDKROOT = iphoneos`.
    private static let albaSettings = [
        "PRODUCT_BUNDLE_IDENTIFIER": "com.lima.alba", "INFOPLIST_FILE": infoPath, "CODE_SIGN_ENTITLEMENTS": entitlementsPath,
        "GENERATE_INFOPLIST_FILE": "YES", "MARKETING_VERSION": "1.2.0", "CURRENT_PROJECT_VERSION": "21",
    ]

    // MARK: - Fixtures

    /// A folder with `Alba.xcodeproj` (its targets' Release settings, a
    /// Debug configuration that must not count) and `files` (path →
    /// property list).
    private static func folder(
        targets: [(name: String, type: String, settings: [String: String])], files: [String: Any] = [:], projectFolder: String = ""
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "ProjectLinkClaims-\(UUID().uuidString)")
        let base = projectFolder.isEmpty ? root : root.appending(path: projectFolder)
        let project = base.appending(path: "Alba.xcodeproj")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try pbxproj(targets: targets).write(to: project.appending(path: "project.pbxproj"), atomically: true, encoding: .utf8)
        for (path, plist) in files {
            let url = base.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url)
        }
        return root
    }

    /// The old-style text Xcode writes.
    private static func pbxproj(targets: [(name: String, type: String, settings: [String: String])]) -> String {
        func settings(_ values: [String: String]) -> String {
            values.sorted { $0.key < $1.key }.map { "\($0.key) = \"\($0.value)\";" }.joined(separator: " ")
        }
        var objects = [
            "P1 = { isa = PBXProject; buildConfigurationList = PL; targets = ( \(targets.indices.map { "T\($0)" }.joined(separator: ", ")) ); };",
            "PL = { isa = XCConfigurationList; buildConfigurations = ( PR ); };",
            "PR = { isa = XCBuildConfiguration; name = Release; buildSettings = { SDKROOT = iphoneos; }; };",
        ]
        for (index, target) in targets.enumerated() {
            objects += [
                "T\(index) = { isa = PBXNativeTarget; name = \(target.name); productType = \"\(target.type)\"; buildConfigurationList = TL\(index); };",
                "TL\(index) = { isa = XCConfigurationList; buildConfigurations = ( TD\(index), TR\(index) ); };",
                "TD\(index) = { isa = XCBuildConfiguration; name = Debug; buildSettings = { MARKETING_VERSION = \"0.0.1\"; }; };",
                "TR\(index) = { isa = XCBuildConfiguration; name = Release; buildSettings = { \(settings(target.settings)) }; };",
            ]
        }
        return """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            objectVersion = 77;
            objects = {
                \(objects.joined(separator: "\n        "))
            };
            rootObject = P1;
        }
        """
    }

    private static let app = "com.apple.product-type.application"

    private static func urlTypes(_ schemes: [String]) -> [String: Any] {
        ["CFBundleURLTypes": [["CFBundleURLName": "com.lima.alba", "CFBundleURLSchemes": schemes]], "UIBackgroundModes": ["remote-notification"]]
    }

    private static func claims(_ state: ProjectLinkClaimsState) throws -> ProjectLinkClaims {
        try #require(state.claims)
    }

    // MARK: - Tests

    @Test func aDeclaredSchemeIsClaimed() throws {
        let folder = try Self.folder(
            targets: [(name: "Alba", type: Self.app, settings: Self.albaSettings)],
            files: [Self.infoPath: Self.urlTypes(["alba"]), Self.entitlementsPath: ["aps-environment": "development"]]
        )
        let state = ProjectLinkClaimsReader.read(folder: folder, bundleID: "com.lima.alba")
        let claims = try Self.claims(state)
        #expect(claims.schemes == ["alba"])
        #expect(claims.domains.isEmpty)
        #expect(claims.targets == ["Alba"])
        // Release's, not Debug's.
        #expect(claims.build == "1.2.0 (21)")
        #expect(state.folder == folder.path(percentEncoded: false))

        let claim = InAppEventLinkClaim.of("alba://events/new-year-2027", in: state)
        #expect(claim == .claimed("alba://"))
        #expect(claim.message(appName: "Alba") == "alba:// is Alba’s, but Atlas can’t tell whether it opens this event.")
        #expect(!claim.blocksSubmit)
        // A web link needs the domain, which isn't declared.
        #expect(InAppEventLinkClaim.of("https://alba.app/events/new-year-2027", in: state) == .notClaimed("alba.app"))
    }

    @Test func aDeclaredDomainIsClaimed() throws {
        var settings = Self.albaSettings
        settings["CODE_SIGN_ENTITLEMENTS"] = "$(TARGET_NAME)/SupportFiles/$(TARGET_NAME).entitlements"
        let folder = try Self.folder(
            targets: [(name: "Alba", type: Self.app, settings: settings)],
            files: [
                Self.infoPath: ["CFBundleDisplayName": "Alba"],
                Self.entitlementsPath: ["com.apple.developer.associated-domains": [
                    "applinks:Alba.app?mode=developer", "webcredentials:alba.app", "applinks:*.alba.events",
                ]],
            ]
        )
        let state = ProjectLinkClaimsReader.read(folder: folder, bundleID: "com.lima.alba")
        let claims = try Self.claims(state)
        #expect(claims.domains == ["alba.app", "*.alba.events"])
        #expect(claims.schemes.isEmpty)
        #expect(InAppEventLinkClaim.of("https://ALBA.app/events/holidays-2026", in: state) == .claimed("alba.app"))
        #expect(InAppEventLinkClaim.of("https://go.alba.events/holidays", in: state) == .claimed("go.alba.events"))
        #expect(InAppEventLinkClaim.of("https://alba.events/holidays", in: state) == .claimed("alba.events"))
        let other = InAppEventLinkClaim.of("https://example.com/holidays", in: state)
        #expect(other == .notClaimed("example.com"))
        #expect(other.message(appName: "Alba") == "Alba doesn’t open links to example.com yet")
        #expect(other.detail?.contains("applinks:example.com") == true)
    }

    /// Alba 1.2.0: an Info.plist with no URL Types, entitlements without
    /// Associated Domains. Its alba:// links open nothing.
    @Test func nothingDeclaredClaimsNothing() throws {
        let folder = try Self.folder(
            targets: [
                (name: "Alba", type: Self.app, settings: Self.albaSettings),
                (name: "AlbaWidgetExtension", type: "com.apple.product-type.app-extension", settings: [
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.lima.alba.widget", "INFOPLIST_FILE": "Widget/Info.plist",
                ]),
            ],
            files: [
                Self.infoPath: ["UIBackgroundModes": ["remote-notification"]],
                Self.entitlementsPath: ["aps-environment": "development"],
                "Widget/Info.plist": Self.urlTypes(["albawidget"]),
            ]
        )
        let state = ProjectLinkClaimsReader.read(folder: folder, bundleID: "com.lima.alba")
        let claims = try Self.claims(state)
        // The widget's scheme isn't the app's.
        #expect(claims.schemes.isEmpty)
        #expect(claims.targets == ["Alba"])
        let claim = InAppEventLinkClaim.of("alba://events/gratitude-week-2026", in: state)
        #expect(claim == .notClaimed("alba://"))
        #expect(claim.message(appName: "Alba") == "Alba doesn’t open alba:// links yet")
        #expect(claim.blocksSubmit)
        #expect(claim.detail?.contains("URL scheme “alba”") == true)
    }

    /// `GENERATE_INFOPLIST_FILE` with no Info.plist file: build settings
    /// can't declare URL Types, so there are none. With a file, its
    /// schemes are filled in from build settings.
    @Test func aGeneratedInfoPlistIsReadThroughBuildSettings() throws {
        var generated = Self.albaSettings
        generated["INFOPLIST_FILE"] = nil
        generated["CODE_SIGN_ENTITLEMENTS"] = nil
        generated["INFOPLIST_KEY_CFBundleDisplayName"] = "Alba"
        let bare = try Self.folder(targets: [(name: "Alba", type: Self.app, settings: generated)])
        let bareClaims = try Self.claims(ProjectLinkClaimsReader.read(folder: bare, bundleID: "com.lima.alba"))
        #expect(bareClaims.schemes.isEmpty)
        #expect(bareClaims.domains.isEmpty)

        var expanded = Self.albaSettings
        expanded["INFOPLIST_FILE"] = "$(SRCROOT)/$(TARGET_NAME)/SupportFiles/Info.plist"
        expanded["APP_SCHEME"] = "$(PRODUCT_NAME:lower)"
        let folder = try Self.folder(
            targets: [(name: "Alba", type: Self.app, settings: expanded)],
            files: [Self.infoPath: Self.urlTypes(["$(APP_SCHEME)", "$(PRODUCT_BUNDLE_IDENTIFIER)"])], projectFolder: "ios"
        )
        // The project is one folder down.
        let claims = try Self.claims(ProjectLinkClaimsReader.read(folder: folder, bundleID: "com.lima.alba"))
        #expect(claims.schemes == ["alba", "com.lima.alba"])
    }

    @Test func theTargetThatBuildsTheAppIsChosen() throws {
        let folder = try Self.folder(
            targets: [
                (name: "AlbaBeta", type: Self.app, settings: ["PRODUCT_BUNDLE_IDENTIFIER": "com.lima.alba.beta", "INFOPLIST_FILE": "Beta/Info.plist"]),
                (name: "Alba", type: Self.app, settings: Self.albaSettings),
            ],
            files: [Self.infoPath: Self.urlTypes(["alba"]), "Beta/Info.plist": Self.urlTypes(["albabeta"])]
        )
        let claims = try Self.claims(ProjectLinkClaimsReader.read(folder: folder, bundleID: "COM.lima.alba"))
        #expect(claims.targets == ["Alba"])
        #expect(claims.schemes == ["alba"])
        // No bundle ID to match: every iOS app target counts.
        let all = try Self.claims(ProjectLinkClaimsReader.read(folder: folder, bundleID: nil))
        #expect(all.schemes == ["alba", "albabeta"])
    }

    @Test func aFolderWithoutAProjectSaysSo() throws {
        let empty = FileManager.default.temporaryDirectory.appending(path: "ProjectLinkClaims-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let state = ProjectLinkClaimsReader.read(folder: empty, bundleID: "com.lima.alba")
        #expect(state == .unreadable(folder: empty.path(percentEncoded: false), reason: "Atlas found no Xcode project in the project folder."))
        let claim = InAppEventLinkClaim.of("alba://events", in: state)
        #expect(claim.needsFolder)
        #expect(claim.message(appName: "Alba") == "Atlas can’t tell whether Alba opens this link. Atlas found no Xcode project in the project folder.")

        let gone = ProjectLinkClaimsReader.read(folder: empty.appending(path: "missing"), bundleID: nil)
        guard case let .unreadable(_, reason) = gone else { Issue.record("expected unreadable"); return }
        #expect(reason == "Atlas can’t open the project folder. Choose it again.")
    }

    @Test func noFolderOrNoDeepLinkSaysWhatToDo() {
        let noFolder = InAppEventLinkClaim.of("alba://events", in: .noFolder)
        #expect(noFolder == .noFolder)
        #expect(noFolder.needsFolder)
        #expect(noFolder.message(appName: "Alba")?.contains("Choose Alba’s project folder") == true)
        #expect(InAppEventLinkClaim.of(nil, in: .noFolder) == .noDeepLink)
        #expect(InAppEventLinkClaim.of("not a link", in: .noFolder) == .noDeepLink)
        #expect(InAppEventLinkClaim.of("alba://events", in: .unknown) == .reading)
        #expect(InAppEventLinkClaim.of("alba://events", in: .unknown).message(appName: "Alba") == nil)
    }

    @Test func buildSettingsAreFilledIn() {
        let settings = ["PRODUCT_NAME": "Alba Daily", "TARGET_NAME": "Alba", "BASE": "$(TARGET_NAME)/x"]
        #expect(XcodeProjectFile.expand("$(PRODUCT_NAME:rfc1034identifier)", settings: settings) == "Alba-Daily")
        #expect(XcodeProjectFile.expand("${TARGET_NAME:lower}", settings: settings) == "alba")
        #expect(XcodeProjectFile.expand("$(inherited) $(BASE)", settings: settings) == "Alba/x")
        #expect(XcodeProjectFile.expand("$(UNKNOWN)alba", settings: settings) == "alba")
    }
}
