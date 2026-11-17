# Desktop Peeler

by presoft · free and open source (MIT)

A native macOS (SwiftUI) cleaner. Requires macOS 12 or later and Xcode (or Apple's Command Line Tools) to build.

## Build and run

    cd desktop-peeler
    bash build.sh

The script compiles the app into `build/Desktop Peeler.app` and shows it in Finder.

## Installer

    bash make-dmg.sh

Builds the app and packs it into `build/DesktopPeeler-<version>.dmg`. Open the disk image and drag Desktop Peeler onto the Applications shortcut. The app is ad-hoc signed only: on another Mac, macOS blocks the first launch; allow it in System Settings › Privacy & Security › Open Anyway. Signing and notarization need an Apple Developer ID.

## What it does

- **Cleanup** – scans caches, logs, temporary files, Xcode build data, developer tool caches, old installers in Downloads, and system-wide caches/logs. You tick categories or single items, then review the full list before approving. "Empty Trash afterwards" (ticked by default) empties the Trash after the move.
- **Auto-start** – lists login items, launch agents and launch daemons; ticked ones are removed from auto-start.
- **System checks** – startup entries pointing to missing programs, broken symbolic links, preference files of apps that appear uninstalled, disk summary and a read-only disk verification.
- **Optimize** – flush DNS cache, free inactive memory, reset Quick Look cache, rebuild Spotlight index, plus a list of the most memory-hungry processes.
- **Activity log** – every change made in the session.
- **Settings** – theme (default: same as macOS), language (default: macOS language, else English; more languages as JSON files), remembered approvals and macOS permissions, each revocable.
- **Help** – in-app help; About (app menu) links to presoft.hu/desktop-peeler.

## Safety rules built in

- Scans never change anything.
- Every change goes through an approval sheet listing each file or the exact command.
- Files are moved to the Trash. After a cleanup the Trash is emptied too, unless you untick "Empty Trash afterwards"; the approval sheet says so.
- "Don't ask again" on an approval sheet skips that sheet for that kind of action from then on; revoke it in Settings.
- Protected (system-level) files are handed to Finder, which asks for your administrator password; optimize commands needing admin use the standard macOS password dialog.
- Anything that could not be removed is reported and left untouched.

## Permissions macOS may ask for

- Control of "System Events" (to read login items) and "Finder" (to trash protected files).
- Access to the Downloads folder (for the old-installers category).
- For a more complete scan you can give Desktop Peeler Full Disk Access in System Settings › Privacy & Security; it works without it.

## Download

The ready-made app is available only on the product page, https://presoft.hu/desktop-peeler, after accepting the terms below.

## License and disclaimer

MIT License, see [LICENSE](LICENSE). Free to use, modify and distribute. The software is provided "as is", without warranty of any kind; the author accepts no liability for any damage, including data loss, arising from its use. Use it at your own risk.

Bundled fonts (Sora, Inter, JetBrains Mono) are under the SIL Open Font License; their license texts are in `Resources/Fonts`.
