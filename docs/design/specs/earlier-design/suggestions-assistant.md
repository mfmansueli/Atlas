ATLAS · SUGGESTIONS, AI ASSISTANT, NEW SUBSCRIPTION · OCTOBER 2026

# Field suggestions, your AI assistant, and adding a subscription

Three additions, plus an API-key option and AI help for Age Rating and Accessibility. Store Page and App Information suggest what to put in each field, and you accept, edit or dismiss each one, or accept them all at once. Connecting your own AI assistant through MCP is now explained where people look and set up in four guided steps. Subscription Pricing gets an Add Subscription button, where you decide on the spot whether the new subscription uses the recommended prices or whether you’ll review them later.

**On the canvas.** *Prototype — suggestions, assistant & new subscription* sits after the Accessibility and App Privacy prototype; its Prototype pill restarts the three flows. Boards 17–18 embed it at every state, in light and dark. *Components — suggestions & assistant* holds the new parts. The shell, tokens, Review & Push and the Settings → AI Assistants window are the ones already specified; nothing here adds a color.

## 1 · Field suggestions

A suggestion is a proposed value for one field, in one language or App Information page, with a reason. It never changes the field by itself.

### Where suggestions come from

| Source | Tag | Needs | Good at |
| --- | --- | --- | --- |
| **Built-in** | `AL` Built-in | Nothing. Always on. | Limits, words repeated between name, subtitle and keywords, empty fields that other languages fill, dates, values from the previous version (review contact, release habit). |
| **Your assistant** | `CC` Claude Code, or the client’s name | The local MCP server and a connected client | Anything that needs your code or history: What’s New from commits, promotional text from the changelog, App Review notes from a debug menu, categories from what the app actually does, translations with your glossary. |
| **AI provider** | `AP` AI provider | The translation key in Settings → Translation | Text only, no code: keywords and wording per language. |

Tags are neutral. The purple “Suggested” pill and the purple tint mean *not reviewed yet*, as everywhere else in the app. An accepted value uses the blue *Not pushed* dot, like any other local change.

### Anatomy

- Under the field: **Suggested** pill · source tag · the reason in one sentence · **Now** and **Suggested** on two rows · the limit after the change (“75 / 100 bytes · frees 13”) · **Dismiss**, **Use and Edit**, **Accept**.
- **Accept** puts the value in the field. A line under it says who suggested it (“Accepted Claude Code’s suggestion.”) with **Undo**. Editing it afterwards changes the line to “Edited from Claude Code’s suggestion.”
- **Use and Edit** puts the value in the field and moves focus there, for when it’s almost right.
- **Dismiss** hides it. The bar offers **Restore n Dismissed** for this language or page.
- A field that already holds the suggested value shows no suggestion.

### The suggestion bar, and accepting everything at once

- One bar per language (Store Page) or page (App Information): the count, a source filter (*All · Built-in · Claude Code · AI provider*, empty sources hidden), **Ask Claude Code…**, **Dismiss All**, **Accept All (n)**.
- **Accept All** takes what the filter shows in this language or page. When other languages have suggestions too, a line under the bar offers **Accept All n in Every Language**.
- No confirmation dialog, because nothing reaches App Store Connect: every accepted value waits in Review & Push, and a toast offers **Undo** for the whole batch.
- **Only fields with suggestions or changes** hides the rest of the form for a quick pass.
- The language control shows a purple count per language; App Information’s page column shows “2 suggestions” under each page. Overview’s *Suggestions* card sums them by area and by source.

### Sample suggestions in the prototype

| Where | Field | Source | Reason |
| --- | --- | --- | --- |
| Store Page · English | Keywords | Built-in | Drops “journal” and “mood”, already in the name and subtitle; frees 13 bytes |
|  | Marketing URL | Built-in | Empty here; other languages use lumen.example |
|  | What’s New | Claude Code | Written from 23 commits since the v1.3 tag |
|  | Promotional Text | Claude Code | Announces 1.4’s main feature; promotional text changes without review |
|  | Subtitle | Claude Code | “Private” is what reviews praise most |
| Store Page · German | What’s New | Claude Code | Translation of the English suggestion, with the glossary |
|  | Keywords | AI provider | Adds the English “journal”; fits in the 15 bytes left |
| App Information · General | Copyright · Secondary category · Version release | Built-in · Claude Code · Built-in | Year; no health features in the code; 1.1–1.3 were released by hand within an hour |
| App Information · App Review | Contact phone · Notes | Built-in · Claude Code | From 1.3’s review details; how to reach Weekly Reflections with the debug menu |

