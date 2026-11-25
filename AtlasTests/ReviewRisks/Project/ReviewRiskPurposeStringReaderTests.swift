//
//  ReviewRiskPurposeStringReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `ReviewRiskPurposeStringReader`: permission texts from build settings and
/// Info.plist files, their translations, and the project's regions.
@Suite("Review risks · reading permission texts")
struct ReviewRiskPurposeStringReaderTests {
    @Test func buildSettingsGiveQuotedAndBareTextsOncePerKey() {
        let pbxproj = #"""
        				INFOPLIST_KEY_NSCameraUsageDescription = "Scans receipts so you can file \"expenses\".";
        				INFOPLIST_KEY_NSMicrophoneUsageDescription = Microphone;
        				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
        				INFOPLIST_KEY_NSCameraUsageDescription = "";
        """#
        let purposes = ReviewRiskPurposeStringReader.buildSettings(pbxproj, file: "Lumen.xcodeproj/project.pbxproj")
        #expect(purposes.map(\.key) == ["NSCameraUsageDescription", "NSMicrophoneUsageDescription"])
        #expect(purposes.first?.value == "Scans receipts so you can file \"expenses\".")
        #expect(purposes.first?.place == "Lumen.xcodeproj/project.pbxproj:1")
        #expect(purposes.last?.value == "Microphone")
        #expect(purposes.last?.place == "Lumen.xcodeproj/project.pbxproj:2")
    }

    @Test func infoPlistGivesOnlyPurposeKeysAtTheirLine() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        	<key>CFBundleName</key>
        	<string>Lumen</string>
        	<key>NSLocationWhenInUseUsageDescription</key>
        	<string>Shows journal entries written near you.</string>
        	<key>NFCReaderUsageDescription</key>
        	<string>Reads tags</string>
        </dict>
        </plist>
        """
        let purposes = ReviewRiskPurposeStringReader.infoPlist(Data(plist.utf8), file: "Lumen/Info.plist")
        #expect(purposes.map(\.key) == ["NFCReaderUsageDescription", "NSLocationWhenInUseUsageDescription"])
        #expect(purposes.last?.place == "Lumen/Info.plist:7")
        #expect(purposes.last?.value == "Shows journal entries written near you.")
    }

    @Test func aStringCatalogGivesTranslatedLanguagesOnly() {
        let catalog = """
        {"sourceLanguage":"en","strings":{
          "NSCameraUsageDescription":{"localizations":{
            "de":{"stringUnit":{"state":"translated","value":"Scannt Belege."}},
            "pt-BR":{"stringUnit":{"state":"translated","value":"Lê recibos."}},
            "fr":{"stringUnit":{"state":"new","value":""}}
          }},
          "CFBundleName":{}
        },"version":"1.0"}
        """
        let read = ReviewRiskPurposeStringReader.stringCatalog(Data(catalog.utf8))
        #expect(read.keys["NSCameraUsageDescription"] == ["de", "pt"])
        #expect(read.keys["CFBundleName"] == [])
        #expect(read.languages == ["en", "de", "pt"])
        #expect(read.source == "en")
    }

    @Test func aStringsFileGivesKeysWithAValue() {
        let strings = """
        /* Camera */
        "NSCameraUsageDescription" = "Scanne des reçus.";
        "NSMicrophoneUsageDescription" = "";
        """
        #expect(ReviewRiskPurposeStringReader.stringsFile(Data(strings.utf8)) == ["NSCameraUsageDescription"])
    }

    @Test func regionsLeaveBaseOut() {
        let pbxproj = """
        			developmentRegion = en;
        			hasScannedForEncodings = 0;
        			knownRegions = (
        				en,
        				Base,
        				de,
        				"pt-BR",
        				"zh-Hans",
        			);
        """
        let regions = ReviewRiskPurposeStringReader.regions(pbxproj)
        #expect(regions.development == "en")
        #expect(regions.known == ["en", "de", "pt", "zh-hans"])
    }

    @Test func languageCodesMeetInOneForm() {
        #expect(ReviewRiskLanguageCode.base("de-DE") == "de")
        #expect(ReviewRiskLanguageCode.base("pt_BR") == "pt")
        #expect(ReviewRiskLanguageCode.base("zh-Hant") == "zh-hant")
        #expect(ReviewRiskLanguageCode.base("zh-TW") == "zh-hant")
        #expect(ReviewRiskLanguageCode.base("zh") == "zh-hans")
        #expect(ReviewRiskLanguageCode.base("no") == ReviewRiskLanguageCode.base("nb"))
    }
}
