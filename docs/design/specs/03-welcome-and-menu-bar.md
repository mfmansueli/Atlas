ATLAS · WELCOME AND MENU BAR · NOVEMBER 2026

# The first minute, and the part of Atlas that never closes

A welcome screen that shows what Atlas is before it asks for a key, and a menu bar icon that keeps Atlas running, moves while it works, and says when it needs you.

**On the canvas** (page *Boas-vindas e barra de menus*): **Prototype — welcome**: Get Started → Connect → Reading your apps. **Prototype — menu bar**: click the Atlas icon to open and close its menu. Board **45** has the first run in every state; board **46** the menu bar. Board 45 replaces the old Connect screen (board 1), which was removed from *Estados*.

## Welcome

### The header is the icon, moving

The top half of the window is the icon’s own blue (`#1FC2FF` → `#0A5CF2`) with the mark drawn from the same seven layers as `Atlas.icon`. Nothing new is invented for it.

| What moves | How | Timing |
| --- | --- | --- |
| App tiles on the band | The three marks on the band become two groups of three rounded tiles that ride the band round the globe. A tile faces you at the front, narrows as the band curves away, and is a sliver when it reaches either end, so it slips behind the globe and comes back without a jump. Behind the globe it dims and the globe hides it. | One lap in 16 s at a steady pace. 8 s while Atlas reads your apps. |
| The globe | The meridian swings across the sphere, so the globe reads as turning. | 9.6 s each way, ease in and out. |
| The star | Rests, then glints when a group of tiles reaches the end of the band beside it: it swells by a third, turns 16°, and a soft glow opens behind it and fades. The apps arrive, the star answers. | Twice a lap (every 8 s): 2.4 s up, 2.9 s down, 2.7 s at rest. |
| The thin orbit | Still most of the time. Now and then it leans about 3° one way, drifts back through centre to 3° the other way, and settles, opening by a tenth while it moves. One continuous motion that starts and ends at zero speed: no stops, no bounce. The gap it cuts in the sphere moves with it. | Every 17 s, over 7.5 s. 17 s is deliberately out of step with the tiles and the star. |
| The whole mark | Floats 11 pt up and down. | 7 s each way. |
| Languages and prices | Eight places around the globe. Each shows a flag with the language’s own name (🇩🇪 Deutsch, 🇯🇵 日本語, 🇧🇷 Português…), pops in, stays, lifts away, and the next one takes its place. One in four is a price in the local currency (€ 4,99 · ¥ 800 · R$ 24,90 · £ 4.99 · ₩ 6,600 · ₹ 499 · $ 4.99 · kr 59). The places are out of step, so something is always changing but never all at once. Four hide below 900 pt of width. | Each chip: in 0.5 s, stays 3 s, out 0.5 s. A place shows four chips and one empty beat every 20 s; 10 s while reading. Each also drifts 14 pt, 6 s each way. |

**Reduce Motion:** the header is the still icon with eight languages around it. Nothing travels, turns, twinkles or changes.

**Flags:** the system’s flag emoji, paired with App Store Connect’s own locales (Portuguese is 🇧🇷 and 🇵🇹, Spanish 🇪🇸 and 🇲🇽, French 🇫🇷 and 🇨🇦), so a flag always means a storefront’s language, never “a language” in general. The chips are decoration: hidden from VoiceOver.

### The words underneath

*Rewritten November 22: fewer words, three sizes of text, so the first ten seconds say what Atlas is.*

