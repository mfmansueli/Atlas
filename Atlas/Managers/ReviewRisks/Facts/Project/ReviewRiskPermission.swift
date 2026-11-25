//
//  ReviewRiskPermission.swift
//  Atlas
//

import Foundation

/// A permission the app's code asks for, and the Info.plist keys (purpose
/// strings) that explain it. Without one, iOS stops the app when it asks and
/// App Store Connect turns the build away (ITMS-90683).
enum ReviewRiskPermission: String, CaseIterable, Codable, Hashable, Sendable {
    case camera
    case microphone
    case location
    case locationAlways
    case photos
    case photosAdd
    case contacts
    case calendars
    case calendarsWriteOnly
    case reminders
    case healthRead
    case healthWrite
    case bluetooth
    case tracking
    case speech
    case nfc
    case faceID
    case motion
    case homeKit
    case mediaLibrary

    /// The keys that cover it, the one to add first: any of them is enough.
    var keys: [String] {
        switch self {
        case .camera: ["NSCameraUsageDescription"]
        case .microphone: ["NSMicrophoneUsageDescription"]
        case .location: ["NSLocationWhenInUseUsageDescription"]
        case .locationAlways: ["NSLocationAlwaysAndWhenInUseUsageDescription"]
        case .photos: ["NSPhotoLibraryUsageDescription"]
        case .photosAdd: ["NSPhotoLibraryAddUsageDescription", "NSPhotoLibraryUsageDescription"]
        case .contacts: ["NSContactsUsageDescription"]
        case .calendars: ["NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription"]
        case .calendarsWriteOnly:
            ["NSCalendarsWriteOnlyAccessUsageDescription", "NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription"]
        case .reminders: ["NSRemindersFullAccessUsageDescription", "NSRemindersUsageDescription"]
        case .healthRead: ["NSHealthShareUsageDescription"]
        case .healthWrite: ["NSHealthUpdateUsageDescription"]
        case .bluetooth: ["NSBluetoothAlwaysUsageDescription"]
        case .tracking: ["NSUserTrackingUsageDescription"]
        case .speech: ["NSSpeechRecognitionUsageDescription"]
        case .nfc: ["NFCReaderUsageDescription"]
        case .faceID: ["NSFaceIDUsageDescription"]
        case .motion: ["NSMotionUsageDescription"]
        case .homeKit: ["NSHomeKitUsageDescription"]
        case .mediaLibrary: ["NSAppleMusicUsageDescription"]
        }
    }

    /// The permission a key explains, for naming a purpose string.
    static func permission(forKey key: String) -> ReviewRiskPermission? {
        allCases.first { $0.keys.first == key } ?? allCases.first { $0.keys.contains(key) }
    }

    /// Whether `key` is a purpose string: `NS…UsageDescription` or NFC's.
    static func isPurposeKey(_ key: String) -> Bool {
        (key.hasPrefix("NS") && key.hasSuffix("UsageDescription")) || key == "NFCReaderUsageDescription"
    }

    /// How serious a missing text is: iOS stops the app for every one but
    /// Face ID, which only fails to prompt.
    var missingLevel: ReviewRiskLevel {
        self == .faceID ? .likely : .blocksReview
    }

    /// Its name in a title: "Camera".
    var name: String {
        switch self {
        case .camera: String(localized: "Camera", comment: "kind:label · a permission the app asks for")
        case .microphone: String(localized: "Microphone", comment: "kind:label · a permission the app asks for")
        case .location: String(localized: "Location", comment: "kind:label · a permission the app asks for")
        case .locationAlways: String(localized: "Location always", comment: "kind:label · a permission the app asks for, in the background too")
        case .photos: String(localized: "Photos", comment: "kind:label · a permission the app asks for")
        case .photosAdd: String(localized: "Saving photos", comment: "kind:label · a permission the app asks for")
        case .contacts: String(localized: "Contacts", comment: "kind:label · a permission the app asks for")
        case .calendars, .calendarsWriteOnly: String(localized: "Calendars", comment: "kind:label · a permission the app asks for")
        case .reminders: String(localized: "Reminders", comment: "kind:label · a permission the app asks for")
        case .healthRead: String(localized: "Health data", comment: "kind:label · a permission the app asks for, to read")
        case .healthWrite: String(localized: "Health updates", comment: "kind:label · a permission the app asks for, to write")
        case .bluetooth: String(localized: "Bluetooth", comment: "kind:label · a permission the app asks for")
        case .tracking: String(localized: "Tracking", comment: "kind:label · App Tracking Transparency's permission")
        case .speech: String(localized: "Speech recognition", comment: "kind:label · a permission the app asks for")
        case .nfc: String(localized: "NFC", comment: "kind:label · a permission the app asks for")
        case .faceID: String(localized: "Face ID", comment: "kind:label · a permission the app asks for")
        case .motion: String(localized: "Motion", comment: "kind:label · a permission the app asks for")
        case .homeKit: String(localized: "Home", comment: "kind:label · HomeKit's permission")
        case .mediaLibrary: String(localized: "Media library", comment: "kind:label · a permission the app asks for")
        }
    }
}
