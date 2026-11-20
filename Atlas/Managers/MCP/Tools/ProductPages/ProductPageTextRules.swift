//
//  ProductPageTextRules.swift
//  Atlas
//

import Foundation

/// What a custom product page's suggestions follow, as get_product_pages'
/// `textRules` and the propose tools' descriptions say it. Promotional text
/// is store text (`ListingField.promotionalText`), so it's checked by
/// `StoreTextGuidelineCheck` like the default page's.
enum ProductPageTextRules {
    /// One paragraph for the propose tools' descriptions.
    static let summary = """
    Promotional text is store text: at most 170 characters, with no prices, “free” in any language, discounts, \
    sales or trial lengths (Guideline 2.3.7: the App Store shows the price and offers itself), no other platforms \
    or app stores (2.3.10), no beta, demo or “coming soon” (2.2, 2.3), no placeholder text (2.1) and “For Kids” \
    only in the Kids Category (2.3.8). A text that breaks one is kept and shown to the person as Not offered, \
    with the words marked and why, and can't be accepted: write another for that language.
    """

    /// `textRules`.
    static let rules: [String] = [
        """
        Promotional text: up to 170 characters in each language, written for the page's audience in that \
        language's voice. A language without its own shows the default page's.
        """,
        """
        2.3.7: no prices, “free” in any language, discounts, sales or trial lengths. The App Store shows the price, \
        in-app purchases and offers itself; saying which features need Pro is fine.
        """,
        """
        2.3.10, 2.2, 2.3, 2.1(a) and 2.3.8: no other platforms or app stores, no beta, demo or “coming soon”, no \
        placeholder text, and “For Kids” only in the Kids Category.
        """,
        """
        Keywords: only the last approved version's keywords in that language (keywords.<locale>.free); a keyword \
        leads to one page, so one another page uses is refused with that page's name.
        """,
        """
        A text that breaks a rule is kept as Not offered: the person sees why and can't accept it. You never push, \
        submit or make a page visible: the person does.
        """,
    ]

    static var json: JSONValue {
        .array(rules.map(JSONValue.string))
    }
}
