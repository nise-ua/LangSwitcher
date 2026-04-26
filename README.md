# LangSwitcher (Configurable EN/RU/UA)

Chrome extension that detects when the last typed word appears to be entered with the wrong keyboard layout and rewrites it automatically.

## What it does

- Tracks typing in `input` and `textarea` fields.
- On word boundary (space/punctuation), checks if the previous word looks like:
  - English letters typed on RU/UA layout (`ghbdtn` -> `привет` / `привіт`), or
  - Cyrillic letters typed on EN layout.
- Rewrites the last word automatically.
- Updates extension badge with active language (`EN`, `RU`, `UA`).

## How to add this extension to Chrome

> This project is loaded as an unpacked extension (developer mode), not from Chrome Web Store.

1. Download or clone this repository to your computer.
2. Open Google Chrome.
3. Go to `chrome://extensions`.
4. Turn on **Developer mode** (top-right toggle).
5. Click **Load unpacked**.
6. Select the project root folder (the folder containing `manifest.json`).
7. Confirm that **LangSwitcher** appears in your extension list.
8. (Optional) Click the puzzle icon in Chrome toolbar and pin **LangSwitcher** for quick access.

## Configure language list

1. Open `chrome://extensions`
2. Find **LangSwitcher** and click **Details**
3. Open **Extension options**
4. Enable at least 2 languages from the list (EN/RU/UA)
5. Save settings

The content script immediately applies updated language list from storage.

## Important limitation

Chrome extensions generally **cannot switch your operating system keyboard layout** on Windows/macOS/Linux. This extension emulates that behavior by auto-correcting wrongly typed words and tracking an internal active language state.

## Update after local code changes

1. Open `chrome://extensions`
2. Find **LangSwitcher**
3. Click the **Reload** button on the extension card

## Remove from Chrome

1. Open `chrome://extensions`
2. Click **Remove** on the **LangSwitcher** card
3. Confirm removal

## Files

- `manifest.json` – extension manifest (MV3)
- `src/content.js` – typing tracker + auto rewrite logic
- `src/background.js` – badge + state updates
- `options/options.html` – configuration page
- `options/options.js` – settings persistence
- `options/options.css` – options page styles