Japanese has none, to show the empty state.

## 2 · Making the assistant integration visible

The integration was only reachable from Settings → AI Assistants. Now it shows up in four places, each with the same message: *your own assistant, on this Mac, suggests; you decide; nothing is pushed without you*.

1. **Overview card** “Use your own AI assistant with Atlas”: what it does, which clients work, three steps, **Set Up Assistant…** and **What Can It Do?**. Once connected it shrinks to a status line with **Ask for Suggestions…**. It can be hidden.
2. **Assistant button** in the toolbar, with a status dot: grey *Not set up*, yellow *Waiting for a first call*, green *Connected*, a spinner while suggestions arrive. The dot is never alone: the popover and the VoiceOver label say the state in words. The popover lists what it can suggest on each page and the privacy facts.
3. **Suggestion bar**: **Set Up Assistant…** in place of **Ask…**, and a dismissible card that says what an assistant would add on this page.
4. **App Privacy** keeps its own connect state from the previous addendum.

## 3 · Setting it up

A four-step sheet. It writes the same configuration as Settings → AI Assistants, which stays the place to manage tokens and permissions.

| Step | What the person does | Notes |
| --- | --- | --- |
| **1 · Assistant** | Picks Claude Code, Claude Desktop, Cursor, Codex CLI or another MCP client | Claude Code is recommended for Lumen because it can read the project’s code and git history. “No assistant?” explains what still works. |
| **2 · Local server** | Turns on the local MCP server; picks *Suggest only* (default) or *Suggest and edit drafts* | 127.0.0.1 only, only while the app is open. The App Store Connect key stays in the Keychain. One token per assistant, revocable. Neither choice can push. |
| **3 · Add to assistant** | Copies one command or a JSON snippet | The text depends on the client and includes that client’s token. The token is shown once in the command, then masked in Settings. |
| **4 · Test** | Asks the assistant “List my apps in Atlas” | The sheet waits for the first call, then shows “Connected · called list\_apps and got your 6 apps”, with prompts to try. If nothing arrives: restart the client. **Finish Without Testing** leaves the status yellow. |

### What step 3 shows

```
# Claude Code, from the app’s project folder
cd ~/Developer/Lumen
claude mcp add --env ALX_TOKEN=alx_cc_7Q2fK9xR atlas \
  -- "/Applications/Atlas.app/Contents/Helpers/alx-mcp"

# Codex CLI
codex mcp add atlas --env ALX_TOKEN=alx_cx_3Lm8Pq2T \
  -- "/Applications/Atlas.app/Contents/Helpers/alx-mcp"

# Claude Desktop (claude_desktop_config.json) and Cursor (~/.cursor/mcp.json)
{
  "mcpServers": {
    "atlas": {
      "command": "/Applications/Atlas.app/Contents/Helpers/alx-mcp",
      "env": { "ALX_TOKEN": "alx_cd_9Vt4Hn6W" }
    }
  }
}
```

`alx-mcp` is a small stdio bridge inside the app bundle. It forwards to the running app over a local socket and checks the token, so every client is configured the same way. Claude Code adds servers to the current project by default; the sheet mentions `--scope user` for every project.

### Asking for suggestions

MCP is driven by the client, so Atlas can’t start the assistant. **Ask Claude Code…** copies a prompt (“Suggest Store Page text for Lumen 1.4 in Atlas…”) and shows a popover that says to paste it and waits. The server also offers it as an MCP prompt, which Claude Code lists as `/mcp__atlas__suggest`. Suggestions arrive one at a time; a banner and the toolbar button show progress, and a toast gives the total when it ends.

### Or an API key

Step 1 now starts with the method. Both are honest about what they give up:

|  | Connect an assistant you use (MCP) | Use an API key |
| --- | --- | --- |
| **Who runs the model** | Your assistant, on its own plan | Atlas, with your key from Anthropic, OpenAI or Google Gemini |
| **Asking** | Paste a prompt into the assistant | **Generate Suggestions…** in the suggestion bar, one click |
| **Reads the code** | Yes, the assistant reads the project itself | No. Only App Store Connect text, plus commit messages, CHANGELOG.md and reviews if you allow them |
| **Cost** | Part of the assistant’s plan | Billed per request to your API account; each request shows its size first |
| **Good for** | Everything, including App Review notes, categories, age rating, accessibility, privacy | Store text and translations: What’s New, promotional text, subtitles, keywords |

With a key, the steps are *Method · API key · What it sees · Test*:

- **API key.** Provider (Anthropic · OpenAI · Google Gemini), a secure field, **Check Key**, then the model list the key can use. A rejected key shows the provider’s answer (“rejected this key (401)”). A link opens the provider’s key page. The key goes in the Keychain and only to that provider. *Also use this key for translations* replaces the separate key in Settings → Translation.
- **What it sees.** App Store Connect text is always sent. *Project folder* (commit messages since the last release tag, CHANGELOG.md, read on this Mac) and *Customer reviews* are switches. Source code is never sent.
- **Test.** One small request (a subtitle, about 400 tokens) with its answer and the time it took.
- **Generate Suggestions…** opens a popover listing what will be sent, with token estimates per item and in total, and **Generate**. Suggestions arrive the same way as from an assistant, tagged with the provider (“Anthropic API”).
- Where a page’s suggestions need the code (categories, App Review notes, age rating, accessibility), a line says so (“6 answers here come from Lumen’s code…”) with **Add an MCP Assistant…**. Built-in suggestions still show.
- Both methods can be set up at once in Settings → AI Assistants; each suggestion’s tag says which one made it. The prototype shows one at a time.

## 3b · Age Rating and Accessibility

Both App Information pages use the same suggestion bar, cards, Accept All and Undo as the other fields. Their answers are choices, not text, so a suggestion shows **Now** and **Suggested** as answers, and there’s no *Use and Edit*: you pick the other answer directly.

### Age Rating

- The questionnaire in two groups: content questions (None · Infrequent · Frequent), already answered as in 1.3, and the newer questions (Yes · No) that Lumen hasn’t answered yet: Health or Wellness Topics, Unrestricted Web Access, User-Generated Content, Messaging and Chat, Advertising, Parental Controls, Age Assurance.
- The assistant answers from the code, with the evidence in the reason: “The only web view opens Lumen’s own help pages (HelpView.swift…)”. Advertising has a built-in answer from App Privacy’s last scan.
- The estimated rating stays in the header. Apple calculates the final rating.

### Accessibility

- A device control (iPhone · Apple Watch here; iPad and Apple Vision Pro work the same) and one Yes/No row per feature, with Apple’s meaning under it. Voice Control isn’t asked on watchOS.
- The assistant answers from the code: labels on every control, text styles instead of fixed sizes, Reduce Motion checks, color plus shape. Built-in answers say No to Captions and Audio Descriptions when the app has no video or audio.
- **Sufficient Contrast** and **Dark Interface** get no suggestion on Apple Watch: they need a person to check the screens. The card says so in Apple’s meaning text.
- Accepted answers go to Review & Push as accessibility declaration changes, with the Publish option described in the Accessibility addendum.

## 3c · Suggest Everything

One prompt in which the assistant reads the project and suggests every field it can: Store Page in every language, and App Information (General, Age Rating, Accessibility for each device, App Review). The per-page **Ask…** stays for a single language or page.

### 1 · Entry

- **Overview, assistant card:** **Suggest Everything…** is the primary button, next to **Details**. It replaces *Ask for Suggestions…*, which only ever meant Store Page.
- **Overview, Suggestions card:** counts per area (Store Page · General · Age Rating · Accessibility · App Review) and a **Suggest Everything…** button.
- **Assistant popover:** **Suggest Everything…** as the primary action, plus **Ask About This Page…** when you’re on Store Page or App Information.

### 2 · Waiting

A popover under the assistant card: the prompt (already copied), **Copy Again**, the MCP shortcut `/mcp__atlas__suggest_all`, a *What it covers* list, a note that changed fields are left alone and unreviewed suggestions stay, and “Waiting for Claude Code to start…” with **Cancel**. It closes on its own when the assistant announces its plan.

