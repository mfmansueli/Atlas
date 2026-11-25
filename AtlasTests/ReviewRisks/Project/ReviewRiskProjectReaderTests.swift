//
//  ReviewRiskProjectReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `ReviewRiskProjectReader` on a small project folder: what it reads, and
/// what it leaves out (Pods, test targets).
@Suite("Review risks · reading a project folder")
struct ReviewRiskProjectReaderTests {
    private typealias Fixtures = ReviewRiskProjectFixtures

    private func makeProject() throws -> URL {
        let folder = try Fixtures.temporaryFolder()
        try Fixtures.write("""
        // !$*UTF8*$!
        {
        	objects = {
        		B1 = {
        			buildSettings = {
        				INFOPLIST_KEY_NSCameraUsageDescription = "Scans receipts so you can file expenses.";
        			};
        		};
        		P1 = {
        			developmentRegion = en;
        			knownRegions = (
        				en,
        				Base,
        				de,
        			);
        		};
        	};
        }
        """, to: "Lumen.xcodeproj/project.pbxproj", in: folder)
        try Fixtures.write("""
        {"pins":[{"identity":"googlesignin-ios","kind":"remoteSourceControl","location":"https://github.com/google/GoogleSignIn-iOS","state":{}}],"version":2}
        """, to: "Lumen.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved", in: folder)
        try Fixtures.write("""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
        	<key>NSLocationWhenInUseUsageDescription</key>
        	<string>Shows journal entries written near you.</string>
        </dict>
        </plist>
        """, to: "Lumen/Info.plist", in: folder)
        try Fixtures.write("""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
        	<key>com.apple.developer.applesignin</key>
        	<array><string>Default</string></array>
        </dict>
        </plist>
        """, to: "Lumen/Lumen.entitlements", in: folder)
        try Fixtures.write("""
        {"sourceLanguage":"en","strings":{"NSCameraUsageDescription":{"localizations":{
          "de":{"stringUnit":{"state":"translated","value":"Scannt Belege."}}}}},"version":"1.0"}
        """, to: "Lumen/InfoPlist.xcstrings", in: folder)
        try Fixtures.write("""
        "NSCameraUsageDescription" = "Scanne des reçus.";
        """, to: "Lumen/fr.lproj/InfoPlist.strings", in: folder)
        try Fixtures.write("""
        import GoogleSignIn

        func createAccount() async throws {
            try await Auth.auth().createUser(withEmail: email, password: password)
        }
        """, to: "Lumen/Account/SignUpModel.swift", in: folder)
        try Fixtures.write("""
        import FBSDKLoginKit
        let button = FBLoginButton()
        """, to: "Pods/FBSDKLoginKit/Login.swift", in: folder)
        try Fixtures.write("""
        import XCTest
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        """, to: "LumenTests/CameraTests.swift", in: folder)
        try Fixtures.write("""
        PODS:
          - Alamofire (5.8.0)
        """, to: "Podfile.lock", in: folder)
        return folder
    }

    @Test func readsDependenciesImportsAndEntitlements() throws {
        let folder = try makeProject()
        defer { Fixtures.remove(folder) }
        let facts = try #require(ReviewRiskProjectReader.read(folder: folder))
        #expect(facts.folderName == folder.lastPathComponent)
        #expect(facts.packages.isSuperset(of: ["googlesignin-ios", "alamofire"]))
        #expect(facts.imports == ["GoogleSignIn"])
        #expect(facts.entitlements.contains("com.apple.developer.applesignin"))
        #expect(facts.swiftFileCount == 1)
    }

    @Test func readsPermissionTextsAndTheirLanguages() throws {
        let folder = try makeProject()
        defer { Fixtures.remove(folder) }
        let facts = try #require(ReviewRiskProjectReader.read(folder: folder))
        let camera = try #require(facts.purposeStrings["NSCameraUsageDescription"])
        #expect(camera.value == "Scans receipts so you can file expenses.")
        #expect(camera.place == "Lumen.xcodeproj/project.pbxproj:6")
        #expect(camera.languages == ["de", "fr"])
        #expect(facts.purposeStrings["NSLocationWhenInUseUsageDescription"]?.place == "Lumen/Info.plist:4")
        #expect(facts.languages.isSuperset(of: ["en", "de", "fr"]))
        #expect(facts.developmentLanguage == "en")
    }

    @Test func readsTheAppsCodeButNotPodsOrTests() throws {
        let folder = try makeProject()
        defer { Fixtures.remove(folder) }
        let facts = try #require(ReviewRiskProjectReader.read(folder: folder))
        #expect(facts.matches(.signUp).first?.place == "Lumen/Account/SignUpModel.swift:3")
        #expect(facts.matches(.thirdPartyLogin).map(\.what) == ["Google Sign-In"])
        #expect(facts.uses(.camera).isEmpty)
        #expect(!facts.imports.contains("FBSDKLoginKit"))
    }

    @Test func aFolderThatIsntThereReadsAsNothing() {
        let missing = FileManager.default.temporaryDirectory.appending(path: "ReviewRiskProject-missing-\(UUID().uuidString)")
        #expect(ReviewRiskProjectReader.read(folder: missing) == nil)
    }
}
