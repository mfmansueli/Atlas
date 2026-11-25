//
//  ReviewRiskPackageReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `ReviewRiskPackageReader`: dependency names from Package.resolved (v1,
/// v2, v3), Podfile.lock and Cartfile.resolved.
@Suite("Review risks · reading dependencies")
struct ReviewRiskPackageReaderTests {
    @Test func packageResolvedVersionsTwoAndThreeGiveIdentityAndRepository() {
        let json = """
        {"originHash":"x","pins":[
          {"identity":"googlesignin-ios","kind":"remoteSourceControl","location":"https://github.com/google/GoogleSignIn-iOS","state":{"version":"7.1.0"}},
          {"identity":"openai","kind":"remoteSourceControl","location":"https://github.com/MacPaw/OpenAI.git","state":{}}
        ],"version":3}
        """
        #expect(ReviewRiskPackageReader.packageResolved(Data(json.utf8)) == ["googlesignin-ios", "openai"])
    }

    @Test func packageResolvedVersionOneGivesPackageAndRepository() {
        let json = """
        {"object":{"pins":[{"package":"Firebase","repositoryURL":"https://github.com/firebase/firebase-ios-sdk.git","state":{}}]},"version":1}
        """
        #expect(ReviewRiskPackageReader.packageResolved(Data(json.utf8)) == ["firebase", "firebase-ios-sdk"])
    }

    @Test func notJSONGivesNothing() {
        #expect(ReviewRiskPackageReader.packageResolved(Data("pins".utf8)).isEmpty)
    }

    @Test func podfileLockGivesPodsAndTheirParents() {
        let lock = """
        PODS:
          - FBSDKCoreKit (16.0.1):
            - FBSDKCoreKit_Basics (= 16.0.1)
          - FBSDKLoginKit (16.0.1):
            - FBSDKCoreKit (= 16.0.1)
          - Firebase/Auth (10.0.0):
            - Firebase/CoreOnly
          - "GoogleUtilities/Environment (7.11.0)":

        DEPENDENCIES:
          - Alamofire
        """
        #expect(ReviewRiskPackageReader.podfileLock(lock) == [
            "fbsdkcorekit", "fbsdkloginkit", "firebase/auth", "firebase", "googleutilities/environment", "googleutilities",
        ])
    }

    @Test func cartfileResolvedGivesRepositoryNames() {
        let cartfile = """
        github "facebook/facebook-ios-sdk" "v16.0.0"
        binary "https://dl.google.com/geosdk/GoogleMaps.json" "7.0.0"
        """
        #expect(ReviewRiskPackageReader.cartfileResolved(cartfile) == ["facebook-ios-sdk", "googlemaps"])
    }

    @Test func repositoryNamesFromEveryKindOfAddress() {
        #expect(ReviewRiskPackageReader.repositoryName("git@github.com:google/GoogleSignIn-iOS.git") == "googlesignin-ios")
        #expect(ReviewRiskPackageReader.repositoryName("https://github.com/supabase/supabase-swift/") == "supabase-swift")
        #expect(ReviewRiskPackageReader.repositoryName("") == nil)
    }
}