### 3 · Receiving

- **Overview:** the assistant card becomes a progress card: “Suggesting everything · 9 of 18”, a bar, and one row per area with what it covers (“English 3/3 · German 0/1 · Japanese 0/1”), its own count and bar, and **Review** as soon as one has arrived. **Stop Receiving** ends the run. The Suggestions card shows “· 2 coming” per area and an *Arriving…* pill. The toolbar button shows a spinner.
- **Store Page and App Information during the run:** a banner (“Suggesting everything · 6 of 18. Here: 2 of 3 arrived.”) with **Overview**. Fields still to come show a striped placeholder: “Claude Code is writing a suggestion for this field…”. Languages and devices with more coming show a small spinner; the page column says “3 suggestions · 4 coming”. *Ask…* is hidden. Accept All takes only what has arrived.
- Suggestions arrive mixed across areas, in the order the assistant sends them.

### 4 · Finished

- Toast: “Claude Code sent 18 suggestions: Store Page 5 · General 1 · Age Rating 6 · Accessibility 5 · App Review 1.” with **Review by Area**, which opens Overview.
- The progress card stays as a summary with **Review** per area, which opens the first language, page or device that has suggestions, plus **Accept All (n)** for every unreviewed one from this run and **Done**.

### 5 · Special cases

| Case | What happens |
| --- | --- |
| **Only an API key** | The button says what it does instead of disappearing: **Generate Store Page Suggestions…** (every language, one request, with what will be sent). A line under the card says App Information needs an assistant that reads the code, with **Add One…**. |
| **No assistant** | **Suggest Everything…** opens setup, with a line explaining why. When setup ends, the toast offers **Suggest Everything**. |
| **A per-area Ask is running** | It isn’t interrupted. The waiting popover says so (“still sending Store Page suggestions (2 of 4)”), and the run’s plan leaves out the fields that Ask covers, so nothing is counted twice. |
| **Age Rating never answered** | *What it covers* says “Not answered yet: all 16 questions”; afterwards the page shows a suggestion for every question. The header says Lumen has no rating yet. |
| **Version in review** | Locked areas are listed with a lock and skipped; the prompt asks only for Promotional Text and Accessibility. Locked fields are read-only with “Locked while 1.4 is in review”, and built-in suggestions for them are hidden. The Version card says *Waiting for Review* and what’s editable. |
| **Stopped, or the assistant goes quiet** | **Stop Receiving** keeps what arrived and refuses the rest. If nothing arrives for 2 minutes, the card says “Claude Code stopped sending · 12 of 18” with the same actions. |

Which fields lock in review is an assumption to check against App Store Connect: here, everything tied to the version or to app information except Promotional Text, while accessibility declarations stay editable.

## 3d · Languages the app supports that the App Store doesn’t

Suggestions used to cover only the languages already added in App Store Connect. But the build usually knows more: Lumen 1.4 ships Polish, Turkish and Hebrew in `Localizable.xcstrings`, and people who use those languages see the English page. Atlas now compares the two lists and suggests creating the missing pages, whether or not anyone added them by hand.

- **Where the list comes from.** The uploaded build’s localizations (App Store Connect returns them per build) and, with an assistant that reads the code, the String Catalog with each language’s coverage. A language under 90% coverage is listed but not preselected.
- **Store Page banner**, in the existing languages: “Lumen’s 1.4 build supports 3 more languages than its App Store page: Polish, Turkish, Hebrew.” **Review…** opens a sheet with each language’s evidence and how many fields are drafted; **Add All 3** adds them at once, with Undo.
- **The language control** shows the new languages with a *New* chip and their suggestion count, so their drafts can be read before deciding. In a new language’s tab, a built-in suggestion card says the page doesn’t exist yet, with **Create Page** and **Not Now**; the drafted fields follow below.
- **Accepting any field adds the language**, because the text needs a page to live in. Once added, a line says the page is created on push, with **Don’t Add**.
- **Review & Push** lists *Create the Polish page* first in that language’s group; its fields depend on it and can’t be pushed without it. After the push, the tab loses its *New* chip and the language count on Overview goes from 12 to 13.
- **Suggest Everything** includes them: the scope line reads “and new pages for Polish, Turkish and Hebrew”, and the prompt asks the assistant for languages the app supports that aren’t on the App Store yet. Overview’s Suggestions card has a *New languages* line.
- **Not Now** hides the card for that language in this version; it stays available in the language control and in the sheet.

