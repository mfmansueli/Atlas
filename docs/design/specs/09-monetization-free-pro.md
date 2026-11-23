ATLAS · MONETIZATION · PROPOSAL · NOVEMBER 2026

# Free and Pro

One rule people can repeat: **Free does it one at a time. Pro does it all at once.** Plus two lines that follow from it: the tools that earn the developer money (prices and retention) are Pro, and more than one app is Pro.

**Navigation update, November 16.** The sections moved from the toolbar to the sidebar, grouped as Overview · Store Listing · After Release, with the app list in a menu at the top and the version’s status at the bottom (page *Proposta · Navegação*, boards 41–43). Where this README says “tab bar” or “toolbar” for sections, read “sidebar”. Every board on the canvas already shows the new navigation.

**On the canvas.** The paywall is in the redesign prototype on this page. Open the Prototype pill and turn Pro off, then try Accept All Languages, Start Autopilot…, recommended prices or the Pro button in the toolbar. The board **Paywall · every state** shows 9 states.

## Why this split

- **The pain Atlas removes is repetition.** A store page in 12 languages is 96 fields; screenshots are 5 per language per device. Doing that by hand is possible for free, and paying removes the repetition. People pay when they feel it, not before.
- **Free has to be good enough to recommend.** A developer with one app can keep their page right in every language for free. That makes Atlas the tool people tell other developers about, and Pro the obvious step when they have a second app or a deadline.
- **AI costs Atlas nothing.** Suggestions come from the person’s own assistant (Claude Code and other MCP assistants) or their API key. So there are no credits or usage limits to explain, and Pro can be a flat price.
- **Money tools pay for themselves.** Recommended prices across 175 countries and retention offers exist to increase the developer’s revenue, and the people who use them run paid apps.

## What’s in each

| Feature | Free | Pro |
| --- | --- | --- |
| Apps and App Store Connect accounts | 1 app, 1 account | Unlimited |
| Store Page, App Information, Pricing: edit and push, every language | ✓ | ✓ |
| Built-in checks and suggestions (limits, missing languages, cut captions) | ✓ | ✓ |
| Suggestions from your AI assistant | One at a time, and one language at a time (“Accept 5 in English”) | Also all at once |
| Accept All Languages, Accept All Pages, Translate All | — | ✓ |
| Review & Push | ✓ | ✓ |
| Screenshot editor | 3 templates, iPhone and iPad | All 14 templates, every device (Mac, iPhone Duo, Vision Pro, Apple Watch) |
| Autopilot (screenshots, App Preview, header artwork) | — | ✓ |
| Recommended prices for 175 countries | — (setting any price yourself stays free) | ✓ |
| Retention messages and offers, real-time setup | — | ✓ |
| Replies to reviews (board 58) | Write a reply, or ask for a suggested one, one review at a time | Also reply automatically to the reviews you allow |

Never gate: reading anything, pushing, Restore Purchases, the checks that stop a bad push, or anything a person already made. If Pro ends, their work stays and stays editable; only the all-at-once actions lock again.

## Price

| Plan | U.S. price | Notes |
| --- | --- | --- |
| **Yearly** (default) | $59.99 / year | 7-day free trial. Shown as $5.00 a month and “Save 50%” against Monthly. |
| Monthly | $9.99 / month | For one launch or one release. |
| Lifetime | $149.99 once | 2.5 years of Yearly. Indie Mac developers ask for it, and it brings cash early. |

### Why there

Mac tools for App Store Connect sit between about $25 and $55 a year when they do one job, and much higher when they are full ASO suites. Atlas does the jobs of several of them (store text, screenshots, prices, retention, review and push), so it can sit at the top of the indie range without reaching the suites.

| Tool | What it does | Price |
| --- | --- | --- |
| Helm for App Store Connect | App Store Connect client, AI translations | $9.99/month, $34.99–54.99/year, $274.99 lifetime; free tier with limits |
| ButterKit | Screenshot design, App Store Connect upload | $10/month, $39/year, $79 lifetime; free with watermark |
| Dragoman | Bulk metadata translation | $4.99/month, $24.99/year, $49.99 lifetime |
| ShipLocal | Metadata and screenshot translation | $24.99/year; free for 4 languages |
| AppScreens | Screenshot generator (web) | $25 and $50 a month |
| ASO.dev | ASO suite with App Store Connect | Indie $38.99/month or $349.99/year; Pro $88.99/month |

Prices from the App Store listings and the developers’ pricing pages, November 2026. Check them again before launch.

### Around the price

- **Use Atlas on itself.** Set Atlas’s own prices with its recommended prices (lower in Brazil, India, Türkiye and others), and use its own Retention to offer a discount when someone cancels Pro.
- **Launch offer:** an introductory first year at $39.99 for the first months, then $59.99.
- **Later, a Team plan** (around $199/year) when agencies ask for it: several App Store Connect accounts, more than 10 apps, shared settings. Not at launch.

## The paywall

- **Where it opens:** from the action that needed Pro (Accept All Languages, Accept All Pages, Start Autopilot…, recommended prices, Retention), and from **Pro** in the toolbar. Pro features show a small PRO chip before they’re clicked, so the paywall is never a surprise.
- **What it says:** a card with what was blocked, in the person’s own numbers (“Accept 32 suggestions in 6 languages in one step”), and that the one-at-a-time way stays free. The left side lists what Pro adds and highlights the feature they clicked.
- **Plans:** Yearly is selected by default with the trial; Monthly and Lifetime are one click away. The button says exactly what happens: “Start 7-Day Free Trial”, “Subscribe for $9.99 a Month”, “Buy Pro for $149.99”.
- **After buying:** what’s unlocked, the trial end date, and a button that finishes what they started (“Accept 32 Suggestions…”).
- **Always visible:** the full price and period, how renewal works, Restore Purchases, Terms of Use and Privacy Policy. These are what App Review checks (guideline 3.1.2) for subscriptions. Close is always there; no countdowns or fake discounts.

## For Claude Code

- StoreKit 2. Products: `pro.yearly` (auto-renewable, 1 year, 7-day free trial intro offer), `pro.monthly` (auto-renewable, 1 month), same subscription group; `pro.lifetime` (non-consumable). Entitlement = any active subscription or the lifetime purchase, checked with `Transaction.currentEntitlements` at launch and on `Transaction.updates`.
- One `Entitlements` type answers `canUse(.acceptAll / .autopilot / .recommendedPrices / .retention / .multipleApps / .allTemplates / .autoReply)`. Every gated button calls it and opens the paywall with that context; nothing is hidden.
- Use the MCP tools freely in Free. When an assistant asks for a bulk action through MCP, it gets a clear message that it needs Pro, and the suggestions still land one by one.
- Prices come from StoreKit (`displayPrice`), never hard-coded, so each country sees its own price and currency.

**Check first: Mac App Store or direct?** Autopilot drives the Simulator, a helper and Claude Code on the person’s Mac. If those can’t run in the App Sandbox, Atlas can’t be on the Mac App Store, and Pro would be sold directly (for example through a merchant of record such as Paddle, which also handles VAT). The paywall stays the same; Restore Purchases becomes “Enter License Key”, and the fine print changes to that store’s terms.

To validate with the first users: whether 1 free app is right, or Free should allow 2; whether Lifetime takes too many sales from Yearly (watch the split for the first 3 months); and whether the trial converts better at 7 or 14 days.
