ATLAS · PROPOSAL · NOVEMBER 2026

# Overview, Pricing, Store Page, Screenshots and App Information: a clearer design

A redesign of the five sections, with two goals: make it obvious what each section changes on the App Store, and make suggestions easy to find and accept, without going language by language.

**Navigation update, November 16.** The sections moved from the toolbar to the sidebar, grouped as Overview · Store Listing · After Release, with the app list in a menu at the top and the version’s status at the bottom (page *Proposta · Navegação*, boards 41–43). Where this README says “tab bar” or “toolbar” for sections, read “sidebar”. Every board on the canvas already shows the new navigation.

**Toolbar update, November 21 (accepted).** Each section’s title and status now sit in the toolbar, and the title row inside the page is gone. One **Autopilot** button, top right, does what Claude Code can do in that section (Suggest Texts…, Make Screenshots…, Draft Replies…). It replaces Ask Claude Code… and Start Autopilot… in the pages, and the Assistant button. **Review & Push** in the toolbar is the only way to push. See *Toolbar e ações* and its README.

**Update, November 22: buttons, Overview, App Information.**  
**One button size.** Buttons are 28 pt high (13 pt text) everywhere in a page or a sheet; a smaller 24 pt button (12 pt text) is only for actions inside a suggestion, a table row or a toast. Before they were 24 and 20. Text fields, menus and segmented controls are 28 pt too, so a row of controls lines up. The toolbar keeps 32 pt. Blue is the one main action of a card or sheet; purple is Accept All; red text is destructive.  
**Overview is three lists.** What 1.4 still needs before App Review (only what is missing, then Submit for Review…); the suggestions to review, one row per section; and After release (Analytics, Ratings & Reviews, Product Pages) with one line each. The App Store preview is smaller and on the right. Removed: the app’s name and version at the top (they are in the toolbar), the tags on the preview, “How a change reaches the App Store”, and the new-languages banner (the Store Page row says it).  
**App Information** shows its title once, in the toolbar; the title above the page list is gone.

**Update, November 22 (2): the app switcher and a first-run tour** (board 63 on *▶ App clicável*).  
**App switcher.** It has a label, “App”, like the other groups of the sidebar; the first two lines stay about this app (name; team and role); a third line, under a hairline, is about the others: “5 other apps · 3 suggestions in Habitat” (purple when there are suggestions; “2 with suggestions” when more than one app has them; hidden with a single app). It replaces the purple dot. The arrows sit in a round control. ⌘K opens it.  
**Tour.** Five tips, one at a time, each pointing at the thing it explains: the app switcher, the sections and their purple numbers, the Autopilot button, Review & Push, and Settings. Each has Next and Skip the Tour, a close button and “2 of 5”. The last one offers Connect an Assistant…. It starts once, after the first sync, and **Show the Tour** in the sidebar (also in the Help menu) starts it again.  
**For Claude Code:** build the tips with `TipKit`: one `Tip` per step, shown with `.popoverTip(_:arrowEdge:)` on the control, in order with a `TipGroup(.ordered)`. Next is a tip action that invalidates the current tip; the close button and Skip the Tour invalidate all five. Show the Tour calls `Tips.resetDatastore()` and configures again. The “2 of 5” counter isn’t part of TipKit’s standard view, so it needs a custom `TipViewStyle`; drop it if the standard look is preferred. Check the TipKit API names against the current SDK before building.

**On the canvas.** The page *Proposta · Novo design* has the clickable prototype (press Play), the board **Redesign · every state** with 21 states, and this README. The current design stays on the other pages until this proposal is approved.

## What was hard

- **The sections don’t say what they change.** Store Page, App Information and Pricing were lists of fields. Someone new to Atlas couldn’t tell which field shows where on the App Store, or that most of App Information never shows at all.
- **Suggestions were hidden until you opened a section.** The tab bar didn’t say where suggestions were waiting, and the language tabs only showed counts for the few languages that fit in the row.
- **Accepting meant visiting every language.** “Accept All (2)” worked for one language. “Accept All 32 in Every Language” was a small link under the bar, and accepted everything without showing what it was accepting.

## Principles

1. **Say what it changes, and show it.** Every section starts with one sentence about what it controls. Store Page, App Information and Pricing have a preview of the App Store beside the editor; Screenshots are their own preview. The preview has **Now | Suggested**, so you can see the page with the suggestions before accepting them. Each Store Page field says where it appears (“Under the name, on the page and in search results”; “Not shown on the page. Only App Store search reads them”).
2. **One meaning per color.** Purple is a suggestion waiting for you: badges, suggestion cards, highlighted text in the preview, rings around screenshots. Blue is accepted or edited and waiting in Review & Push (“Not pushed”). Plain is what’s live.
3. **Suggestions are visible from anywhere.** A purple count is shown wherever you navigate: on the tab bar, the app in the sidebar, each language in the language menu, each App Information page, iPhone and Apple Watch in Accessibility, Prices and Retention in Pricing, and each language in Screenshots.
4. **Accept everything without going language by language, but see it first.** Accept All Languages sits right beside the language you’re viewing, and shows every suggestion before accepting, unless you’ve told it not to ask.
5. **Accepting is never pushing.** Accepted suggestions wait in Review & Push, and every accept can be undone from the toast.