```
get_store_page(app, version) → { …, "locales": [ … ],
  "app_locales": [ { "locale": "pl", "coverage": 0.98, "source": "Localizable.xcstrings", "on_app_store": false }, … ] }
suggest_fields(…, items: [ { "area": "store", "locale": "pl", "field": "name", "value": "Lumen — Dziennik", … } ])
  // allowed for a locale in app_locales even if it isn’t on the App Store; creating the page still needs the person
```

## 4 · MCP contract

Same pattern as the existing tools. Reads are always allowed while the server runs. `suggest_fields` needs the “Propose app information” permission (on for both setup choices). With *Suggest and edit drafts* the same call may set `"apply": true`, which writes the value as an unpushed change marked with the assistant’s name.

### `get_store_page(app, version, locales?)` · `get_app_information(app)`

Current values, live values, limits (characters or bytes), the language list, and the open suggestions with their source, so an assistant doesn’t repeat itself.

### `suggest_fields(app, version, items)`

```
{ "app": "dev.northpier.lumen", "version": "1.4",
  "items": [
    { "area": "store", "locale": "en-US", "field": "whatsNew",
      "value": "• Weekly reflections: a calm summary of your week, every Sunday\n…",
      "reason": "Written from the 23 commits since the v1.3 tag in northpier/lumen.",
      "evidence": [ { "kind": "git", "ref": "v1.3..4f2c91a" } ] },
    { "area": "info", "page": "review", "field": "notes", "value": "…", "reason": "…",
      "evidence": [ { "kind": "code", "ref": "Lumen/Debug/DebugMenu.swift:18" } ] } ] }

→ { "results": [ { "field": "whatsNew", "status": "queued", "id": "sg_81" },
                 { "field": "notes", "status": "queued", "id": "sg_82" } ] }
```

For Age Rating and Accessibility, `area` is `"info"` with `page` `"ageRating"` or `"accessibility"` (plus `"device"`), `field` is the question or feature, and `value` is one of its answers.

Per item, `status` is `queued`, `unchanged` (the field already has that value), `replaced` (an older open suggestion from the same source was replaced) or `refused` with a reason the assistant can act on: `over_limit` with the count, `invalid_answer` for a choice that isn’t offered, `unknown_field`, `locked` (the version is in review), `not_permitted`.

### A whole run: `begin_suggestions` → `suggest_fields` → `end_suggestions`

```
begin_suggestions(app, version, plan: [ { area, locale | page | device, field }, … ])
→ { "run": "run_42",
    "accepted": 18,
    "skipped": [ { "field": "subtitle", "locale": "en-US", "reason": "changed_by_you" },
                 { "page": "review", "field": "notes", "reason": "locked" },
                 { "locale": "en-US", "field": "keywords", "reason": "in_another_request" } ] }

suggest_fields(app, version, items, run: "run_42")   // any number of calls, any order
end_suggestions(run: "run_42")                        // optional; the run also ends at the plan’s last item
```

The plan gives the total for the progress bar and the fields for the “coming” placeholders. Items outside the plan are accepted and added to the total. After **Stop Receiving**, calls with that run get `refused: run_stopped`. `get_store_page` and `get_app_information` tell the assistant which fields are locked, changed or already suggested, so its plan matches.

### Prompts `suggest(area, app?)` and `suggest_all(app?)`

Returns the same text the Ask popover copies, with the field list and limits attached as context.

## 5 · Adding a subscription

**Add Subscription…** sits in Subscription Pricing’s header, next to **Add In-App Purchase…**, and on each group as **Add to Group**. Overview’s pricing card has it too.

### The sheet

| Field | Behaviour |
| --- | --- |
| Subscription group | The app’s groups, or New Group…. The new subscription takes the next level. |
| Reference name | Prefilled from the group and duration. Only the team sees it. |
| Product ID | Prefilled; checked as you type: allowed characters, already used by another product, used by a deleted product (IDs can’t be reused). Says that it can’t be changed later. |
| Duration | 1 week · 1 month · 3 months · 6 months · 1 year |
| Price (U.S.) | A stepper over Apple’s price points that starts empty, with a built-in suggestion: $1.99 for a week, because four weeks then cost more than Monthly at $4.99. **Use $1.99** applies it. Nothing is chosen for you. |
| Display name and description | 30 and 45 characters, English; other languages are translated later in Store Page. |

