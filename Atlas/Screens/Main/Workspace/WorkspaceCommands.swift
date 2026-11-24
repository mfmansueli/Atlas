//
//  WorkspaceCommands.swift
//  Atlas
//

import SwiftUI

/// Menu bar commands for the main window: sections (⌘1–⌘9) and Refresh (⌘R)
/// in View, a Product menu with Run Autopilot (⌥⌘A, the toolbar Autopilot
/// button's action), Review & Push (⇧⌘P) and Activity, plus the
/// section-specific commands that work through `WorkspaceIntent`.
struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceNavigator) private var navigator

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(AppWorkspaceSection.allCases) { section in
                Button(section.fullTitle, systemImage: section.systemImage) { navigator?.open(section) }
                    .keyboardShortcut(KeyEquivalent(Character(String(section.shortcutDigit).lowercased())), modifiers: section.shortcutModifiers)
            }
            .disabled(navigator == nil)
            Divider()
            Button("Refresh", systemImage: "arrow.clockwise") { navigator?.refresh() }
                .keyboardShortcut("r")
                .disabled(navigator == nil)
            Divider()
        }
        CommandGroup(after: .textEditing) {
            Button("Find", systemImage: "magnifyingglass") { navigator?.send(.search) }
                .keyboardShortcut("f")
                .disabled(navigator == nil)
            Button("Find and Replace Across Locales…") { navigator?.open(.storePage, intent: .findAndReplace) }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(navigator == nil)
        }
        CommandMenu("Pricing") {
            Group {
                Button("Review Suggestions", systemImage: "sparkles") { navigator?.open(.subscriptionPricing, intent: .reviewSuggestions) }
                Button("Apply Suggested Prices…", systemImage: "checkmark.circle") { navigator?.open(.subscriptionPricing, intent: .applyRecommendedPrices) }
                Button("Schedule Pending Prices…", systemImage: "calendar.badge.clock") {
                    navigator?.open(.subscriptionPricing, intent: .editPriceSchedule(productID: nil))
                }
                Divider()
                Menu("Show Prices As") {
                    ForEach(PricingDisplay.allCases, id: \.self) { display in
                        Button(display.title) { navigator?.open(.subscriptionPricing, intent: .showPrices(display)) }
                    }
                }
                Button("Results", systemImage: "chart.line.uptrend.xyaxis") { navigator?.open(.subscriptionPricing, intent: .showResults) }
            }
            .disabled(navigator == nil)
        }
        CommandMenu("Store Page") {
            Group {
                Button("Translate Missing…", systemImage: "translate") { navigator?.open(.storePage, intent: .translateMissing) }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Import Translations…", systemImage: "square.and.arrow.down") { navigator?.open(.storePage, intent: .importTranslations) }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            .disabled(navigator == nil)
        }
        CommandMenu("Product") {
            Group {
                Button("Run Autopilot", systemImage: "play.circle") { navigator?.requestsAutopilot = true }
                    .keyboardShortcut("a", modifiers: [.command, .option])
                Button("Review & Push…", systemImage: "arrow.up.circle") { navigator?.isReviewPresented = true }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Activity", systemImage: "clock") { navigator?.isActivityPresented = true }
                // The chat in the window's corner (board 69).
                Button("Assistant Chat", systemImage: "text.bubble") { AssistantChatCenter.shared.toggle() }
                    .keyboardShortcut("j")
            }
            .disabled(navigator == nil)
        }
    }
}
