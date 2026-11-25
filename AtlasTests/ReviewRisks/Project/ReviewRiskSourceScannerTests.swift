//
//  ReviewRiskSourceScannerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `ReviewRiskSourceScanner`: imports, permission APIs and account signals
/// read from Swift lines, with comments left out.
@Suite("Review risks · reading Swift code")
struct ReviewRiskSourceScannerTests {
    private typealias Fixtures = ReviewRiskProjectFixtures

    @Test func importsAreReadInEveryFormButNotFromComments() {
        let project = Fixtures.scanned("""
        import SwiftUI
        @preconcurrency import FirebaseAuth
        import struct Foundation.URL
        // import OpenAI
        /* import Anthropic */
        """)
        #expect(project.imports == ["SwiftUI", "FirebaseAuth", "Foundation"])
    }

    @Test func aCameraRequestIsFoundAtItsLine() {
        let project = Fixtures.scanned("""
        let session = AVCaptureSession()
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        """)
        #expect(project.uses(.camera).map(\.place) == ["Lumen/Source.swift:2"])
        #expect(project.uses(.microphone).isEmpty)
    }

    @Test func pickersThatNeedNoPermissionAreNotUses() {
        let project = Fixtures.scanned("""
        PhotosPicker(selection: $item) { Text("Pick") }
        let picker = PHPickerViewController(configuration: configuration)
        let contacts = CNContactPickerViewController()
        """)
        #expect(project.permissionUses.isEmpty)
    }

    @Test func commentedOutCodeIsNotAUse() {
        let project = Fixtures.scanned("""
        // manager.requestWhenInUseAuthorization()
        /* manager.requestWhenInUseAuthorization()
           let central = CBCentralManager(delegate: nil, queue: nil) */
        let ready = true
        """)
        #expect(project.uses(.location).isEmpty)
        #expect(project.uses(.bluetooth).isEmpty)
    }

    @Test func healthReadsWithoutWritingAndPhotosAddOnly() {
        let project = Fixtures.scanned("""
        store.requestAuthorization(toShare: nil, read: types) { _, _ in }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        """)
        #expect(project.uses(.healthRead).count == 1)
        #expect(project.uses(.healthWrite).isEmpty)
        #expect(project.uses(.photosAdd).count == 1)
        #expect(project.uses(.photos).isEmpty)
    }

    @Test func signUpIsFoundOncePerLine() {
        let project = Fixtures.scanned("""
        struct SignUpView: View {
            func createAccount() async throws {
                try await Auth.auth().createUser(withEmail: email, password: password)
            }
        }
        """)
        #expect(project.matches(.signUp).map(\.line) == [1, 2, 3])
        #expect(project.matches(.signUp)[2].excerpt == "try await Auth.auth().createUser(withEmail: email, password: password)")
    }

    @Test func deleteAccountIsFoundInATextAndACall() {
        let project = Fixtures.scanned("""
        Button("Delete Account", role: .destructive) { confirming = true }
        try await Auth.auth().currentUser?.delete()
        """)
        #expect(project.matches(.accountDeletion).map(\.line) == [1, 2])
    }

    @Test func removingSettingsOrAPictureIsNotDeletingTheAccount() {
        let project = Fixtures.scanned("""
        UserDefaults.standard.removeObject(forKey: "token")
        removeUserDefaults()
        deleteProfileImage()
        """)
        #expect(project.matches(.accountDeletion).isEmpty)
    }

    @Test func googleSignInAndSignInWithAppleAreTold() {
        let project = Fixtures.scanned("""
        import GoogleSignIn
        GIDSignIn.sharedInstance.signIn(withPresenting: root)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        try await Auth.auth().revokeToken(withAuthorizationCode: code)
        """)
        #expect(project.matches(.thirdPartyLogin).map(\.line) == [1, 2])
        #expect(project.matches(.thirdPartyLogin).allSatisfy { $0.what == "Google Sign-In" })
        #expect(project.matches(.appleSignIn).map(\.what) == ["Sign in with Apple"])
        #expect(project.matches(.appleTokenRevoke).count == 1)
        #expect(project.matches(.signIn).isEmpty)
    }

    @Test func facebookAnalyticsAloneIsNotASignIn() {
        let project = Fixtures.scanned("""
        import FacebookCore
        AppEvents.shared.logEvent(.completedRegistration)
        """)
        #expect(project.matches(.thirdPartyLogin).isEmpty)
        #expect(project.imports == ["FacebookCore"])
    }

    @Test func codeLinesKeepStringsAndLineCount() {
        let lines = ReviewRiskSourceScanner.codeLines("let a = \"http://x\" // note\n/* one\ntwo */ let b = 1")
        #expect(lines == ["let a = \"http://x\" ", "", " let b = 1"])
    }
}
