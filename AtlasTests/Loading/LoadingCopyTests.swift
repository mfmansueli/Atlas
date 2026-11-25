//
//  LoadingCopyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// README-DS §9's loading template: the line says what loads ("Reading 6
/// apps from Apple…"), never a bare "Loading…", in six words at most;
/// VoiceOver reads "Loading <what>" once per skeleton.
@Suite("Loading copy")
struct LoadingCopyTests {
    private let messages = LoadingCopy.all(sampleAppName: "Lumen")

    @Test func everyLineFitsTheTemplate() {
        for message in messages {
            #expect(message.followsCopyRules, "\(message.line ?? message.spoken)")
            #expect(message.lineWordCount <= LoadingMessage.maximumLineWords, "\(message.line ?? "")")
        }
    }

    @Test func noLineIsABareLoading() {
        for message in messages {
            guard let line = message.line else { continue }
            #expect(!line.hasPrefix("Loading"), "\(line)")
            #expect(line != "Loading…")
            #expect(line.hasSuffix("…"), "\(line)")
        }
    }

    @Test func voiceOverSaysWhatIsLoading() {
        for message in messages {
            #expect(message.spoken.hasPrefix("Loading ") || message.spoken.hasPrefix("Checking "), "\(message.spoken)")
            #expect(LoadingMessage.wordCount(message.spoken) >= 2, "\(message.spoken)")
            #expect(!message.spoken.hasSuffix("…"), "VoiceOver doesn't read an ellipsis: \(message.spoken)")
        }
    }

    @Test func noBannedWords() {
        let banned = ["simply", "just", "easily", "seamlessly", "powerful", "leverage", "magic", "please", "oops", "successfully", "!"]
        for message in messages {
            let text = ((message.line ?? "") + " " + message.spoken).lowercased()
            for word in banned {
                #expect(!text.contains(word), "\(word) in \(text)")
            }
        }
    }

    @Test func linesNameTheApp() {
        #expect(LoadingCopy.productPages(appName: "Lumen").line == "Reading Lumen’s product pages…")
        #expect(LoadingCopy.analytics(appName: "Lumen").line == "Downloading Apple’s reports for Lumen…")
    }

    @Test func wordsAreCountedByWhitespace() {
        #expect(LoadingMessage.wordCount("Reading 6 apps from Apple…") == 5)
        #expect(LoadingMessage.wordCount("  Reading   apps ") == 2)
        #expect(LoadingMessage.wordCount("") == 0)
    }

    @Test func templateRefusesWhatREADMEDSBans() {
        #expect(!LoadingMessage(spoken: "Loading the apps", line: "Loading…").followsCopyRules)
        #expect(!LoadingMessage(spoken: "Loading the apps", line: "Reading every one of your apps from Apple…").followsCopyRules)
        #expect(!LoadingMessage(spoken: "Loading the apps", line: "Reading apps from Apple").followsCopyRules)
        #expect(!LoadingMessage(spoken: "", line: nil).followsCopyRules)
        #expect(LoadingMessage(spoken: "Loading the apps", line: "Reading 6 apps from Apple…").followsCopyRules)
        #expect(LoadingMessage(spoken: "Loading the apps").followsCopyRules)
    }
}
