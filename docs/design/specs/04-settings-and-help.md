ATLAS · SETTINGS AND HELP · NOVEMBER 2026

# Settings in one window, and help that takes you there

Settings redrawn in the current design, with everything added since the first version. Atlas Help written as short tasks, each with a button that opens Atlas at the right place.

**On the canvas** (page *Ajustes e Ajuda*): two prototypes, both clickable. Board **48** has every Settings pane and state; board **49** has Help. They are also boards 4 and 5 on *▶ App clicável*. Boards 10 and 14 on *Estados* (the old Settings) were removed.

**Update, November 22.** **Settings is now in the sidebar**, above the version, with a gear and ⌘, beside it; the Atlas menu keeps its Settings… item. In *▶ App clicável*, clicking it opens this window over the app.  
**Connecting an assistant no longer asks for anything technical.** AI Assistants lists the assistants found on this Mac (Claude Code, Claude for Mac, Cursor), each with **Connect**. Atlas adds itself to the assistant, waits for it to answer and checks that it can read the app, showing the three steps as they pass. A connected assistant offers **Send a Test Suggestion**. “Local server”, the address and “Pair Assistant…” moved under **Advanced**, with the one line to paste for any other assistant. “Revoke” is now “Disconnect…”, asked in place. New states on board 48: nothing connected yet, connecting, just connected, Advanced.  
**To check before building:** where each assistant keeps its MCP settings and whether Atlas can write there from the App Sandbox (it may need the person to choose the folder once), and how to detect that an assistant is installed. Written from what is known today; confirm against each assistant’s documentation.

**Update, November 22 (2): a guided connection.** **Connect** on an assistant now opens a sheet with three steps.  
**1 · Project folder.** “Where is Lumen Journal’s project?” A large area takes the folder by drag and drop (from Finder, or from the title of the Xcode window); Choose Folder… does the same; and Atlas offers the folder it found on this Mac with Use This Folder. Atlas then checks that the folder has the Xcode project and that its bundle ID is this app’s, and says the assistant may read it and can’t write to it. A wrong folder says what is missing. Connect Without a Project stays possible: the assistant then only reads the App Store data.  
**2 · Connect.** Atlas adds itself to the assistant, starts it in the folder and waits for its first message, showing each step. Nothing to type or copy.  
**3 · Say hello.** The assistant’s own first message arrives in Atlas: what it sees (version, languages, subscriptions), what it read in the project, and an offer. It proves the connection works in words anyone understands. Below it: three things to ask, and Ask for a First Suggestion.  
**If it doesn’t answer** after 30 seconds: the usual reasons, each with its button (Restart and Try Again, Open the assistant, Open Help).  
**For Claude Code:** the hello is a real call. After connecting, Atlas sends the assistant one prompt (“Read the app with the atlas tools and the project folder, and introduce yourself in three short sentences”) and shows the reply; it is not canned text. The folder is saved per app and per assistant as a security-scoped bookmark, and Atlas suggests one from Xcode’s recent projects whose bundle ID matches. Scenes: `set-wiz-folder` `set-wiz-drag` `set-wiz-picked` `set-wiz-wrong` `set-wiz-busy` `set-wiz-hello` `set-wiz-fail`.

## Settings

Opened with ⌘, from the Atlas menu or the menu bar icon. A sidebar with nine panes, like the main window, instead of toolbar tabs: nine tabs no longer fit, and the sidebar can be searched.

| Pane | What’s in it | Where it came from |
| --- | --- | --- |
| General | Appearance · menu bar and Dock · how often to check App Store Connect · confirmations before pushing | Old General, plus the menu bar settings from board 46 |
| Accounts | App Store Connect keys with their role and what it can’t do · vendor numbers · a link to Analytics’ reports | Old Account. The vendor number is also still in Analytics settings |
| AI Assistants | Where suggestions come from (assistant, API key, built-in) · the local server · paired assistants · what they may suggest and never can · Claude Design projects · activity | Old AI Assistants and its pairing board, plus the provider choice from old Translation |
| Suggestions | Source language, tone, words never translated · Atlas’s own checks · accepting · what is never accepted for you | Old Translation’s glossary and defaults; “accept right away” from the Store Page |
| Pricing | Defaults for new apps · prices by country · price data · Apple’s commission | Old Pricing, with plainer labels |
| Screenshots | The Simulator · Autopilot’s stops · artwork defaults | New. These were scattered in Autopilot’s plan |
| Notifications | Whether macOS allows them · what to hear about · sound, menu bar dot, Dock count | New |
| Atlas Pro | The plan and its renewal · what it includes, with what Free does instead · Restore Purchases | New |
| Privacy & Data | What leaves this Mac, by destination · sharing with the developer (off) · what is kept here · remove everything | New |

