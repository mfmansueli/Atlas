//
//  EncryptionKeyProjectReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The key read by Atlas itself from fixture folders shaped like a real
/// project (`Lumen.xcodeproj` with an old-style `project.pbxproj` and an
/// Info.plist): as a generated Info.plist's build setting, in the
/// Info.plist, missing, and in another app's target only.
@Suite("Encryption key in the project")
struct EncryptionKeyProjectReaderTests {
    private static let app = "com.apple.product-type.application"
    private static let infoPath = "Lumen/Info.plist"

    private static func folder(targets: [(name: String, settings: [String: String])], files: [String: Any] = [:]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "EncryptionKeyProject-\(UUID().uuidString)")
        let project = root.appending(path: "Lumen.xcodeproj")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try pbxproj(targets).write(to: project.appending(path: "project.pbxproj"), atomically: true, encoding: .utf8)
        for (path, plist) in files {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url)
        }
        return root
    }

    private static func pbxproj(_ targets: [(name: String, settings: [String: String])]) -> String {
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
                "T\(index) = { isa = PBXNativeTarget; name = \(target.name); productType = \"\(app)\"; buildConfigurationList = TL\(index); };",
                "TL\(index) = { isa = XCConfigurationList; buildConfigurations = ( TR\(index) ); };",
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

    @Test func aGeneratedInfoPlistsBuildSettingIsRead() throws {
        let folder = try Self.folder(targets: [(name: "Lumen", settings: [
            "PRODUCT_BUNDLE_IDENTIFIER": "dev.example.lumen", "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
        ])])
        let key = try #require(EncryptionKeyProjectReader.read(folder: folder, bundleID: "dev.example.lumen").key)
        #expect(key.value == .no)
        #expect(key.isBuildSetting)
        #expect(key.target == "Lumen")
        #expect(key.whereText == "Lumen’s build settings")
    }

    @Test func theInfoPlistsKeyAndCodeAreRead() throws {
        let folder = try Self.folder(
            targets: [(name: "Lumen", settings: ["PRODUCT_BUNDLE_IDENTIFIER": "dev.example.lumen", "INFOPLIST_FILE": Self.infoPath])],
            files: [Self.infoPath: ["ITSAppUsesNonExemptEncryption": true, "ITSEncryptionExportComplianceCode": "a1b2c3"]]
        )
        let key = try #require(EncryptionKeyProjectReader.read(folder: folder, bundleID: "dev.example.lumen").key)
        #expect(key.value == .yes)
        #expect(key.code == "a1b2c3")
        #expect(!key.isBuildSetting)
        #expect(key.whereText == "Lumen/Info.plist (Lumen)")
    }

    @Test func aTargetWithoutTheKeyIsNotFound() throws {
        let folder = try Self.folder(
            targets: [(name: "Lumen", settings: ["PRODUCT_BUNDLE_IDENTIFIER": "dev.example.lumen", "INFOPLIST_FILE": Self.infoPath])],
            files: [Self.infoPath: ["CFBundleDisplayName": "Lumen"]]
        )
        #expect(EncryptionKeyProjectReader.read(folder: folder, bundleID: "dev.example.lumen") == .notFound(targets: ["Lumen"]))
    }

    @Test func onlyTheTargetBuildingTheAppCounts() throws {
        let folder = try Self.folder(targets: [
            (name: "Other", settings: ["PRODUCT_BUNDLE_IDENTIFIER": "dev.example.other", "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO"]),
            (name: "Lumen", settings: ["PRODUCT_BUNDLE_IDENTIFIER": "dev.example.lumen"]),
        ])
        #expect(EncryptionKeyProjectReader.read(folder: folder, bundleID: "dev.example.lumen") == .notFound(targets: ["Lumen"]))
        if case .unreadable = EncryptionKeyProjectReader.read(folder: folder, bundleID: "dev.example.missing") {} else {
            Issue.record("Two app targets, neither building the bundle ID: Atlas can't tell")
        }
    }

    @MainActor
    @Test func aPinnedStateIsKeptForScenesAndTests() {
        let center = EncryptionKeyProjectCenter()
        center.pin(.noFolder, for: "1")
        #expect(center.state(for: "1") == .noFolder)
        #expect(center.state(for: "2") == .unknown)
    }
}
