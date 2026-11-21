//
//  PageShotsRun.swift
//  Atlas
//

import Foundation

/// Make Screenshots for This Page (board 52): a set of screenshots made
/// for one custom product page from the default page's own screens, in
/// another order and with other captions, in the languages and on the
/// devices the person picks. It's the page's only: the default page's
/// screenshots, captions and template never change. It outlives the sheet,
/// so a hidden run keeps going. Kept by the page's name, like its brief,
/// so a draft keeps its run once it's in App Store Connect.
struct PageShotsRun: Codable, Hashable, Sendable, Identifiable {
    struct Key: Codable, Hashable, Sendable {
        var appID: StoreApp.ID
        /// `ProductPageBrief.key` of the page's name.
        var page: String

        init(appID: StoreApp.ID, pageName: String) {
            self.appID = appID
            page = ProductPageBrief.key(pageName)
        }
    }

    /// Also the name of the folder its images are in.
    var id: String
    var appID: StoreApp.ID
    /// The page's ID: a draft's until it's pushed.
    var pageID: ProductPage.ID
    var pageName: String
    /// Who the page is for, in the person's or the assistant's words: the
    /// angle is written from it.
    var note: String
    var stage: PageShotsStage
    var plan: PageShotsPlan?
    /// Every language the page is in (the default page's), primary first:
    /// the ones the assistant writes captions in.
    var languages: [String]
    /// The languages that get the page's own images, primary first.
    var locales: [String]
    /// The languages the person changed in Plan: the assistant's next plan
    /// doesn't change them.
    var choseLocales = false
    var displays: [ScreenshotDisplayType]
    /// The template's name, for the Look row.
    var templateName: String
    var images: [PageShotsImage] = []
    /// When Atlas started laying out the set: the time left is read from
    /// how long the first ones took.
    var makingSince: Date?
    /// Where the made set is used (Result), a subset of what was made.
    var usedLocales: [String]?
    var usedDisplays: [ScreenshotDisplayType]?
    /// The Claude Code session Atlas started for the plan or a change.
    var claudeRunID: UUID?
    /// When the assistant was last asked: a plan made after it is its
    /// answer.
    var askedAt: Date?
    /// What the person asked to change (Ask for Changes…).
    var changeRequest: String?
    /// What went wrong or what the assistant left to do, said calmly.
    var problem: String?
    /// The Look: nil is the default page's template.
    var design: PageShotsDesign?
    /// Capture screens again: nil when the person didn't ask.
    var recapture: PageShotsRecapture?
    /// The sheet was hidden while it worked.
    var isHidden = false
    var startedAt: Date
    var updatedAt: Date

    var key: Key { Key(appID: appID, pageName: pageName) }

    var look: PageShotsLook { design?.look ?? .same }

    /// The Claude Code sessions working on the run: the plan's, the looks'
    /// and the captures'.
    var claudeRunIDs: [UUID] {
        [claudeRunID, design?.claudeRunID, recapture?.claudeRunID].compactMap(\.self)
    }

    /// The template the set is laid out with when it isn't the default
    /// page's: a starter sized for the set, or the look chosen of three.
    func lookTemplate(appID: StoreApp.ID, appName: String, slotCount: Int) -> ScreenshotTemplate? {
        switch look {
        case .same: nil
        case let .starter(starter): ScreenshotTemplate.starter(starter, id: appID, title: appName, slotCount: max(slotCount, 1))
        case .claudeDesign: design?.chosen?.template
        }
    }

    var primaryLocale: String { languages.first ?? locales.first ?? "en-US" }

    /// How many screenshots the set has in all.
    var expectedCount: Int {
        (plan?.screens.count ?? 0) * locales.count * displays.count
    }

    func image(locale: String, displayType: ScreenshotDisplayType, position: Int) -> PageShotsImage? {
        images.first { $0.locale == locale && $0.displayType == displayType && $0.position == position }
    }

    /// One language's images on one device, in order.
    func images(locale: String, displayType: ScreenshotDisplayType) -> [PageShotsImage] {
        images.filter { $0.locale == locale && $0.displayType == displayType }.sorted { $0.position < $1.position }
    }

    /// The languages and devices the set goes to, as chosen at Result.
    var useLocales: [String] { usedLocales ?? locales.filter { locale in images.contains { $0.locale == locale } } }

    var useDisplays: [ScreenshotDisplayType] {
        usedDisplays ?? displays.filter { display in images.contains { $0.displayType == display } }
    }

    /// `locales` in the page's order (`languages`), primary first, each
    /// once; ones the page isn't in are left out.
    static func ordered(_ locales: [String], by languages: [String]) -> [String] {
        languages.filter(locales.contains)
    }

    /// The screenshots Use These Screenshots puts in Review & Push.
    var usedImages: [PageShotsImage] {
        images.filter { useLocales.contains($0.locale) && useDisplays.contains($0.displayType) }
    }
}