## Badges

| Where | What the number counts |
| --- | --- |
| Tab bar: Pricing, Store Page, Screenshots, App Information | Suggestions in that section not yet accepted or dismissed. Overview has no badge: it is the summary. |
| App in the sidebar | All of the app’s open suggestions. |
| Language picker | “5 suggestions here” under the language’s name. |
| Language menu (Store Page, Screenshots) | Languages with suggestions first, each with its count; then “Up to date” languages with a check. A language the app supports but the App Store doesn’t have yet is marked **New page**. |
| App Information pages | Count plus a short status: “7 suggested · 7 unanswered”, “In progress”, “Exempt · done”. |
| Inside a page | Accessibility’s iPhone and Apple Watch, and Pricing’s Prices and Retention, each have their own count. |

A badge disappears at zero. Badges are purple with white text (dark text in dark mode); in High Contrast they use the darker purple. VoiceOver reads them as part of the label: “Store Page, 32 suggestions to review”.

## Accept All Languages

- **Where:** right beside the language picker in Store Page and Screenshots, with the total count. App Information has the same button, **Accept All Pages**, beside the page’s description. Pricing has **Accept All 3** above its products.
- **The sheet:** languages on the left (or pages), each with a checkbox and “5 of 5”; the selected language’s suggestions on the right, each with a checkbox, Now and New, who suggested it and why. Screenshots show the screenshot before and after. Untick a whole language or a single field. A new language says that accepting creates its page when you push.
- **Don’t ask again:** a checkbox in the sheet’s footer. When it’s on, the next Accept All Languages accepts everything at once and says so in the toast. A line under the button reads “Accepts right away” with **Ask First** to turn it off. It’s also in Settings → Suggestions. It is one setting for Store Page, Screenshots and App Information.
- **After:** a toast “Accepted 23 suggestions in 5 languages. They’re in Review & Push.” with **Undo** and **Review & Push**. Badges drop to what’s left.
- The arrows beside the button jump to the previous or next language with suggestions. **Accept 5 in English** accepts only the language you’re viewing.

## Each section

### Overview

Left: three cards. What 1.4 still needs before App Review, with Submit for Review…; “65 suggestions to review”, one row per section with Review; “After release”, one row each for Analytics, Ratings & Reviews and Product Pages. Right: the top of the App Store page (name, rating, screenshots) in English, German or Japanese; clicking a part opens the section that edits it.

### Store Page

Language picker + Accept All Languages + arrows; the fields, each with where it appears and its counter; suggestions inline under the field; the App Store preview on the right with the store’s own words in that language (Laden, Neue Funktionen, In-App-Käufe). Hebrew and Arabic run right to left in the fields and the preview. Ask Claude Code… and Editor | In-App Texts move to the header.

### Screenshots

The same language bar. One language at a time, large, drawn by the template engine; a suggested caption appears on the screenshot itself with a purple ring and “Caption suggested”. **All Languages** shows every language at a glance with its count. Device switch (iPhone, iPad, Mac) and Start Autopilot… stay.

### App Information

Pages on the left with counts and status. Each page says what it changes on the App Store (“Not on the App Store. Only App Review reads it.”). Yes/No and None/Infrequent/Frequent questions are one line each, with the suggestion on a line under them. The preview shows the Information and Accessibility sections.

### Pricing

One card per product: its U.S. price and a bar showing how its 175 prices are set (equalized, recommended, suggested). Suggestions sit inside the product; Show Countries lists now and suggested per country. “What people pay” shows the In-App Purchases list in the U.S., Germany, Brazil, India or Japan, now or with the suggestions. Retention is a tab with its own badge.

## What doesn’t change

- Review & Push and the push itself (board 7), In-App Texts (boards 26–27), Retention’s editor (board 28), App Privacy (boards 15–16), Autopilot (board 21), the Assistant popover and setup.
- How suggestions are made, who makes them, and the MCP tools.

## For Claude Code

- Badges come from the same open-suggestions query everywhere (not accepted, not dismissed), grouped by section, language, page or product, so they always agree.
- The tab bar is a custom segmented control so each segment can show a badge; keep ⌘1–⌘5.
- Setting: `acceptAllWithoutAsking`, default off, shared by Store Page, Screenshots and App Information; shown in Settings → Suggestions and under the button when on.
- Accept All accepts only what’s ticked, as one undoable change. Undo restores the exact set.
- Accepting a new language’s suggestions queues “create the page”, as today.
- The App Store previews use the store’s strings for each language and the app’s real rating per storefront; the screenshots come from the template engine.

To validate: whether the previews earn their width on smaller windows (they could fold to a button under 1100 pt); whether one “Don’t ask again” for every section is right, or Store Page and App Information should be separate.
