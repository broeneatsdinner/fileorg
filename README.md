# fileorg

`fileorg` is a small shell tool for organizing files in the current working directory by keyword or filename pattern.

It creates word-list files, builds a reviewed list of matching files from a selected word list, then can move those files into a new subdirectory. The organizer defaults to dry-run mode so you can inspect the planned moves before anything changes.

fileorg is intentionally review-first: create a word list, choose existing lists through file selectors that can preview or edit in place, generate a matching-files list, review that list, then move files.

## Demo

![fileorg demo](demo/demo.gif)

Higher-quality video: [demo/demo.mp4](demo/demo.mp4)

The demo shows a complete review-first workflow:

- create a new word list from scratch
- notice a missed extension and edit the list
- generate a reviewed matching-files list
- move only the matching files into a new subdirectory

## Files

- `fileorg.sh` is the main organizer script.
- `selector-interactive.sh` provides keyboard selection menus for choosing word-list and matching-files files.
- `fileorg-word-list-images-extensions.txt` is an example word list for common image extensions.
- `fileorg-word-list-movies-extensions.txt` is an example word list for common video extensions.
- `fileorg-matching-files.txt` is a small example matching-files list.

## Requirements

- `zsh` for `fileorg.sh`
- `bash` for `selector-interactive.sh`
- macOS is the primary target. When available, `fileorg` sorts generated matches by Finder Date Added metadata, then falls back to file birth time or filename.

## Usage

The menu-driven workflow is the primary interface. The direct flags below are available for targeted use.

Run `fileorg.sh` from the directory you want to organize:

```sh
cd path/to/files
/path/to/fileorg.sh
```

The script works on the current working directory, not the directory where the script is stored.

You can also run specific modes directly:

```sh
/path/to/fileorg.sh --view-list
/path/to/fileorg.sh --edit-list
/path/to/fileorg.sh --build-list
/path/to/fileorg.sh --view-matches
/path/to/fileorg.sh --edit-matches
/path/to/fileorg.sh --organize
/path/to/fileorg.sh --organize --force
/path/to/fileorg.sh --dry-run
```

## Workflow

1. Start a new word list.

   Choose `Start a new word list from scratch` from the main menu. Enter a suffix such as `images`, then enter comma-separated search terms such as `.jpg, .png, .heic`.

   This creates a file named like `fileorg-word-list-images.txt`, with one search term per line. After that, return to the main menu and choose existing lists when you are ready to review, edit, or build from them.

2. Choose an existing word list.

   Choose `Choose an existing word list` from the main menu, or run:

   ```sh
   /path/to/fileorg.sh --view-list
   /path/to/fileorg.sh --edit-list
   ```

   Editing uses `VISUAL` first, then `EDITOR`, then `/usr/bin/nano`:

   ```sh
   VISUAL="code --wait" /path/to/fileorg.sh --edit-list
   EDITOR=vim /path/to/fileorg.sh --edit-list
   ```

   While the word-list selector is open, press `v` to preview the highlighted word list or `o` to open it in your editor. Press Enter to select and show the highlighted file. Press Left Arrow, `q`, `Q`, or Escape to return to the main menu.

3. Generate a matching-files list.

   Choose `Generate a new fileorg-matching-files*.txt from an existing word list`, or run:

   ```sh
   /path/to/fileorg.sh --build-list
   ```

   The script scans regular files in the current directory, matches them case-insensitively against the selected word list, and writes a reviewable file such as `fileorg-matching-files-images.txt`.

   Existing matching-files lists are preserved by adding a number, such as `fileorg-matching-files-images-2.txt`.

4. Choose a matching-files list.

   Choose `Choose an existing fileorg-matching-files*.txt` from the main menu, or run:

   ```sh
   /path/to/fileorg.sh --view-matches
   /path/to/fileorg.sh --edit-matches
   ```

   Remove anything you do not want moved before organizing. Blank lines are ignored, and lines that do not point to regular files are skipped.

   Editing uses `VISUAL` first, then `EDITOR`, then `/usr/bin/nano`, just like word-list editing:

   ```sh
   VISUAL="code --wait" /path/to/fileorg.sh --edit-matches
   EDITOR=vim /path/to/fileorg.sh --edit-matches
   ```

   Matching-files selectors also support `v` to preview the highlighted list and `o` to open it in your editor before choosing it with Enter. Press Left Arrow, `q`, `Q`, or Escape to return to the main menu.

5. Run the organizer in dry-run mode.

   Dry-run mode is the safe default. It prints the destination directory it would create and each file it would move, but it does not create directories or move files.

   From the menu, choose the organizer option and accept the default `dry-run` choice, or run:

   ```sh
   /path/to/fileorg.sh --organize
   /path/to/fileorg.sh --dry-run
   ```

6. Run the organizer in force mode.

   Only use force mode after reviewing the dry-run output.

   From the menu, choose the organizer option and type `force`, or run:

   ```sh
   /path/to/fileorg.sh --organize --force
   ```

   Force mode creates the destination subdirectory under the current working directory and moves the reviewed matching files into it. The destination must not already exist.

## Keyboard Selection

`selector-interactive.sh` renders arrow-key menus used when selecting existing word-list and matching-files files.

- Use Up and Down arrows to move through options.
- Press Enter to choose the highlighted option.
- Press `v` to view the highlighted file when choosing a word-list or matching-files list.
- Press `o` to open the highlighted file in your editor when choosing a word-list or matching-files list.
- Press Left Arrow, `q`, `Q`, or Escape to cancel selector menus.
- Press Ctrl+C to interrupt and cancel the current operation.

For text prompts in `fileorg.sh`, `q`, `Q`, or Escape cancels where cancellation is accepted. Ctrl+C cancels the script and exits with an interrupt status.

## Word Lists

Word-list files are named:

```text
fileorg-word-list*.txt
```

Each nonblank line is used as a case-insensitive fixed-string match against filenames in the current directory.

The included word-list files are examples:

- `fileorg-word-list-images-extensions.txt` matches common image extensions.
- `fileorg-word-list-movies-extensions.txt` matches common video extensions.

Use them as references or copy their contents into your own local word lists.

## Matching-Files Lists

Matching-files lists are named:

```text
fileorg-matching-files*.txt
```

These files are intentionally reviewable. The organizer moves only files listed in the selected matching-files list, skips blank lines, and skips entries that are not regular files.

The included `fileorg-matching-files.txt` is a tiny example showing the expected format.
