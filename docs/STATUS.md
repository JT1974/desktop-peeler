# Desktop Peeler – project status

The project folder on the iMac is `Desktop/Work/desktop-peeler`.

Last updated: 2026-11-24 (first published build: 1.0.0 build 2, GitHub release `v1.0.0-build2` with SHA-256 checksum; published unsigned by the owner's decision)

## Where things stand

- The first version (plain look) was compiled on the iMac. Whether it was run and tested is not recorded.
- Since then the app got the presoft skin (`Sources/Theme.swift`, restyled `Sources/Views.swift`), bundled brand fonts, an app icon, a light theme and a theme switcher.
- 2026-11-16, second round (owner's 12-point list): Settings pane (theme with "same as macOS" default, language, remembered approvals, macOS permissions with revoke), Help pane, About panel with description and presoft.hu/desktop-peeler link, English + Hungarian via JSON language files (users can add more), "Empty Trash afterwards" in Cleanup (default on), Select all in System checks, process descriptions on hover, smaller accordion corners, step labels "grab"/"peel", `make-dmg.sh` installer.
- This version compiles with `build.sh` and `make-dmg.sh` on the iMac (Command Line Tools, macOS 26) as a universal app (x86_64 + arm64) and launches. The arm64 part has not been run on an Apple-chip Mac yet. Checked on the real window (Hungarian, dark): every pane, the cleanup approval sheet with Cancel, Select all, process tooltips. Not yet tested by hand: real cleanup with Empty Trash, remembered approvals running, permission revoke (tccutil), language file import.

## Next steps

1. Test each pane by hand on the iMac, including the administrator-password paths and the new items listed above.
2. Distribution decided 2026-11-17: Route A, download only from the product page behind an accept-the-terms modal (`PRODUCT_DOCUMENTATION.md` §8, §10.5). Free, open source, MIT. Signing and notarization need an Apple Developer ID.
3. Build the product page with the download modal in the presoft website project.

## Project layout

| Path | Content |
|---|---|
| `Sources/Core.swift` | Scanning, Trash removal, startup items, system checks, optimize actions |
| `Sources/AppState.swift` | App state and the approval flow every change passes through |
| `Sources/Views.swift` | SwiftUI interface: app menu commands, sidebar, tool panes, approval sheet |
| `Sources/SettingsView.swift` | Settings pane: theme, language, remembered approvals, macOS permissions |
| `Sources/HelpView.swift` | Help pane and About panel |
| `Sources/Localization.swift` | `L()`/`N()` translation lookup, language file loading, import and removal |
| `Resources/Languages` | `en.json` (template, generated) and `hu.json` |
| `tools/update-language-template.py` | Regenerates `en.json` from the sources, reports missing translations |
| `make-dmg.sh` | Builds the app and the drag-to-Applications disk image `build/DesktopPeeler-<version>-build<n>.dmg` |
| `Sources/Theme.swift` | presoft brand skin: colours, fonts, button, checkbox and card styles |
| `Resources/Fonts` | Sora, Inter, JetBrains Mono (SIL Open Font License) |
| `Resources/AppIcon.iconset` | App icon PNGs (concept 3, peeler tool) |
| `docs/icon-concepts` | The five icon concepts as SVG plus an overview image |
| `Info.plist` | Bundle metadata, bundle ID `hu.presoft.desktoppeeler`, minimum macOS 12.0 |
| `build.sh` | Compiles with `swiftc` for Intel and Apple chips and joins them into one universal app, ad-hoc signs, packs fonts and icon, outputs `build/Desktop Peeler.app` |
| `README.md` | Build and usage summary |
| `docs/STATUS.md` | This file |
| `docs/PRODUCT_DOCUMENTATION.md` | Feature, approval-rule and limits reference; help, About, App Store and product page material |
| `docs/screenshots` | Product page images (sample data, Hungarian UI); copied to the website project under `v3/docs/desktop-peeler-app/` |

## Decisions made by János

- Native SwiftUI app, target macOS 12 or later. Universal build (Intel + Apple chip) since 2026-11-16, so the downloadable app does not need Rosetta.
- Removal always goes to the Trash; nothing is deleted permanently.
- Scope is the user account plus system level; system-level items need the administrator password.
- No change happens without an approval sheet that lists every file or the exact command.

- presoft brand skin with dark and light theme and a switcher in the top bar; app icon is concept 3 (peeler tool).
- 2026-11-16: Cleanup empties the Trash afterwards by default (checkbox); "Don't ask again" approvals allowed, revocable in Settings; Settings also shows macOS permissions with revoke; installer is a drag-to-Applications .dmg; product page is presoft.hu/desktop-peeler.

## Known gaps

- The new features are not tested by hand yet (see above).
- macOS can only revoke the System Events and Finder automation permissions together (tccutil); one at a time only in System Settings. The Downloads-folder permission state cannot be read without macOS asking, so no status is shown for it.
- The .dmg is ad-hoc signed: other Macs block the first launch until allowed in System Settings › Privacy & Security.
- `https://presoft.hu/desktop-peeler/latest.json` and the .dmg are live since 2026-11-24, served next to the coming-soon page until the full website launches; "Check for updates" reads them.
- Releasing: build with `make-dmg.sh`, commit, tag that commit `v<version>-build<n>`, attach the .dmg to a GitHub release with its SHA-256, then update the website's `src/data/desktop-peeler.ts` (the site build stops if the checksum does not match the file).
- Background items that apps register directly with macOS cannot be listed or removed; the app only opens System Settings › Login Items.
- The "orphaned preference files" check is a heuristic based on the vendor prefix of the bundle ID.
- The Trash is emptied only after a cleanup with "Empty Trash afterwards" ticked; it is not scanned or sized.
