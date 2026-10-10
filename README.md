# envi

Inspired by Notational Velocity.

Native macOS note-taking: fast search-first notes as plain `.md` files, with optional Vim modal editing in the note body.

## Requirements

- macOS 14+
- Xcode 15+

## Run

Open `Envi.xcodeproj` in Xcode and run the **Envi** scheme, or:

```bash
xcodebuild -scheme Envi -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Envi-*/Build/Products/Debug/envi.app
```

## Test

```bash
xcodebuild -scheme Envi -destination 'platform=macOS' test
```

## Usage

1. On first launch, use **Documents/envi** or choose any folder.
2. Type in the search field to filter notes (title, body, and tags). Selecting a note puts its title in the search field (⌘D restores the previous search).
3. **Return** opens the highlighted match or creates a note when nothing matches (the new title stays in the search field). **Escape** clears the search.
4. **⌘L** focuses search · **⌘J/⌘K** and (in the search field) **⌃J/⌃K**, **⌃N/⌃P**, and **↑/↓** move the highlight · **⌘R** or double-click a title to rename inline · **⌘⇧T** or double-click Tags to edit tags inline · **⌘⌫** or the context menu moves a note to the Trash.
5. The notes list shows **Title**, **Date Modified**, and **Tags**. The note pane has a compact editable title and the body. Tags appear only in the list. They are stored as a `tags:` frontmatter line (a comma-separated list or a YAML list). Other frontmatter keys are kept when the note is saved.
6. Optional global bring-to-front hotkey: **Settings → Activation**.

### Vim mode

Vim modal editing for the note body is **off by default** (toggle in **Settings → Editing**). When enabled, a compact footer shows the current mode.

- Opening a note into the body starts in **Insert** (`-- INSERT --`).
- **Esc** enters **Normal** (`-- NORMAL --`, block-style caret); another **Esc** focuses search.
- Motions: `h j k l`, `w b e`, `0` `^` `$`, `gg` `G`, counts (`3j`, `2dd`, `5gg`).
- **j/k move by wrapped lines** (on by default in **Settings → Editing**): `j`/`k` step one soft-wrapped screen line instead of jumping to the next newline. Operator motions like `dj` still use buffer lines.
- Insert: `i` `a` `I` `A` `o` `O`.
- Edits: `x` `X`, `d`/`c`/`y` + motion, `dd` `cc` `yy`, `D` `C`, `p` `P`, `u` / `Ctrl-r`.
- Visual: `v` / `V`, then motion and `d`/`c`/`y`/`x`.
- Control note-navigation shortcuts (**⌃J/⌃K/⌃N/⌃P**) apply only while the search field is focused, so they do not steal keys from the note body.
