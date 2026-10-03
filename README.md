# envi

Native macOS note-taking app inspired by Notational Velocity.

## Requirements

- macOS 14+
- Xcode 15+

## Run

Open `Envi.xcodeproj` in Xcode and run the **Envi** scheme, or:

```bash
xcodebuild -scheme Envi -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Envi-*/Build/Products/Debug/envi.app
```

## Usage

1. On first launch, use **Documents/envi** or choose any folder.
2. Type in the search field to filter notes (title, body, and tags). Selecting a note puts its title in the search field (⌘D restores the previous search).
3. **Return** opens the highlighted match or creates a note when nothing matches (the new title stays in the search field). **Escape** clears the search.
4. **⌘L** focuses search · **⌘J/⌘K**, **⌃J/⌃K**, **⌃N/⌃P**, and **↑/↓** move the highlight · **⌘R** or double-click a title to rename · **⌘⇧T** or double-click Tags to edit tags.
5. The notes list shows **Title**, **Date Modified**, and **Tags**. The note pane has a compact editable title and the body (no status bar). Tags appear only in the list.
6. Optional global bring-to-front hotkey: **Settings → Activation**.
