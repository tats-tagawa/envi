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

## Getting started

1. On first launch, choose **Use Documents/envi** or **Choose Folder…**. Each note is a Markdown file in that folder. Change folders later with **File → Open Notes Folder…** (⌘⇧O).
2. Type a title in **Search or create…** and press **Return**. If nothing matches, envi creates the note and puts the caret in the body so you can write immediately.
3. Edit the body in the note pane. Changes save automatically to the `.md` file.
4. To open an existing note, type to filter the list, move with **↑/↓** or **⌘J/⌘K**, then press **Return** (or click a row). Selecting a note puts its title in the search field; press **Return** again to jump into the body.
5. Rename with **⌘R** (or double-click the title in the list). Delete with **⌘⌫** (moves the note to the Trash).
6. For tasks, press **⌃⌘T** to enter Task mode, type a title, and press **Return** to create a checklist item. Embed more tasks in any note with `- [ ]` lines.

## Search and create

- The search field filters by title, body, and tags.
- **Return** opens the highlighted match, or creates a note when there are no matches. The new title stays in the search field.
- **Escape** clears the search (it does not leave Task mode).
- **⌘L** focuses search (and selects the field contents).
- **⌘D** deselects the current note and restores the previous search text.
- While a note is selected, the search field shows that note’s title (the Notational Velocity model). Rename happens in the list (**⌘R**), not in a separate title field in the editor.

## Notes list

The list shows **Title**, **Date Modified**, and **Tags**.

- **Date Modified** uses relative time for recent notes (within 6 hours), **Today** / **Yesterday** with a time, and a short medium date for older notes. Hover a date for the full timestamp. Format options live in **Settings → Date Modified**.
- The **Tags** column appears once any visible note has tags, or while you are editing tags (**⌘⇧T**).
- Right-click a row for Rename, Edit Tags…, or Move to Trash.
- Layout defaults to a sidebar list beside the editor. Switch to a stacked list-above-editor layout in **Settings → Layout**.

## Tasks

Tasks are ordinary GitHub-flavored Markdown checkboxes in note bodies. Optional trailing tokens set priority (`!1` highest … `!3` lowest) and deadline (`@YYYY-MM-DD`):

```markdown
- [ ] Buy milk !1 @2026-10-20
- [x] Ship PR !2
```

- **⌃⌘T** (**View → Toggle Task Mode**) switches the list to individual task lines (open first by priority then deadline, done dimmed at the bottom). Columns show priority and due date (overdue in red). The search placeholder becomes **Search or create task…**. Escape clears the query but stays in Task mode; toggle again to return to notes.
- In Task mode, **Return** opens the parent note for the highlighted task, or creates a dedicated note whose body is `- [ ] …` when nothing matches.
- Click the checkbox in the task list to toggle done/not done.
- In the note body:
  - **⌘⇧Return** (**Note → Insert Task**) inserts `- [ ] ` (on an empty line, or on a new line below).
  - **⌘Return** (**Note → Toggle Task**) flips the checkbox on the current task line.
  - **⌃⌘1 / ⌃⌘2 / ⌃⌘3** set priority; **⌃⌘0** clears it.
  - **⌘⇧D** opens a date picker to set or clear the deadline.
- You can also type `!1` / `@2026-10-20` at the end of a task line by hand.

## Tags and frontmatter

- Edit tags with **⌘⇧T**, or double-click the Tags cell. Enter a comma-separated list.
- Tags are stored as a `tags:` frontmatter line (comma-separated or a YAML list). Other frontmatter keys are preserved when the note is saved.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Focus search | ⌘L |
| Deselect / restore search | ⌘D |
| Next / previous note | ⌘J / ⌘K |
| Move highlight in search | ↑/↓, and (while search is focused) ⌃J/⌃K, ⌃N/⌃P |
| Open highlighted note or create | Return (in search) |
| Clear search | Escape (in search) |
| Toggle Task mode | ⌃⌘T |
| Insert task at caret | ⌘⇧Return |
| Toggle task at caret | ⌘Return |
| Set task priority 1 / 2 / 3 | ⌃⌘1 / ⌃⌘2 / ⌃⌘3 |
| Clear task priority | ⌃⌘0 |
| Set / clear task deadline | ⌘⇧D |
| Rename note | ⌘R |
| Edit tags | ⌘⇧T |
| Delete note (Trash) | ⌘⌫ |
| Open notes folder | ⌘⇧O |

## Settings

- **Appearance** — System (default), Light, or Dark.
- **Layout** — Sidebar (default) or Stacked.
- **Editing** — Optional Vim mode for the note body (off by default). When on, a footer shows `-- INSERT --` / `-- NORMAL --`. Optional **j/k move by wrapped lines** (on by default with Vim).
- **Date Modified** — Date order and 24-hour time.
- **Activation** — Optional global bring-to-front hotkey. While enabled, closing the window hides envi instead of quitting so the hotkey can bring it back.

## Vim mode

Toggle in **Settings → Editing**. When enabled:

- Opening a note into the body starts in **Insert**.
- **Esc** enters **Normal** (block-style caret); another **Esc** focuses search.
- Motions: `h j k l`, `w b e`, `0` `^` `$`, `gg` `G`, counts (`3j`, `2dd`, `5gg`).
- **j/k move by wrapped lines** (on by default): `j`/`k` step one soft-wrapped screen line. Operator motions like `dj` still use buffer lines.
- Insert: `i` `a` `I` `A` `o` `O`.
- Edits: `x` `X`, `d`/`c`/`y` + motion, `dd` `cc` `yy`, `D` `C`, `p` `P`, `u` / `Ctrl-r`.
- Visual: `v` / `V`, then motion and `d`/`c`/`y`/`x`.
- Control note-navigation shortcuts (**⌃J/⌃K/⌃N/⌃P**) apply only while search is focused, so they do not steal keys from the note body.
- Cmd task shortcuts (**⌘Return**, **⌘⇧Return**, priority/deadline) still work in Normal and Insert.