### Rules

- **Changes apply at once.** No Save button. A switch or a menu takes effect when it changes.
- **Every switch says what it does when it isn’t obvious**, in one line under its name.
- **Limits are said where they bite.** A key whose role can’t read sales says so on the key, and its vendor number field is off with the reason.
- **Destructive actions ask in place.** Removing a key opens a red panel on that key that says exactly what is lost and that nothing changes in App Store Connect.
- **What Atlas will never do is shown as locked rows**, not left out: assistants never push or accept; prices, privacy answers, the age rating and compliance are never accepted for you.
- **Sections that don’t apply go away.** With an API key or built-in only, the server and pairing sections are hidden.
- **A problem outside Atlas is at the top of its pane.** If macOS blocks notifications, the pane says so first, with the button that fixes it.
- Per-run and per-event choices still win. Screenshots’ switches are defaults.

### Renamed, for plain words

| Before | Now |
| --- | --- |
| Local MCP server | Let assistants connect |
| Base territory | Base country |
| Default source · World Bank PPP price level | Based on · World Bank price levels |
| Intensity | Strength |
| Discount only | Only lower prices |
| Glossary · never translated | Never translated |

## Atlas Help

A window of its own (⌘?), so it can stay open beside Atlas. A sidebar with search and every article; the home page has four articles to start with, the rest by group, and a way to write to support.

### The 19 articles

| Group | Articles |
| --- | --- |
| Start here | What Atlas does · Connect App Store Connect · How suggestions work · Review & Push |
| Store listing | Store Page in every language · Screenshots and Autopilot · Product pages for an audience · In-App Events and their artwork · App Information, privacy and compliance · Pricing by country |
| After release | Submit for Review and release · Reply to reviews · Analytics |
| Atlas | Connect an AI assistant · The menu bar icon · Atlas Free and Atlas Pro · Your key and your data · Keyboard shortcuts · Fix a problem |

All 19 are written in full in the prototype, and are the text to ship.

### How an article is written

- **The title is the task** or the thing, in the words used in the app.
- **One sentence first** that answers the question by itself.
- **Steps are numbered and short**, four at most, with the button’s exact name in bold.
- **One note** for the thing people worry about: where the key is kept, what is Pro, what is never accepted.
- **Show Me** opens Atlas at that place. Help stays open and says what it opened.
- **Related** has two or three articles, never a long list.

### Search

- Looks in titles, first sentences and a few keywords per article, on this Mac. Results say which group they are in.
- No results says so and points to Contact Support.
- The home page offers four searches to try.

### The Help menu

Search · Atlas Help ⌘? · Keyboard Shortcuts · What’s New in Atlas · Connect App Store Connect · Fix a Problem · App Store Connect System Status · Contact Support… · Send Feedback…

### From inside the app

Not drawn yet: a small ? beside a section’s title opens that section’s article, and error messages link to *Fix a problem* at the right heading.

## New shortcuts

Two are new with this work: `⇧⌘P` for Review & Push and `⌘?` for Atlas Help. The rest were already in the design.

## Building it

- **Settings:** a SwiftUI `Settings` scene with a `NavigationSplitView`, one view per pane. Search filters panes by the words on them.
- **Help:** a normal window with the articles bundled as Markdown, so search is local and Show Me can call the same deep links the menu bar uses. An Apple Help Book could not open Atlas at a place.
- **Notifications’ status:** read from `UNUserNotificationCenter`’s settings each time the pane opens.

**To check before shipping:** the path to make a key in App Store Connect (Users and Access → Integrations → App Store Connect API → Team Keys) and the role names are written from memory; confirm them against the site, since Apple moves these. Prices and plan names in the Pro article come from README — Monetization and must change with it.

## Prototype scenes

`Settings.dc.html`: `set-general` `set-accounts` `set-accounts-remove` `set-assistants` `set-assistants-off` `set-assistants-key` `set-assistants-none` `set-suggestions` `set-pricing` `set-shots` `set-notif` `set-notif-blocked` `set-pro` `set-free` `set-privacy`

`Help.dc.html`: `help-home` `help-connect` `help-suggest` `help-events` `help-assistant` `help-menubar` `help-pro` `help-keys` `help-fix` `help-search` `help-search-none` `help-shown` `help-menu`
