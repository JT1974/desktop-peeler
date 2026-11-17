# Desktop Peeler – product documentation

Version described: 1.0 (build 1), source state of 2026-11-16. Bundle ID `hu.presoft.desktoppeeler`. Minimum macOS 12.0. Product page: https://presoft.hu/desktop-peeler

**Purpose of this file.** It is the single reference for (a) the product page on presoft.hu, (b) the in-app help and About window, and (c) store listing and submission material. Sections 1–5 describe what the app does today and are the source of truth for any copy. Section 6 is the in-app help text. Section 7 is the About content and the visual identity. Section 8 covers distribution (download from the product page only) and why the Mac App Store is not used. Section 10 is the material for the product page: key messages and the screenshots in `screenshots/`.

**Verification status.** Built with `build.sh` and `make-dmg.sh` on the owner's iMac (Intel, macOS 26, Command Line Tools) as a universal app (Intel and Apple chips in one app). Run and checked on Intel only; the Apple-chip part compiles and is in the app, but has not been run on an Apple-chip Mac. Checked in the running app (Hungarian, dark theme): every pane, the cleanup approval sheet with Cancel, Select all, the process descriptions, Settings, Help and the About window. Not yet tried in real use: a cleanup that empties the Trash, a remembered approval running without the sheet, revoking a macOS permission, adding a language file. Items marked **[CONFIRM]** need a decision or a fact from the owner (János).

---

## 1. Product summary

Desktop Peeler is a native macOS utility that finds removable files (caches, logs, temporary files and similar), lists programs that start automatically, checks for a few kinds of leftovers and inconsistencies, and offers a small set of maintenance commands. Its defining rule: nothing changes until the user has seen an explicit list (every file with its size and path, every login item, or the exact command) and approved it. Files are moved to the Trash; after a cleanup the Trash is emptied too, unless the user unticks "Empty Trash afterwards".

The window has a top bar (app icon, name, theme switch), a sidebar and a status bar ("Ready" or the task in progress). The sidebar has five tool panes (Cleanup, Auto-start, System checks, Optimize, Activity log) and, at the bottom, Settings and Help. Settings also opens with ⌘, and Help with ⌘?; the About window is in the app menu.

The app speaks English and Hungarian and follows the Mac's language by default; further languages can be added as files. It follows the Mac's light or dark appearance by default.

The app collects no data, has no account, no network features, no analytics, no ads and no background component. It does nothing when it is not open.

---

## 2. Features in detail

### 2.1 Cleanup

The header reads "Step 1 · grab, step 2 · peel". The user presses **Scan** (later **Scan again**). Scanning only reads. The result is a list of categories; each shows the number of items and total size and can be opened (arrow on the right) to show every item. Items are sorted largest first. Each item has a magnifying-glass button that reveals it in Finder, and its full path is shown as a tooltip. Items of zero size and `.DS_Store` files are not listed.

| Category | What is scanned | Preselected | Admin password |
|---|---|---|---|
| Application caches (your account) | Every entry in `~/Library/Caches` | Yes | No |
| Log files (your account) | Every entry in `~/Library/Logs` (includes crash reports) | Yes | No |
| Temporary files | Entries in the user's temporary folder not modified for more than 2 days | Yes | No |
| Xcode build data | Entries in `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/Xcode/iOS DeviceSupport`, `~/Library/Developer/CoreSimulator/Caches` | No | No |
| Developer tool caches | `~/.npm/_cacache`, `~/.gradle/caches`, `~/.node-gyp`, `~/.android/cache` (each as one item) and every entry in `~/.cache` | No | No |
| Old installers in Downloads | `.dmg`, `.pkg` and `.zip` files in `~/Downloads` not modified for more than 30 days | No | No |
| System-wide caches | Every entry in `/Library/Caches` | No | Yes |
| System-wide logs | Every entry in `/Library/Logs`; files ending `.gz`, `.bz2`, `.old` in `/private/var/log` | No | Yes |

A category checkbox selects or clears all its items; item checkboxes work individually. The footer shows "Selected: N items · size", the **Empty Trash afterwards** checkbox (ticked by default) and **Review & clean…**, which opens the approval sheet (section 3). On approval the items are moved to the Trash; if Empty Trash afterwards is ticked, Finder then empties the whole Trash, including items that were already in it. After a cleanup the app scans again automatically.

Consequences copy should state plainly: apps rebuild their caches, so the first launch after cleaning can be slower and the freed space partly returns; removing Xcode build data makes the next build slower; developer tool caches are downloaded again on demand; emptying the Trash is permanent.

### 2.2 Auto-start

The user presses **Load list** (later **Refresh**). Four groups are shown:

| Group | Source |
|---|---|
| Login item | The user's login items, read through System Events |
| Launch agent (your account) | `.plist` files in `~/Library/LaunchAgents` |
| Launch agent (all users) | `.plist` files in `/Library/LaunchAgents` |
| Launch daemon (system) | `.plist` files in `/Library/LaunchDaemons` |