- **Welcome to Atlas**, 32 pt bold.
- One line that says what Atlas does, 18 pt regular, in the main text color: “Your App Store page, right in every country.”
- One quieter line, 13 pt gray: “Words, screenshots and prices. Atlas suggests, you approve.”
- Three points, each a title and at most five words: **Every country, one place** “175 countries. Every language.” · **Suggestions, never surprises** “You say yes or no to each one.” · **Push when you’re ready** “Nothing goes live before that.” Below 680 pt of height they keep only their titles, and the quiet line hides.
- **Get Started** uses Liquid Glass, the system’s own material on macOS 26: build it with `.buttonStyle(.glassProminent)` tinted with Atlas’s blue and `.controlSize(.large)`, so the rim light, the depth and the way it swells under the pointer and squeezes when pressed come from the system, and Reduce Transparency and Increase Contrast are handled for free. The tint is a deep blue (about #0B63D6 to #0753BD) so the white label reads clearly. The prototype imitates the material in CSS: the deep blue, a thin light rim brighter along the top, a faint sheen on the upper half, a light shadow, and a slight swell on hover and squeeze on click; no glow around it; there is no periodic shine, as the system button has none. Check the exact API names against the current SDK. Under it: “You’ll need an App Store Connect key. It never leaves this Mac.”
- No jargon here: “storefront”, “API”, “Keychain” and “Review & Push” wait until the person meets them in the app.

### Connect, then reading

- **Connect** (rewritten November 22, then trimmed). Written for experienced developers and for people starting out alike: say why in one sentence, show the way in three steps, and reassure once.
  - “Step 1 of 2” · **Connect Atlas to your apps** · “Atlas needs a key from App Store Connect to see your apps and guide you through each step. You only do this once.”
  - **Before you start** · “Make a key in App Store Connect. About two minutes.” Then three numbered steps: Open **Users and Access**, then **Integrations** · Create a **Team Key** with **Admin** access · **Download** the key file. Apple shows it only once. Buttons: **Open App Store Connect**, **Show Me How**.
  - **Show Me How** opens the Atlas Help article “Get your App Store Connect key” in its own window, so it can stay open next to the browser while the person follows along (scene `connect-how`). Four steps, each with a picture of the App Store Connect page and an orange ring around what to click: Users and Access → Integrations; Team Keys, + and Admin; Download; where the Issuer ID and Key ID are. Then one tip for people who don’t see Integrations. The pictures in the prototype are drawings; the app will use real screenshots with personal data blurred, bundled with the app like the other Help articles.
  - **Then paste it here** · “Three things from the page where you made the key.” Issuer ID (top of the page), Key ID (next to your key), Key file (the file you downloaded). A green check on each when it looks right; the file area turns green when the key is dropped.
  - One line under both: “Your key stays on this Mac. Atlas never changes anything without your OK.” Then Back and Connect; Connect waits for all three.Below 680 pt of height the explanatory lines hide and only the steps and fields stay; below 900 pt of width the hints next to the field names hide. The path to make a key and the role name are written from memory: confirm them against App Store Connect before shipping.
- **Reading your apps…** brings the large header back with the tiles at double speed, counts apps as they are read, and says that nothing is changed in App Store Connect.
- The errors from the old Connect screen (key refused, offline) keep their wording and sit under the fields.

## Menu bar

### Atlas keeps running

- Closing the window does not quit Atlas. Pushes and Autopilot finish; Atlas keeps checking for reviews, Apple’s answers and analytics reports.
- The first time, a note under the icon says so, with **Got It** and **Quit When I Close the Window** (which turns the setting off).
- **Quit Atlas** (⌘Q, or in the menu) really quits. If a push is running, Atlas asks first: Quit After the Push, Quit Now, Cancel. A push stopped halfway is listed in Review & Push next time.
- Clicking the Dock icon, or **Open Atlas** in the menu, brings the window back where you left it.

### The icon

| State | Looks like | When |
| --- | --- | --- |
| Idle | Globe and band, still. | Nothing running, nothing waiting. |
| Working | The band dims and a bright stretch sweeps round the globe, thinner and dimmer behind it. One lap in 2.6 s. | A push, Autopilot, Suggest Everything, a check with Apple, a screenshot capture. |
| Needs you | A dot at the top right. | A choice Autopilot is waiting on, suggestions to accept, a version approved for manual release, reviews with suggested replies. |
| Paused | Dimmed, with a pause mark. | You chose Pause Background Work. |
| Can’t connect | A stroke across it. | The key was refused, or Apple can’t be reached. |

Working wins over Needs you while something runs; the dot comes back when it stops. Finishing has no animation of its own. With Reduce Motion, or with the setting off, Working is a still icon with the bright stretch at the front.

### The menu

1. **Running now**: each job with a bar, how far it is, and about how long is left. Or “Everything is up to date” with the last and next check.
2. **Needs you**: each line opens Atlas at that place.
3. Open Atlas ⌘O · Review & Push… (with its count) · Check Now ⌘R · Pause Background Work
4. Settings… ⌘, · Quit Atlas ⌘Q

### Settings · General

| Setting | Default | Notes |
| --- | --- | --- |
| Show Atlas in the menu bar | On | Off also turns off “Keep running”, since there would be no way back in. |
| Keep running when the window is closed | On | Off: closing the window quits Atlas once nothing is running. |
| Show in the Dock | Only while a window is open | Or Always. |
| Animate the menu bar icon while working | On | Follows Reduce Motion. |
| Open Atlas at login | Off | Starts in the menu bar, with no window. |
| Check App Store Connect | Every hour | Every 15 minutes, every hour, every 6 hours, only when I ask. |

## Building it

- **Status item:** `NSStatusItem` (or SwiftUI `MenuBarExtra`) with a template image, so macOS tints it. The working loop is 8 template frames swapped on a timer, about 3 a second; they are drawn on board 46.
- **Staying alive:** return `false` from `applicationShouldTerminateAfterLastWindowClosed`. For “Dock: only while a window is open”, switch the activation policy between `.regular` and `.accessory`.
- **Login:** `SMAppService.mainApp`.
- **Welcome header:** the layer SVGs in `camadas-svg` are enough: tiles follow the band’s ellipse (440 × 130, turned −24°) with their width following the sine of the angle, the meridian scales on x inside the sphere’s clip, the star and its glow scale about the star’s centre. Honour `accessibilityReduceMotion`.

**Not checked:** how often App Store Connect lets a key poll before rate limits bite. “Every hour” is a safe design default; the 15-minute option needs testing against the real limits.

## Prototype scenes

`welcome` `welcome-still` `connect` `connect-filled` `checking` · `mb-closed` `mb-running` `mb-needs` `mb-quiet` `mb-working-closed` `mb-settings` `mb-glyphs` in `Welcome.dc.html`.
