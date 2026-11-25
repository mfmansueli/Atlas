---
id: shots
group: listing
title: Screenshots and Autopilot
summary: Screenshots for every device and language, from templates or from a new look by Claude.
keywords: screenshots, screenshot, by hand, replace, delete, reorder, upload, import, folder, fastlane, autopilot, template, templates, caption, captions, app preview, video, header, simulator, xcode, claude design, device
showMe: section:screenshots
related: events, assistant
---
Each set is a template plus your app’s screens plus a caption per language. Change the caption and every device follows.

## Autopilot

1. Say what to make: screenshots, an App Preview, header artwork.
2. Choose the look.
3. Check the plan and start it. Atlas captures your app in the Simulator, designs, and writes every language.
4. Come back twice: to choose the look, then to approve. **Approve All** moves the screenshots, App Previews and header art to Review & Push and closes Autopilot.
5. Push them from **Review & Push**, like everything else. Autopilot never pushes by itself.

No simulator for a device? If Xcode knows it and the runtime is installed, Atlas makes one, in any run. Otherwise its card asks you to download a runtime (several GB, Install), save a helper again, or see why Xcode couldn’t make it.

> Autopilot needs Xcode on this Mac and an assistant connected. It is part of Atlas Pro.

## Redo only some captures

When some screens changed (new phrases in one language, a redesigned screen), you don’t need a whole new run.

1. Open Screenshots → Captures. ⌘-click captures, or click a language’s name or a screen’s column to choose all of them.
2. Choose Replace… to put in a PNG of your own, or drop one on the capture. It must be that device’s full-size screenshot.
3. Or choose Capture Again with Claude Code to redo only those captures. Plan, look and captions stay; Review & Push sends only changed images.

- Claude Code can ask for it too. Its request shows in Screenshots with Accept and Decline.
- No saved Autopilot run? It’s rebuilt from the set’s captures: screens, devices, iPhone Duo poses and sizes. Only App Preview moments need the original run.
- Captures Claude Code marked as Out of date keep that label until a new one takes their place.
- To let Claude Code open these runs without asking, turn on Settings → Screenshots → Let Claude Code open capture-only runs. Nothing is sent either way.

> A product page’s screens can be captured again the same way, up to three a page.

## Screenshots by hand

No Autopilot or assistant needed: open a language in Screenshots, pick the device, and edit. Every change waits in Review & Push, with Undo.

1. Click a screenshot to select it; the bar above shows its source. Use ◀ ▶ to move it, Replace…, Delete…, or Undo Change.
2. Click the Add Screenshots tile or drop PNG or JPEG files on it, to add them after the last one. A set holds up to 10.
3. Manage has Add Screenshots…, Import a Folder… and Delete All in that language.

- Replace and Delete work in that language only, or in every language that has its own screenshots.
- A file that replaces a template screenshot isn’t redrawn when the template or caption changes. Undo Change brings the template version back.
- A language without screenshots of its own shows the primary language’s. Start from English (U.S.) copies them in, ready to replace one by one, or Add Its Own… starts fresh.
- Import a Folder reads fastlane-style folders by language (de-DE/iphone-6.9/01.png). Device comes from the name or image size, order from the leading number. A table previews each language’s changes first.
- The primary language must keep at least one screenshot on each device: Apple needs it.
- Claude Code can suggest a file, deletions or a new order, with a reason, on the language page. Accept queues it in Review & Push. Deleting or moving a template screenshot affects only that language.

> Atlas never scales screenshots. Files must match a device size (iPhone 6.9″ 1320 × 2868 or 1290 × 2796, iPad 13″ 2064 × 2752 or 2048 × 2732, Mac 2880 × 1800, 2560 × 1600, 1440 × 900 or 1280 × 800), either way round, with no transparency. Pushes add new screenshots before deleting old ones, so a failure never leaves a language short.