Each row shows the name (the launch item's label), the program path, and an outlined "program missing" label when that program no longer exists. Nothing is preselected.

**Remove selected from auto-start…** opens the approval sheet. On approval, login items are removed from the login-items list, and launch agent/daemon `.plist` files are moved to the Trash (this never empties the Trash). The applications themselves are not uninstalled. Changes take effect at the next login or restart; a program that is already running keeps running until then. A launch item can be restored by putting its `.plist` back from the Trash.

**Open Login Items in System Settings** opens the macOS settings pane, for background items the app cannot manage (section 4).

### 2.3 System checks

The user presses **Run checks** (later **Check again**). Checking only reads. Nothing is preselected; **Select all (N)** at the bottom ticks or clears every finding at once. Results:

- **Startup disk** – volume name, file system, SMART status and free/total space, taken from `diskutil info /`. A button **Verify disk structure (read-only)** runs `diskutil verifyVolume /` and shows its output. It repairs nothing; repairs are done with Apple's Disk Utility. The Mac can feel slow while verification runs.
- **Startup entries pointing to missing programs** – launch agents/daemons whose program path no longer exists (typical leftovers of uninstalled apps).
- **Broken symbolic links** – links whose target is gone, in `/usr/local/bin`, `/opt/homebrew/bin`, `~/.homebrew/bin`, `~/.local/bin`, `/Applications`, `~/Applications`.
- **Preference files of apps that seem to be uninstalled** – `.plist` files in `~/Library/Preferences` for which no installed app from the same vendor was found. This is a heuristic (section 4); each entry should be reviewed.

**Fix selected…** opens the approval sheet; approved files are moved to the Trash (never emptied), then the checks run again.

### 2.4 Optimize

Four actions, each with a **Run…** button that opens the approval sheet showing the exact command:

| Action | Command | Admin password | Effect |
|---|---|---|---|
| Flush DNS cache | `dscacheutil -flushcache; killall -HUP mDNSResponder` | Yes | Clears cached network name lookups |
| Free inactive memory | `purge` | Yes | Releases disk cache held in memory; temporary effect |
| Reset Quick Look cache | `qlmanage -r cache` | No | Clears thumbnail/preview caches; rebuilt on use |
| Rebuild Spotlight index | `mdutil -E /` | Yes | Erases and rebuilds the search index; search is incomplete and the Mac busier until indexing finishes |

Below the actions is a read-only list of the 15 processes using the most memory, with CPU percentage, and a **Refresh** button. Pointing at a process shows what it does and its full path:

- about 50 well-known macOS processes and Apple apps have their own description (for example WindowServer: "Draws everything on screen: windows, menus, the Dock and animations.");
- a process inside an app bundle is described as "Part of the app “X”" (for example browser helper processes);
- other processes under `/System`, `/usr`, `/bin`, `/sbin` are "A macOS system component", those under `/Library` or `/opt` "A background program installed by another app or tool".

The app cannot quit processes.

Copy must not promise speed gains. These are troubleshooting actions: they help with specific symptoms (wrong DNS results, broken previews, broken search), not general performance.

### 2.5 Activity log

A timestamped list of every change made since the app was opened: each file moved to the Trash, each Trash emptying, each login item removed, each command run, each permission revoked, and each failure. The log is kept in memory only and is cleared when the app quits.

### 2.6 Settings

A sidebar pane (also ⌘,) with four cards:

- **Theme** – Same as macOS (default), Dark, Light. The three-way switch in the top bar changes the same setting. Saved between launches.
- **Language** – "Same as macOS (…)" (default: the Mac's language if a translation exists, otherwise English), or any installed language. **Add language file…** installs a translation file; **Save English template…** saves the file a translator starts from; added languages are listed with a **Remove** button. See 2.8.
- **Remembered approvals** – every kind of action the user approved with "Don't ask again" (section 3), each with a **Revoke** button. Possible entries: Move cleanup items to the Trash; Empty the Trash after a cleanup; Remove items from auto-start; Move system-check findings to the Trash; each Optimize action separately.
- **macOS permissions** – what macOS currently allows the app, read without making macOS ask, with a **Refresh** button:

| Permission | Status shown | Revoke… | System Settings |
|---|---|---|---|
| Control System Events and Finder | Allowed / not allowed / not asked yet / unknown, for each of the two | Resets both through `tccutil reset AppleEvents` (macOS cannot reset only one), via the approval sheet | Opens Privacy & Security › Automation, where each can be switched off on its own |
| Downloads folder | – (macOS gives no way to read it without asking) | `tccutil reset SystemPolicyDownloadsFolder`, via the approval sheet | Opens Files and Folders |
| Full Disk Access (optional) | Allowed / not allowed | – (granted and taken back only in System Settings) | Opens Full Disk Access |

  A note explains that the administrator password is asked by macOS every time and never stored, so there is nothing to revoke. After a revoke, macOS asks again the next time the permission is needed.

### 2.7 Help and About

**Help** is a sidebar pane (also ⌘? and the Help menu) with these topics: Getting started, Cleanup, Auto-start, System checks, Optimize, Activity log, Settings, Adding a language, Frequently asked questions, and an About card with the product page link. Text: section 6.

**About Desktop Peeler** (app menu) opens the standard macOS About window: icon, name, version, the tagline, the short description and a clickable link to presoft.hu/desktop-peeler, then the copyright line. Content: section 7.

### 2.8 Languages

English and Hungarian are built in (`Resources/Languages/en.json`, `hu.json`). Each language is one JSON file:

```json
{ "code": "de", "name": "Deutsch", "strings": { "Cleanup": "Bereinigung", "...": "..." } }
```

The key on the left is the English text, the value is the translation; placeholders such as `%d` and `%@` must stay. Missing texts stay in English. Added files are copied to `~/Library/Application Support/Desktop Peeler/Languages/`; a file with the same code as a built-in language replaces it. The language can be changed while the app runs.

### 2.9 Installation

`make-dmg.sh` produces `build/DesktopPeeler-1.0.dmg` (about 1.4 MB). The app in it is universal: it runs natively on Intel and Apple-chip Macs, without Rosetta. The user opens it and drags Desktop Peeler onto the Applications shortcut. The app is only ad-hoc signed for now: on a Mac other than the one that built it, macOS blocks the first launch until the user allows it in System Settings › Privacy & Security › Open Anyway. Signing and notarization need an Apple Developer ID (section 8.2). The `.dmg` is offered only on the product page, behind the download confirmation (section 10.5). Uninstalling: drag the app to the Trash; its settings are in `~/Library/Preferences/hu.presoft.desktoppeeler.plist` and added languages in `~/Library/Application Support/Desktop Peeler/`.

---

## 3. Approval rules

These rules are the core promise of the product and must appear in help, About, the product page and store copy without being weakened.

1. **Scans and checks only read.** Scan, Load list, Run checks, Verify disk and Refresh change nothing.
2. **Every change goes through the approval sheet.** The sheet shows a title, an explanation, and the complete list of what will happen: each file with its size and full path, each login item, or the exact command. It has **Cancel** and a confirm button whose label states the action (for example "Move 42 items to Trash and empty it").
3. **"Don't ask again" is the user's choice and can be taken back.** The sheet has a "Don't ask again for this kind of action" checkbox. If ticked, that kind of action later runs without waiting; the sheet still opens, says it was approved automatically, lists what is being done and shows the result. Every remembered approval is listed in Settings and can be revoked one by one. Revoking a macOS permission never offers this checkbox.
4. **Nothing happens on Cancel.** Closing the sheet without confirming leaves the Mac unchanged.
5. **Files go to the Trash; emptying it is a visible, separate choice.** Cleanup has "Empty Trash afterwards", ticked by default. When ticked, the sheet says that the whole Trash, including what was already in it, will be emptied permanently, and lists it as the last line. Unticked, items can be put back until the user empties the Trash. Auto-start removal and System-check fixes never empty the Trash.
6. **Only what was listed is touched.** The work performed is exactly the list shown at review time.
7. **Administrator rights are requested by macOS, per action.** Protected files are handed to Finder, which shows its own password prompt; admin commands use the standard macOS password dialog. The app never sees or stores the password and keeps no elevated rights afterwards.
8. **Failures are reported, not hidden.** After the work the sheet shows the result. Anything that could not be removed is listed with a "▲" mark as "COULD NOT REMOVE (left untouched)" and stays where it was.
9. **Risky categories are not preselected.** Only the three low-risk categories (user caches, user logs, old temporary files) are ticked after a scan. Nothing is ticked in Auto-start or System checks.
10. **Everything is logged** in the Activity log for the session.

---

## 4. Limits and known behaviour

- **Background items registered directly with macOS** (System Settings › General › Login Items, "Allow in the Background") cannot be listed or removed by the app. The app offers a button that opens that settings pane.
- **Apple's own system launch items** (in `/System/Library`) are not listed and cannot be changed.
- **The orphaned-preferences check is a guess.** It compares the first two parts of the file name (for example `com.vendor`) with the bundle IDs of apps found in `/Applications`, `/System/Applications`, `~/Applications`, the Application Support folders and preference panes. It can flag files of command-line tools or apps installed elsewhere. Removing such a file resets that app's settings; it can be put back from the Trash.
- **Some items cannot be removed.** macOS protects certain files (System Integrity Protection, privacy protection). They are reported as failures and left in place.
- **Emptying the Trash is permanent and covers the whole Trash.** The app does not scan or size the Trash, and cannot empty only its own items.
- **Caches come back.** Cleaning is not a one-time permanent gain.
- **Without Full Disk Access some folders are invisible** to the app, so the scan can be incomplete. The app works without it.
- **Disk verification is read-only**; the app repairs nothing on the disk.
- **Open apps:** removing the cache or temporary files of an app that is running can make that app misbehave until it is restarted. Help recommends quitting other apps before a cleanup.
- **Permissions:** macOS resets the System Events and Finder automation permissions only together; one at a time only in System Settings. The Downloads-folder permission state cannot be read without macOS asking, so no status is shown for it.
- **Ad-hoc signature:** macOS may ask again for permissions after the app is rebuilt, because the signature changes with every build.
- **Not included:** uninstalling apps, duplicate finder, large-file finder, browser history/cookie cleaning, malware scanning, scheduled or automatic cleaning, memory "boosting" in the background, quitting processes.
- **Saved between launches:** theme, language, remembered approvals. Not saved: scan results, selections, the Activity log.

### Permissions macOS may ask for

| Prompt | Why | If declined | Revoke |
|---|---|---|---|
| Control "System Events" | Read and remove login items | Login item group stays empty; launch agents/daemons still listed | Settings › macOS permissions |
| Control "Finder" | Move protected files to the Trash with the admin password; empty the Trash | Those files are reported as not removed; emptying fails and is reported | Settings › macOS permissions |
| Access the Downloads folder | "Old installers in Downloads" category | That category shows nothing | Settings › macOS permissions |
| Administrator password | System-wide items and three Optimize actions | The action fails and is reported | Nothing stored |
| Full Disk Access (optional, set manually) | More complete scan | Scan covers what is readable | System Settings |

---

## 5. Technical notes

| File | Content |
|---|---|
| `Sources/Core.swift` | Logic, no UI: scanning, Trash removal and emptying, startup items, system checks, optimize actions, process descriptions, permission checks |
| `Sources/AppState.swift` | Observable state; `ActionFlow` is the approval flow (review → working → done); remembered approvals |
| `Sources/Views.swift` | App, menu commands, sidebar (`Pane`), tool panes, approval sheet |
| `Sources/SettingsView.swift` | Settings pane |
| `Sources/HelpView.swift` | Help pane and About window |
| `Sources/Localization.swift` | `L()` / `N()` lookup, language file loading, import and removal |
| `Sources/Theme.swift` | Brand colours, fonts, buttons, checkbox, cards, theme switch |
| `Resources/Languages` | `en.json` (generated template), `hu.json` |
| `tools/update-language-template.py` | Rebuilds `en.json` from the sources and lists texts missing from other language files |
| `build.sh` / `make-dmg.sh` | Build the universal app (x86_64 and arm64, joined with `lipo`) / build the app and the disk image |

- Any feature that changes the system must create an `ActionFlow` and let the approval sheet run it. Do not add a code path that changes files or settings outside this flow.
- Every user-facing text is wrapped in `L("…")` (or `N("…")` for texts stored as data and translated where shown). After adding or changing texts run `python3 tools/update-language-template.py` and add the Hungarian translations it reports as missing.
- A privacy-policy link must be reachable inside the app if it is ever submitted to the App Store (guideline 5.1.1(i)). It is not there yet.

---

## 6. In-app help content

This is the English text shown in the Help pane (`Sources/HelpView.swift`); the Hungarian version is in `Resources/Languages/hu.json`. Change both together.

**Header:** Desktop Peeler first looks, then shows you a list and waits. Nothing is changed until you approve that list.

### Getting started

Desktop Peeler helps you remove files your Mac no longer needs and shows you what starts automatically. It works in two steps everywhere: first it looks, then it shows you a list and waits. Nothing is changed until you approve that list.

For the first cleanup: quit your other apps, open Cleanup, press Scan, open the categories to see what was found, press Review & clean…, read the list, then confirm.

### Cleanup

Scan looks for caches, logs, temporary files and similar data and groups them into categories. Three low-risk categories are ticked for you; the others are left for you to decide. Click the arrow on a category to see every item, and the magnifying glass to see an item in Finder.

Review & clean… shows every selected item with its size and location. Confirm to go ahead, or Cancel to change nothing. Categories marked "admin password" contain files shared by all users; Finder will ask for your password for those.

Empty Trash afterwards is ticked by default: after the items are moved to the Trash, the whole Trash is emptied, including anything that was already in it. Emptying is permanent. Untick it if you want to be able to put items back.

After cleaning, apps recreate their caches as they need them, so some apps open a little slower the first time and part of the space is used again over time.

### Auto-start

This pane lists programs that start by themselves when you log in or when the Mac starts. Tick the ones you want to stop and press Remove selected from auto-start…. The programs stay installed; they simply no longer start automatically. The change applies from your next login or restart.

A "program missing" badge means the entry points to a program that no longer exists; such entries are safe candidates for removal.

Some apps register background items directly with macOS. Those can only be switched off in System Settings › General › Login Items; use the button at the bottom to go there.

### System checks

Run checks looks for startup entries whose program is gone, shortcuts (symbolic links) that point nowhere, and settings files of apps that seem to be uninstalled. It also shows the health and free space of your startup disk. Nothing is ticked for you; Select all ticks every finding at once.

The settings-file list is an estimate. If you recognize an app you still use, leave its file alone. Removing a settings file resets that app's preferences.

Verify disk structure checks the startup disk without changing it. If it reports problems, repair the disk with Apple's Disk Utility (First Aid).

### Optimize

Each action solves a specific problem; none of them is needed regularly. Run… shows the exact command before anything happens.

Flush DNS cache helps when websites do not open or open the wrong address. Free inactive memory releases memory macOS uses as cache; the effect is short-lived. Reset Quick Look cache fixes wrong or missing file previews. Rebuild Spotlight index fixes search that misses files; searching is incomplete until indexing finishes, which can take a while.

The process list shows what is using the most memory right now. Point at a process to see what it does. To close a program, quit it normally or use Activity Monitor.

### Activity log

A record of everything Desktop Peeler changed since you opened it. It is cleared when you quit the app.

### Settings

Theme: Same as macOS, Dark or Light. The switch in the top bar changes the same setting.

Language: "Same as macOS" uses the Mac's language if a translation exists, otherwise English.

Remembered approvals: if you tick "Don't ask again" on an approval sheet, that kind of action runs without waiting for your approval from then on. The result is still shown and logged. Each one can be revoked in Settings.

macOS permissions: shows what macOS allows Desktop Peeler to do, and lets you revoke each permission. macOS asks again the next time it is needed.

### Adding a language

Each language is one file. In Settings › Language press Save English template…, open the file in a text editor, set "code" (for example "de") and "name" (for example "Deutsch"), and translate every value on the right-hand side under "strings". Leave the left-hand side and placeholders such as %d and %@ unchanged.

Then press Add language file… and choose the file. Texts that are missing stay in English. A file with the same code as a built-in language replaces it.

### Frequently asked questions

**Can I undo a cleanup?** Only if Empty Trash afterwards was not ticked: open the Trash, select the items and choose Put Back. Emptied items cannot be put back.

**Why did the free space not change?** Files in the Trash still take space. Empty the Trash, or leave Empty Trash afterwards ticked.

**Why does macOS ask whether Desktop Peeler may control Finder or System Events?** System Events is used to read your login items. Finder is used to move protected files to the Trash and to empty the Trash. Desktop Peeler uses them for nothing else.

**Why am I asked for my password?** Some files and commands belong to the system. macOS asks for the password; Desktop Peeler never sees or stores it.

**Some items "could not be removed". Is that a problem?** No. macOS protects some files. They were left exactly as they were.

**Is it safe to delete caches?** Caches are copies that apps can recreate. Quit the app first; an app that is running may misbehave until restarted.

**Does Desktop Peeler run in the background or send data anywhere?** No. It works only while it is open, and it does not connect to the internet.

**Should I give it Full Disk Access?** Optional. With it the scan sees more folders. Without it the app still works.

---

## 7. About section

| Field | Value |
|---|---|
| Name | Desktop Peeler |
| Version | 1.0 (build 1) |
| Tagline | Clean up your Mac. Nothing happens without your approval. (HU: Takarítsd ki a Maced. A jóváhagyásod nélkül semmi sem történik.) |
| Short description | Desktop Peeler finds caches, logs, temporary files and leftovers, shows you exactly what it found, and removes only what you approve. (HU: A Desktop Peeler megkeresi a gyorsítótárakat, naplókat, ideiglenes fájlokat és maradványokat, pontosan megmutatja, mit talált, és csak azt távolítja el, amit jóváhagysz.) |
| Product page | https://presoft.hu/desktop-peeler (linked in the About window and in Help) |
| Developer | presoft |
| Copyright | © 2026 presoft (from `Info.plist`); the legal name, Takács János e.v. (presoft.hu), appears only in legal documents (licence, terms, privacy) |
| Support | **[CONFIRM support URL or address]** |
| Privacy | "Desktop Peeler collects no data and makes no network connections." plus link to the privacy policy **[CONFIRM URL]** |
| Requirements | macOS 12 or later |
| Languages | English, Hungarian; more can be added as files |
| Acknowledgements | Fonts: Sora, Inter and JetBrains Mono, each under the SIL Open Font License (license texts are in the app bundle). No other third-party code. |
| License | MIT (open source, free). Provided as is, without warranty; use at your own risk. Text: `LICENSE` in the repository. |
| Source code | Public GitHub repository **[CONFIRM URL once created]** |

About window as built: the standard macOS About window showing icon, name, version, tagline, short description, the product page link and the copyright line. Not yet in it: privacy policy and support links (not decided).

### 7.1 Icon

The icon follows the presoft logo box: a rounded square in `surface-2` (#111830) with a #2a3a5c hairline, a line drawing in `text` (#e8f1ff) and exactly one cyan (#3ee0ff) element. Five concepts are in `docs/icon-concepts/` (SVG, 1024 × 1024, plus `overview.png`):

| # | File | Idea |
|---|---|---|
| 1 | `1-peeled-desktop.svg` | A desktop screen whose corner peels away in cyan. |
| 2 | `2-storage-ring.svg` | A disk-usage ring with one segment peeling off as a cyan curl. |
| 3 | `3-peeler-tool.svg` | A peeler tool with a cyan curl of peel. Chosen by the owner and installed as the app icon. |
| 4 | `4-lifted-layer.svg` | A stack of layers with the top one lifted off in cyan. |
| 5 | `5-sparkling-desktop.svg` | A desktop screen with a cyan sparkle: the clean result. |

The installed icon is `Resources/AppIcon.iconset` (PNG, 16–1024 px); `build.sh` turns it into `AppIcon.icns` with `iconutil`. To switch concept, re-render the chosen SVG into the iconset sizes. The presoft logo itself is not used or altered in the icon. For the product page the 1024 px icon is copied to `screenshots/00-app-icon.png`.

### 7.2 Skin (presoft brand)

Source: the brand guideline in the presoft website project (`brand/README.md`) and the site's `src/styles/global.css`. Implemented in `Sources/Theme.swift`; no view may use colours or fonts outside it.

| Token | Value | Use in the app |
|---|---|---|
| bg | #05070d | Window background, list wells |
| bg-2 | #080b14 | Sidebar, top bar, status bar |
| surface | #0b1020 | Cards, approval sheet |
| surface-2 | #111830 | Selected sidebar item, icon box |
| text | #e8f1ff | Headings, body, failure lines |
| text-2 | #a9b7d0 | Lead text, secondary values |
| muted | #6f7d99 | Labels, metadata, eyebrow |
| accent | #3ee0ff | The one primary button per screen, checkbox ticks, eyebrow dash |
| on-accent | #021018 | Text on the cyan button |
| line / line-2 / line-3 | rgba(160,200,255,0.09 / 0.16 / 0.34) | Hairline borders |

Themes: dark and light, both from the guideline. By default the app follows the macOS appearance; the user can fix Dark or Light in Settings or with the three-way switch at the right end of the top bar (half-filled circle, moon, sun). Light values: bg and surface #ffffff, bg-2 and surface-2 #eef2f8, text #05070d, text-2 #33405a, muted #5b6880, borders rgba(5,7,13,0.08 / 0.14 / 0.30). The cyan button is the same in both themes; cyan used as a line or tick on white becomes `accent-text` #00708c, as the guideline requires.

Rules carried over from the guideline: borders instead of shadows; cyan stays rare (one call-to-action per screen); no orange or red anywhere, so failures and warnings are marked by wording, a "▲" prefix and brighter text, never by a warning colour; status labels are outlined pills; buttons are pills; cards, accordions, wells and the selected sidebar item all use the 10 px radius.

Typography: Sora SemiBold for titles, Inter Regular/SemiBold for text and buttons, JetBrains Mono for labels, sizes, paths and the log. The fonts are bundled in `Resources/Fonts` under the SIL Open Font License (license texts included) and loaded through `ATSApplicationFontsPath`.

---

## 8. Distribution

**Decision (2026-11-17): Route A.** The app is free, open source (MIT) and available only as a download on the product page, https://presoft.hu/desktop-peeler. It is not submitted to the Mac App Store. Sections 8.3–8.5 and 8.7 are kept only as background in case that ever changes.

### 8.1 Blocker: the current app cannot pass review

The App Review Guidelines, section 2.4.5, set extra rules for the Mac App Store. Two of them conflict with what Desktop Peeler does today:

- 2.4.5(i): apps "must be appropriately sandboxed". A sandboxed app cannot read other apps' caches in `~/Library/Caches`, `/Library`, `/private/var/log`, the LaunchAgents/LaunchDaemons folders or developer tool folders without the user granting each folder, and cannot script Finder or System Events freely.
- 2.4.5(v): apps "may not request escalation to root privileges". The system-wide cleanup categories, removal of system launch items and three of the four Optimize actions depend on the administrator password.

So version 1.0 as built is not submittable. The store material below is only usable after one of the routes in 8.2 is chosen.

### 8.2 Routes (Route A chosen)

**Route A – distribute outside the App Store (keeps every feature). Chosen.** Enroll in the Apple Developer Program, sign with a Developer ID certificate, enable the hardened runtime, notarize, and distribute the `.dmg` from presoft.hu/desktop-peeler only, behind the download confirmation (10.5). The `.dmg` already exists (2.9); it lacks only the Developer ID signature and notarization. The app is free: no payment, no license keys.

**Route B – a reduced, sandboxed App Store edition.** Rebuild the file access around user-granted folders: the user picks a folder in an open panel, the app stores a security-scoped bookmark, and cleans only inside granted folders. What survives: user caches, user logs, Xcode and developer caches, old installers, broken symbolic links in granted folders, orphaned preferences, the read-only process list, the approval flow, Trash removal. What must be removed: system-wide caches and logs, launch daemons and all-users launch agents, Flush DNS, Free inactive memory, Rebuild Spotlight, any admin prompt, and Finder scripting (so emptying the Trash and the automation permission rows go too). Login-item listing through System Events needs a temporary Apple Events entitlement that review may refuse; plan to replace it with the button that opens System Settings. Disk verification via `diskutil` must be tested inside the sandbox.

**Route C – both:** full edition direct, reduced edition in the store. Twice the testing.

### 8.3 Technical submission checklist (Route B) – not used

- Apple Developer Program membership; App ID for the bundle identifier; app record in App Store Connect.
- A real Xcode project (the current `build.sh` produces an ad-hoc signed app, which cannot be uploaded). Guideline 2.4.5(ii) requires packaging and submission with Xcode technologies.
- App Sandbox entitlement, plus only the entitlements actually used (user-selected file read/write, app-scoped bookmarks).
- Hardened runtime; Apple Distribution signing; upload through Xcode or Transporter.
- Universal build (Apple silicon and Intel) (done in `build.sh`).
- App icon set (done) and `LSApplicationCategoryType` (done); version and build numbers; copyright string (done).
- Run on the currently shipping macOS without deprecated or optional technologies (2.4.5(viii)).
- No own update mechanism, no license keys (2.4.5(vi), (vii)); nothing launched at login without consent (2.4.5(iii)).
- Export compliance answer: the app uses no encryption of its own **[CONFIRM after final code]**.
- Privacy manifest and required-reason API declarations: check whether file timestamp and disk space APIs used by the scanner need declared reasons **[VERIFY against current Apple documentation]**.
- Privacy-policy link inside the app and in App Store Connect (5.1.1(i)).
- Tested on a clean user account; no crashes, no placeholder content.

### 8.4 Listing metadata (draft) – not used

Field limits marked "verify" were not confirmed against Apple's reference pages on 2026-11-16.

| Field | Limit | Draft |
|---|---|---|
| Name | 30 characters (verify) | Desktop Peeler |
| Subtitle | 30 characters (verify) | Disk cleaner you approve first |
| Primary category | – | Utilities |
| Secondary category | – | Productivity (optional) |
| Promotional text | 170 characters | See exactly what will be removed before anything happens. Every cleanup is a list you approve, and files go to the Trash so you can put them back. |
| Keywords | 100 bytes | cleaner,cache,logs,disk space,temporary files,junk,startup,login items,storage,cleanup |
| Description | 4,000 characters, plain text | Below |
| What's New | – | First release. |
| Support URL | required | **[CONFIRM]** |
| Marketing URL | optional | https://presoft.hu/desktop-peeler |
| Privacy Policy URL | required | **[CONFIRM]** |
| Copyright | required, year then owner | 2026 Takács János e.v. (presoft.hu) |
| Age rating | questionnaire | No restricted content expected; lowest rating |
| Price / availability | – | **[CONFIRM]** |
| Screenshots | 1–10, 16:10, one of 1280×800, 1440×900, 2560×1600, 2880×1800; JPEG or PNG without transparency | The 2560×1600 files in `screenshots/` fit once flattened onto a solid background (their window corners are transparent). They show the full edition in Hungarian; a store edition needs its own set in the store's language. |

**Name.** Apple's trademark rules bar "Mac" inside a product name. A web search found no app called "Desktop Peeler"; the final check is App Store Connect, which refuses a taken name. "Peeler" does not say "cleaner", so the subtitle must carry the search terms.

**Description draft (Route B edition; the promotional text and "Always recoverable" are true only for an edition without Empty Trash afterwards):**

> Desktop Peeler frees space on your Mac without surprises. It looks for files you no longer need, shows you every one of them, and waits for your decision.
>
> REVIEW FIRST
> Scanning changes nothing. Before any cleanup you see the full list: each item, its size and where it is. Confirm to proceed or cancel to leave everything as it was.
>
> ALWAYS RECOVERABLE
> Approved items are moved to the Trash, never deleted permanently. Put them back any time before you empty the Trash.
>
> WHAT IT FINDS
> • Application caches and log files
> • Old temporary files
> • Xcode build data and developer tool caches
> • Old installers in your Downloads folder
> • Shortcuts that point nowhere and settings files left behind by removed apps
>
> YOU STAY IN CONTROL
> • Select whole categories or single items
> • Only low-risk categories are preselected
> • A session log records everything that was changed
>
> PRIVATE BY DESIGN
> No account, no ads, no tracking, no network connections. Desktop Peeler works only while it is open and only in the folders you allow.

Do not use claims such as "speeds up your Mac", "boosts performance" or "removes malware" in any copy: the app does not measure or guarantee them, and guideline 2.3 requires metadata to reflect the app accurately.

### 8.5 App privacy answers (App Store Connect) – not used

The app collects no data: answer "Data Not Collected". No tracking. No third-party SDKs. This must be re-confirmed if analytics, crash reporting or licensing is ever added.

### 8.6 Privacy policy (draft text, for the product page) **[CONFIRM address, contact, date; have it reviewed]**

> **Desktop Peeler Privacy Policy**
> Effective date: [date]
>
> Desktop Peeler is published by Takács János e.v. (presoft.hu), [address], contact: [contact].
>
> **Data we collect.** None. Desktop Peeler does not collect, store or transmit personal data. It has no account, no analytics, no advertising and makes no network connections.
>
> **Data processed on your Mac.** To do its work the app reads the names, sizes and dates of files in the folders it scans, and the list of programs that start automatically. This information stays on your Mac, is shown only to you, and is discarded when you quit the app. The app stores only its own settings (theme, language, remembered approvals) on your Mac.
>
> **Third parties.** No data is shared with anyone, because none is collected.
>
> **Retention and deletion.** We hold no data about you, so there is nothing to retain or delete. Removing the app and its settings file removes everything it stored on your Mac.
>
> **Changes.** If this policy changes, the new version will be published at this address with a new effective date.

### 8.7 App Review notes (draft, Route B) – not used

> Desktop Peeler removes cache, log and temporary files that the user selects. It is fully sandboxed. It accesses only folders the user grants through the standard open panel; access is kept with security-scoped bookmarks and can be revoked in the app. Every change is shown in a review sheet first and requires confirmation; files are moved to the Trash with the system API and are never deleted permanently. The app requests no administrator rights, installs nothing, does not run at login and makes no network connections. To test: launch, grant the suggested folder, press Scan, expand a category, press "Review & clean…", confirm, and check the Trash. No login is required.

---

## 9. Open items for the owner

1. Apple Developer ID for signing and notarizing the `.dmg` (Route A, 8.2).
2. Support and privacy-policy URLs; privacy and support links in the About window once decided.
3. Build the product page with the download confirmation (10.5) on presoft.hu.

---

## 10. Product page material (presoft.hu/desktop-peeler)

The presoft site is Hungarian-only, so the screenshots show the Hungarian interface, and suggested captions are given in Hungarian. The files are in `screenshots/` next to this document.

### 10.1 Key messages

Use these, in this order of weight; every claim is backed by sections 2–4.

1. **You see everything before anything happens.** Every change is a list you approve: each file with size and path, or the exact command. Cancel leaves the Mac untouched.
2. **It finds the usual space-wasters.** App caches, logs, temporary files, Xcode and developer tool caches, old installers in Downloads, system-wide caches and logs.
3. **It tidies what starts with the Mac.** Lists login items, launch agents and daemons; flags entries whose program is gone.
4. **It spots leftovers.** Broken links, startup entries of removed apps, settings files of apps that seem to be uninstalled.
5. **Troubleshooting in one click, with the command shown.** Flush DNS, free inactive memory, reset Quick Look, rebuild Spotlight; the memory list explains each process.
6. **You decide how much it asks.** "Don't ask again" per kind of action, every permission listed and revocable in Settings.
7. **Private.** No account, no tracking, no internet connection; it runs only while open.
8. **Native and bilingual.** Mac app for macOS 12 or later, Hungarian and English, light and dark appearance.
9. **Free and open source.** MIT license, source code on GitHub. Provided as is; use at your own risk.

Avoid: "speeds up your Mac", "boosts performance", "removes viruses", "safe to delete everything". Say clearly that emptying the Trash is permanent and on by default.

### 10.2 Screenshots

All are real captures of the app (version 1.0, Hungarian, dark theme unless noted), filled with **sample data**: the user is a made-up "anna", the files, apps and sizes are examples, not a real Mac. Window captures are 2560 × 1600 px (16:10, retina, 1280 × 800 pt window) PNG with transparent rounded corners and no shadow; add a shadow in CSS if wanted.

| File | Shows | Suggested caption (HU) |
|---|---|---|
| `01-cleanup.png` | Cleanup after a scan: categories with item counts and sizes, three low-risk ones ticked, Empty Trash afterwards, Review & clean… | Egy keresés, és látod, mennyi helyet foglalnak a gyorsítótárak, naplók és ideiglenes fájlok. |
| `02-cleanup-expanded.png` | A category opened to its items, each with size and Finder button | Kategóriánként vagy fájlonként döntöd el, mi mehet. |
| `03-approval.png` | The approval sheet: full list with sizes and paths, the Empty Trash line, "Don't ask again", Cancel and the confirm button | Semmi sem történik, amíg át nem nézed és jóvá nem hagyod a teljes listát. |
| `04-autostart.png` | Auto-start: login items, launch agents and daemons; an entry marked "program missing" ticked | Lásd és kapcsold ki, mi indul el magától a Mac-kel. |
| `05-system-checks.png` | System checks: startup disk summary, missing-program entry, broken link, settings files of removed apps, Select all | Maradványok és hibás bejegyzések, egy helyen. |
| `06-optimize.png` | Optimize: four actions (three marked admin password) and the memory list | Célzott javítások, mindig a pontos paranccsal. |
| `07-process-tooltip.png` | Detail (2060 × 560 px): pointing at WindowServer shows what it does and its path | Megmutatja, mi az a folyamat, ami a memóriát foglalja. |
| `08-settings.png` | Settings: theme, language, two remembered approvals with Revoke, macOS permissions | Téma, nyelv, megjegyzett jóváhagyások és engedélyek, egyenként visszavonhatóan. |
| `09-help.png` | Help pane | Beépített súgó magyarul és angolul. |
| `10-about.png` | About window (568 × 632 px) with tagline, description and product link | — |
| `11-cleanup-light.png` | Cleanup with an opened category, light theme | Világos és sötét megjelenés, a rendszerhez igazodva. |

App icon for the page: `00-app-icon.png` (1024 × 1024 px, same as `Resources/AppIcon.iconset/icon_512x512@2x.png`).

### 10.3 Facts box

| | |
|---|---|
| Platform | macOS 12 Monterey or later, Intel and Apple chip (universal app; tested on Intel, not yet run on an Apple-chip Mac) |
| Download | `DesktopPeeler-1.0.dmg`, about 1.4 MB, drag-to-Applications, only from this page after accepting the terms (10.5) **[CONFIRM: hosting and whether it is signed/notarized first]** |
| Languages | Hungarian, English (more can be added) |
| Price | Free |
| License | MIT, open source; use at your own risk |
| Source code | GitHub **[CONFIRM URL]** |
| Data | Collects nothing, no network connection |
| Developer | presoft |

### 10.4 How the screenshots were made

A throwaway copy of the app (separate bundle ID `hu.presoft.desktoppeeler.demo`, never shipped) was filled with the sample data and had every action disabled, then the real window was captured with `screencapture -l`. To redo them after interface changes, rebuild such a copy the same way; do not capture a real user's Mac, because paths, app names and login items would be published.

### 10.5 Download confirmation (required)

The download button does not link to the `.dmg` directly. It opens a modal dialog; the file can be downloaded only after the visitor accepts the terms.

Behaviour:

- The modal shows the text below and one checkbox, unticked by default.
- The **Letöltés** button is disabled until the checkbox is ticked. **Mégse** (and Esc, and the close button) closes the modal without downloading.
- The `.dmg` URL is not present on the page as a plain link outside the modal, so the download cannot start without acceptance. (A visitor who already knows the file URL can still fetch it; the page cannot prevent that, and the MIT license applies regardless.)
- Nothing is stored about the acceptance: no cookie, no log, no data sent (the site has no cookies and no trackers).
- Keyboard and screen-reader accessible: focus moves into the modal, stays there while it is open, and returns to the download button when it closes.

Text (HU):

> **Mielőtt letöltöd**
>
> A Desktop Peeler ingyenes, nyílt forráskódú program (MIT licenc), szabadon felhasználható, módosítható és terjeszthető.
>
> A programot „ahogy van” állapotban adjuk közre, mindennemű garancia nélkül. A használatából eredő bármilyen kárért – beleértve az adatvesztést is – a fejlesztő nem vállal felelősséget. Mindenki a saját felelősségére használja.
>
> ☐ Elolvastam és elfogadom: a programot a saját felelősségemre használom.
>
> [Mégse] [Letöltés]

Below the text, a link to the full license (`LICENSE` in the GitHub repository) **[CONFIRM URL]**. Have the wording reviewed together with the site's other legal texts.

## Sources

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) – sections 2.3, 2.4.5, 5.1.1(i)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
