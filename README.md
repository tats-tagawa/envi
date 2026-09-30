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
2. Type in the sidebar search field to fuzzy-filter notes.
3. **Return** opens the highlighted note · **⌘Return** creates a note named from the search text.
4. **↑/↓** or **⌃P/⌃N** move the highlight · **⌘K** focuses search and selects all.
5. Each note is a plain `.md` file (title = filename). Created/updated dates come from the file and show in the main panel status bar.
