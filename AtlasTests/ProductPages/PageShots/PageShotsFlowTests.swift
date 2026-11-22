//
//  PageShotsFlowTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Make Screenshots for This Page… from Private diary's editor (board 52):
/// the run starts with the page's note and languages and asks Claude Code
/// for the plan (or copies the prompt); Use These Screenshots puts one
/// change per language and device in Review & Push, in place of the
/// page's earlier ones, and the editor shows them as the page's own.
@MainActor
@Suite("Page screenshots flow")
struct PageShotsFlowTests {
    typealias Test = PageShotsTestFixtures

    private func flow(queue: ChangeQueue = ChangeQueue(changes: DebugProductPagesData.pendingChanges)) async throws -> (PageShotsFlow, ProductPagesViewModel) {
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, Test.pageID)
        let flow = PageShotsFlow(
            app: Test.app, page: page, studio: PageShotsStudio(), queue: queue, screenshots: DebugScreenshotsServices(),
            languages: model.pageShotsLanguages, ownLocales: page.locales, note: model.pageShotsNote(of: page)
        )
        return (flow, model)
    }

    @Test func makeScreenshotsAsksClaudeForThePlanWithThePagesNote() async throws {
        let (flow, model) = try await flow()
        var asked: [(purpose: ClaudeCodeRunPurpose, prompt: String)] = []
        let id = UUID()
        flow.launch = { purpose, prompt in
            asked.append((purpose, prompt))
            return id
        }
        await flow.open()

        let run = try #require(flow.run)
        #expect(run.stage == .planning)
        #expect(run.claudeRunID == id)
        #expect(run.note == DebugProductPagesData.privateDiary.note)
        #expect(run.languages == model.pageShotsLanguages)
        #expect(run.locales == ["en-US", "de-DE", "ja", "ar-SA"])
        #expect(run.displays == [.iPhone, .iPad])
        #expect(flow.studio.presentedKey == flow.key)
        #expect(asked.count == 1)
        #expect(asked.first?.purpose == .pageScreenshots(pageName: "Private diary"))
        #expect(asked.first?.prompt.contains("get_page_screenshots") == true)
        #expect(asked.first?.prompt.contains("Private diary") == true)
        #expect(!flow.canStart)

        // Opening it again shows the same run.
        await flow.open()
        #expect(asked.count == 1)
        #expect(flow.run?.id == run.id)
    }

    @Test func withoutClaudeCodeThePromptIsCopied() async throws {
        let (flow, _) = try await flow()
        var copied: String?
        flow.copy = { copied = $0 }
        await flow.open()
        #expect(flow.copiedPrompt != nil)
        #expect(copied == flow.copiedPrompt)
        #expect(flow.run?.claudeRunID == nil)
    }

    @Test func useTheseScreenshotsQueuesEachLanguageAndDeviceInPlaceOfTheEarlierOnes() async throws {
        let queue = ChangeQueue(changes: DebugProductPagesData.pendingChanges)
        let (flow, model) = try await flow(queue: queue)
        var toasts: [ToastMessage] = []
        flow.onToast = { toasts.append($0) }
        flow.studio.begin(Test.run(plan: Test.plan(count: 2), locales: ["en-US", "de-DE"], displays: [.iPhone, .iPad]))
        await flow.loadSource()
        flow.startAutopilot()
        await flow.studio.waitUntilMade(flow.key)
        #expect(flow.run?.stage == .result)
        #expect(flow.usedCount == 8)

        flow.use()
        let builder = ProductPageChangeBuilder(appID: Test.app.id)
        var queued = builder.screenshotChanges(pageID: Test.pageID, pageName: Test.pageName, in: queue.changes)
        #expect(queued.count == 4)
        #expect(Set(queued.map(\.id)) == Set(["en-US", "de-DE"].flatMap { locale in
            [ScreenshotDisplayType.iPhone, .iPad].map { builder.screenshotsChangeID(pageID: Test.pageID, locale: locale, displayType: $0) }
        }))
        #expect(queued.allSatisfy { $0.blockedReason == nil && $0.oldValue == "The default page’s screenshots" })
        #expect(flow.run?.stage == .used)
        #expect(flow.studio.presentedKey == nil)
        #expect(toasts.last?.text == "8 screenshots added to “Private diary”. They’re waiting in Review & Push, top right.")
        #expect(toasts.last?.actionTitle == "Review & Push")

        let files = try #require(model.queuedScreenshots(of: flow.page, locale: "de-DE", device: .iPad))
        #expect(files.count == 2)
        #expect(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        #expect(model.hasQueuedScreenshots(flow.page))
        #expect(builder.edits(for: Test.pageID, in: queue.changes).screenshots["en-US"]?[.iPhone] == model.queuedScreenshots(
            of: flow.page, locale: "en-US", device: .iPhone
        ))

        // Made again and used in English only: German's changes go.
        flow.studio.update(flow.key) { $0.stage = .result }
        flow.toggleUse(locale: "de-DE")
        #expect(flow.usedCount == 4)
        flow.use()
        queued = builder.screenshotChanges(pageID: Test.pageID, pageName: Test.pageName, in: queue.changes)
        #expect(queued.count == 2)
        #expect(model.queuedScreenshots(of: flow.page, locale: "de-DE", device: .iPad) == nil)
    }

    @Test func aDraftsScreenshotsAreFoundByNameOnceItsPushedAndASetHasOneToTen() throws {
        let builder = ProductPageChangeBuilder(appID: Test.app.id)
        let page = try #require(DebugProductPagesData.pages.first { $0.id == DebugProductPagesData.PageID.prompts })
        let file = ProductPageScreenshotsPush.File(path: "/tmp/1.png", fileName: "1.png", fileSize: 10, checksum: "x")
        let change = builder.screenshotsChange([file], locale: "en-US", displayType: .iPhone, of: page, hadOwn: true)
        #expect(change.title == "\(ProductPageChangeBuilder.localeName("en-US")) · Screenshots · iPhone")
        #expect(change.newValue == "1 screenshot for this page")
        #expect(change.oldValue == "The page’s own screenshots")
        #expect(change.restoreRequests.isEmpty)
        #expect(builder.isScreenshotsChange(change))
        #expect(builder.screenshotChanges(pageID: "another-id", pageName: "  PROMPTS ", in: [change]) == [change])
        #expect(builder.screenshotChanges(pageID: "another-id", pageName: "Mood", in: [change]).isEmpty)
        let edits = builder.edits(for: page.id, in: [change])
        #expect(edits.count == 1)
        #expect(edits.screenshots["en-US"]?[.iPhone] == [file])
        #expect(edits.texts.isEmpty)

        let eleven = builder.screenshotsChange(Array(repeating: file, count: 11), locale: "en-US", displayType: .iPhone, of: page, hadOwn: false)
        #expect(eleven.blockedReason == "A set has 1 to 10 screenshots.")
    }
}