### Prices in the other 174 territories

The question the person answers before adding: *does this subscription cost what Atlas recommends, or do I check later?*

| Choice | What gets created | Afterwards |
| --- | --- | --- |
| **Use the recommended prices** · Recommended | The recommended price in every territory: 112 lower than Apple’s equalized price, none higher. The option shows sample prices (Brazil R$ 5,90, India ₹69, Germany 2,29 €…) and a table below. | “Recommended · 112 lower than equalized” on the row |
| **Use Apple’s prices now, review the recommendations later** | Apple’s equalized prices | A banner and a **Review…** button on the row. The review sheet lists the 112 territories with checkboxes, a “30% or more lower” filter, **Apply Selected (n)**, **Apply All 112**, **Keep Apple’s Prices** and **Later**. |
| **Use Apple’s equalized prices** | Apple’s equalized prices | Apple keeps them updated for taxes and exchange rates. |

The sheet says the trade-off in one line: prices you set yourself don’t follow Apple’s automatic updates. Recommendations use the purchasing-power model already used by *Show suggestions* in Subscription Pricing.

### Review & Push

- Two rows under Subscription Pricing: *New subscription · Lumen Plus Weekly* (product ID, duration, price, level) and *Prices · Lumen Plus Weekly* (“112 territories at the recommended price, 62 at Apple’s equalized price”). The prices row follows the subscription’s checkbox.
- Push creates the subscription, its English localization and its prices, in that order. A note says it goes to App Review with its own submission or with version 1.4, and its prices take effect once it’s approved.
- Accepted suggestions appear in their usual groups with the source tag; changes typed by the person show “You”.

## 6 · States

- **17 · Suggestions and assistant setup** (19 states): Overview before and after connecting, the Assistant popover, the four setup steps and done, Store Page with built-in suggestions only, Ask, suggestions arriving, all suggestions, accepted and dismissed, Use and Edit, German, no suggestions, App Information’s General and App Review.
- **19 · API key, Age Rating and Accessibility** (12 states): setting up with a key (checked, rejected, what it sees, test), Generate Suggestions with what will be sent, the Assistant popover with a key, Age Rating with suggestions, accepted and with only a key, Accessibility for Apple Watch and iPhone.
- **19** also has **new languages** (5 states): the Store Page banner, the review sheet, a new language’s tab, Hebrew added with its text accepted, and Review & Push with a page to create.
- **20 · Suggest Everything** (15 states): entry on Overview and in the Assistant popover, waiting, receiving on Overview, Store Page and Age Rating, finished, stopped, a per-area Ask still running, only an API key, no assistant, Age Rating never answered, and a version in review.
- **18 · New subscription** (9 states): the list, the sheet with recommended prices (light and dark), review later, can’t add yet, both added rows, reviewing recommendations later, Review & Push.

## 7 · Decisions the request left open

- **Accept All has no confirmation.** It’s safe because Review & Push stands between it and Apple, and Undo covers the batch.
- **Built-in suggestions work without an assistant**, so the feature is useful from day one, and the empty assistant slot explains what connecting adds.
- **One suggestion per field per source.** A new one from the same source replaces the old; different sources would show one at a time, newest first.
- **The base price is never preselected.** The suggestion is one click away, so accepting it is a decision, as with field suggestions.
- **“Later” means Apple’s prices are live meanwhile**, not a draft with no prices: a subscription can’t be submitted without prices.

## 8 · SwiftUI notes

- The suggestion is a view under the field in the same `Form` row, so it scrolls and reflows with it; `.accessibilityElement(children: .contain)` with the label “Suggestion for Subtitle from Claude Code”.
- Accept All is one undo group on the window’s `UndoManager`, so ⌘Z works as well as the toast.
- The Assistant button is a toolbar item with a `.popover`; status comes from the MCP server’s observable state.
- The setup is a sheet with a `NavigationStack` of four steps; the command is a selectable `Text` in a monospaced font with a Copy button.
- The price stepper is a `Stepper` over the fetched price points, not free text.

