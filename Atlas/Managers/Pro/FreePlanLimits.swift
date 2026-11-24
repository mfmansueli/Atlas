//
//  FreePlanLimits.swift
//  Atlas
//

import Foundation

/// What Free's screenshot editor has (README — Monetization): the first
/// `Entitlements.freeTemplateLimit` templates of the gallery, the simple
/// ones, on iPhone and iPad. Every other template, and templates on iPhone
/// Duo, Mac, Apple Watch and Apple Vision Pro, are Pro's. A template a
/// person already uses is never locked, and screenshots made by hand stay
/// free on every device.
enum FreePlanLimits {
    /// Above, Band and Panorama.
    static let templates: [TemplateStarter] = Array(TemplateStarter.simple.prefix(Entitlements.freeTemplateLimit))

    /// The devices Free's templates lay out.
    static let displays: [ScreenshotDisplayType] = [.iPhone, .iPad]

    static func includes(_ starter: TemplateStarter) -> Bool {
        templates.contains(starter)
    }

    static func includes(_ display: ScreenshotDisplayType) -> Bool {
        displays.contains(display)
    }
}
