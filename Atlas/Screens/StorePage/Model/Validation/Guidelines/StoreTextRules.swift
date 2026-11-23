//
//  StoreTextRules.swift
//  Atlas
//

import Foundation

/// App Review's rules for store text and screenshots, as assistants read
/// them before writing: in the MCP server's instructions, the prompts,
/// get_listing's and get_store_page's `storeTextRules`, and what Generate
/// Suggestions… sends. `StoreTextGuidelineCheck` refuses what breaks the
/// ones words can show; the others are for the assistant's judgment.
nonisolated enum StoreTextRules {
    /// One sentence for prompts and instructions.
    static let summary = """
    Store texts and captions follow App Review’s metadata rules. No prices, “free” (in any language), discounts or trial \
    lengths: the App Store shows price and offers itself (Guideline 2.3.7). No other platforms or app stores, like \
    Android or Google Play (2.3.10). No other apps’ names in the name, subtitle or keywords, and no unverifiable claims \
    like “#1” or “best” in the name or subtitle (2.3.7). No beta, demo or “coming soon” (2.2, 2.3). No placeholder text \
    (2.1). “For Kids” only in the Kids Category (2.3.8). Describe only what this version does (2.3.1). Texts that break \
    a rule are refused with the reason.
    """

    /// `storeTextRules`: each rule with its guideline.
    static let all: [String] = [
        """
        2.3.7 Pricing: no prices, “free” in any language, discounts, sales or trial lengths in the name, subtitle, \
        promotional text, description, keywords, What's New or screenshots. The App Store shows the price, in-app \
        purchases and offers itself. Saying which features need Pro or an in-app purchase is fine, and 2.3.2 asks the \
        description to make that clear.
        """,
        """
        2.3.7 Name, subtitle and keywords: no other apps' names, brands or trademarked terms, and no unverifiable claims \
        (“#1”, “best”, “award-winning”). The name is at most 30 characters and keywords describe the app.
        """,
        "2.3.10: no other mobile platforms or app marketplaces (Android, Google Play, Setapp) anywhere in the metadata.",
        """
        2.3 and 2.3.1: describe only what this version does, with no “coming soon” and no features it doesn't have; \
        promote no false price.
        """,
        "2.2: no beta, demo or trial versions; 2.1(a): no placeholder text such as lorem ipsum, TODO or [insert name].",
        """
        2.3.8 and 5.1.4(b): metadata suits all audiences (4+), and “For Kids” or “For Children” is reserved for the \
        Kids Category.
        """,
        """
        2.3.12: What's New describes the new features and changes; only bug fixes and performance work may stay \
        generic.
        """,
        "2.3.3 and 2.3.9: screenshots show the app in use, with fictional accounts and data, never a real person's.",
    ]

    /// `storeTextRules` as tool results carry it.
    static var json: JSONValue {
        .array(all.map(JSONValue.string))
    }

    // MARK: - In-App Texts

    /// One sentence for in-app purchase, subscription and group texts, in
    /// get_in_app_texts, propose_subscription and the prompts that write
    /// them.
    static let inAppSummary = """
    In-app purchase, subscription and subscription group names and descriptions follow the same metadata rules: no \
    prices, “free” (in any language) or discounts, since the App Store shows each product’s price and offers (Guidelines \
    2.3.7, 2.3.1); no trial lengths in a subscription’s texts (its free trial is an introductory offer, 3.1.2(a)); no \
    other platforms or app stores (2.3.10); no placeholder text (2.1); nothing “coming soon” (2.3); “For Kids” only in \
    the Kids Category (2.3.8); texts that suit everyone (2.3.2). Exception: a non-subscription app’s free trial is a \
    non-consumable at Price Tier 0 named “XX-day Trial”, like “7-day Trial” (3.1.1), so its texts may say how long it \
    lasts. Texts that break a rule are refused with the reason.
    """

    /// get_in_app_texts' `textRules`: each rule with its guideline.
    static let inApp: [String] = [
        """
        2.3.7 and 2.3.1: no prices, “free” in any language, discounts or sales in a display name or description. The \
        App Store shows each product's price in the person's currency, and any offer, next to its name.
        """,
        """
        3.1.1: a non-subscription app may offer a free time-based trial as a non-consumable in-app purchase at Price \
        Tier 0 named “XX-day Trial” (e.g. “7-day Trial”); keep that name. 3.1.2(a): a subscription's free trial is \
        an introductory offer, so its name and description don't mention one.
        """,
        """
        2.3.2: names and descriptions suit a public audience and say what the purchase unlocks; 2.3.8: “For Kids” \
        and “For Children” are only for the Kids Category.
        """,
        "2.3.10, 2.1(a) and 2.3: no other platforms or app stores, no placeholder text, nothing “coming soon”.",
    ]

    static var inAppJSON: JSONValue {
        .array(inApp.map(JSONValue.string))
    }
}