## 9 · Built since: subscriptions, starting price, In-App Texts, Confirm All

Board 38 draws it. What’s built is smaller than §5: it creates an app’s subscriptions with a US starting price and Apple’s equalized prices elsewhere. The recommended prices in §5 aren’t built yet.

**In the prototype.** Board 40 embeds the assistant prototype at these states: Quiet Timer (click it in the sidebar) with Create Subscription…, Ask Claude Code… and Set Starting Price; Store Page → In-App Texts with Ask Claude Code…; and Confirm All on Age Rating. The push’s refusal while App Review holds the texts is drawn on board 38 only.

### Create Subscription

- Pricing for an app with no subscriptions says so (*Quiet Timer has no subscriptions*) and offers **Create Subscription…**, **Ask Claude Code…** and **Open App Store Connect**. What’s queued is listed under it (*Waiting in Review & Push*), each with its product ID, *1 month · $2.99*, who made it and a discard button.
- The sheet: **Group** (an existing group or New Group, with reference and display names), **Subscription** (reference name, product ID, duration, Family Sharing), **On the App Store** (display name ≤30 and description ≤45 in the primary language), **Starting price** (the price in the United States, USD) and an optional App Review note. Each field counts its characters, and the notes say what can’t change later: the product ID, and Family Sharing once it’s on.
- Nothing is created until the push. The push creates the group if it’s new, the subscription, its texts, availability in every country or region, and the starting price. A retry finds what was already created and goes on from there. The review screenshot is added in App Store Connect.
- **Ask Claude Code…** asks the assistant for the subscriptions the app’s code sells. It reads `get_subscriptions` and sends each one with `propose_subscription`, citing the code as evidence. Each is checked like the sheet.

### Set Starting Price

- A subscription with no prices shows *<name> has no price yet* and **Set Starting Price…**. The sheet asks for the price in the United States. Every other country or region gets Apple’s equalized price, which can be changed in Pricing after the push.
- `propose_prices` with territory USA for a subscription with no prices becomes the same change.

### In-App Texts

- Store Page → In-App Texts has **Ask Claude Code…** in its action bar. It asks the assistant for the missing group names and subscription and purchase names and descriptions. The assistant reads `get_in_app_texts` and sends `propose_in_app_texts`, one text or a batch. Each text is checked like a cell edit (limit, empty, unknown column or locale, already changed by the person) and is either queued or refused with the reason.
- The push writes the texts into the subscription’s editable version, or a new draft version when there isn’t one. App Store Connect refuses new texts while version 1 is Waiting for Review. The push sheet says so in plain words (*Version 1 of these texts is Waiting for Review, so App Store Connect won’t take new ones yet…*), keeps the change, and offers **Retry Failed**.

### Age Rating · Confirm All

- When Claude Code has answered questions from the project, the banner says how many are not confirmed yet (*answered 7 questions from the project · 5 not confirmed yet*). **Confirm All** confirms each one, as if the person confirmed them one by one. Reject still works per question.

```
get_subscriptions(appId)                                  → groups, subscriptions, prices or “no prices yet”
propose_subscription(appId, group, groupDisplayName?, referenceName, productId, duration, displayName, description, price, familySharing?, reviewNote?, locale, evidence)
propose_prices(appId, product, territory: "USA", price)   // a subscription with no prices: Set Starting Price
get_in_app_texts(appId)                                   → locales × columns (group.name, <productId>.name, <productId>.description)
propose_in_app_texts(appId, locale, column, text | proposals: [{ locale, column, text }])
```

Sample data is illustrative: Lumen’s fields, commits, file names, review counts, prices and recommendations, and the tokens. The setup commands follow the clients’ documented formats; check them against current client versions before shipping.

References: [Claude Code and MCP](https://docs.anthropic.com/en/docs/claude-code/mcp) · [Model Context Protocol](https://modelcontextprotocol.io/) · [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions) · [Manage pricing for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions).

## Retention: a message and an offer when someone cancels

Pricing has two views now: **Prices** and **Retention**. Retention sits with the subscriptions because it belongs to them (which subscriptions a message covers, which offers it can show), not with the App Store page: people see it in Settings → Subscriptions, after they tap Cancel Subscription.

- **What Apple shows.** One message from the developer on the Confirm Cancellation screen, marked as coming from the developer, with Cancel Subscription and Keep Subscription always there. Three kinds: message only, message with an image, message with an offer. When someone is eligible for an offer, it replaces the image. Visible on iOS and iPadOS 15.1, macOS 14 and visionOS 1 or later.
- **Limits Atlas enforces.** Header 66 characters, message 144, per language. Up to 10 messages per app; one message can cover several subscriptions. Up to 10 retention offers per subscription. Images come from the Asset Library: PNG, 3840 wide and 160 to 2160 tall, no transparency, readable in light and dark.
- **Retention offers** are a new offer type (offerType 5 in transactions). You can attach several; Apple decides who is eligible and shows each person the best one.
- **Every language.** The message is written once and translated by Atlas like any other text; a language that runs over 144 is flagged, and Claude Code suggests a shorter version. The preview shows Apple’s own words in that language around your message, light and dark, right to left for Arabic and Hebrew.
- **Review & Push, then App Review.** Messages and offers are pushed with everything else, then Apple reviews them before subscribers see them. Test by canceling a sandbox subscription.
- **Advanced: real-time messages from your server**, folded away. With the Retention Messaging API (a separate server API that needs access from Apple), your server picks a message for each subscriber when they tap Cancel, can suggest switching plan within the group, or sign a promotional offer. It must answer within 700 ms and pass Apple’s performance test in the sandbox; otherwise Apple falls back to the messages set in App Store Connect, then to default messages. Atlas links to the access request and Claude Code can set up the endpoint.

### APIs

- **App Store Connect API 4.6** (the key Atlas already uses): retention messages, their versions and localizations, images, retention offers with prices, linking offers to subscriptions, and submitting a message version for review without an app version.
- **Retention Messaging API** (server to server, by request): upload images and messages, default messages per product and locale, the real-time URL, and the performance test.

Sources: Apple, [Retention Messaging API](https://developer.apple.com/documentation/retentionmessaging) and its [setup guide](https://developer.apple.com/documentation/retentionmessaging/setting-up-retention-messages); WWDC26 session 309, Explore Retention Messaging in App Store Connect.

## Ask Claude Code: the request goes to the toolbar · added November 18

Asking used to look like nothing happened. Now the request visibly travels from the button that was clicked to the assistant button in the toolbar, and that button shows work in progress until the suggestions arrive. Board 56, on the page *Proposta · Navegação*.

| Moment | The button that was clicked | The assistant button in the toolbar |
| --- | --- | --- |
| Before | ✦ Ask Claude Code… | Terminal icon, green dot: connected |
| The click, 0.68 s | Turns purple. A 26 pt purple token with the sparkle leaves its center | The token lands on it, shrinking to half and fading in the last 0.15 s |
| Working | “Claude Code Is Working…”, purple, and it can’t be pressed again | One purple ring spreads from it (0.9 s, once). Then “Working…” beside the icon and a purple dot that pulses every 1.1 s |
| Done | Back to Ask Claude Code… | Green dot again. A message says what was suggested and where |

- **The path is an arc:** the token moves up quickly and across slowly at first. Horizontal `cubic-bezier(.5, 0, .9, .6)`, vertical `cubic-bezier(.1, .7, .3, 1)`, both 0.68 s. In SwiftUI: a `matchedGeometryEffect` or a keyframe animation between the two frames, read with `GeometryReader` in the window’s coordinate space.
- **It starts wherever the button is.** The same from Store Page, In-App Events and Product Pages (Suggest Pages, Ask Claude Code for Ideas), near the toolbar or far from it.
- **One request at a time** for each app. While one is running the asking buttons say so.
- **Clicking the assistant button while it works** says what it is working on.
- **Reduce Motion:** no token and no pulse. The two buttons still change, at once.
- **VoiceOver** hears “Sent to Claude Code: Store Page, German. The assistant button in the toolbar shows it’s working.”
- **Color** is the purple of suggestions, because what comes back is a suggestion. Increase Contrast uses the darker purple and adds the outline the other buttons get.

Scenes: `ask-fly` `ask-work` `ask-done` `ask-cp` `ask-ev` `ask-s`. Not drawn: a request that fails, and several requests waiting.
