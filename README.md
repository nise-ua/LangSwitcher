# LangSwitcher (Configurable EN/RU/UA)

Chrome extension that detects when the last typed word appears to be entered with the wrong keyboard layout and rewrites it automatically.

## What it does

- Tracks typing in `input` and `textarea` fields.
- On word boundary (space/punctuation), checks if the previous word looks like:
  - English letters typed on RU/UA layout (`ghbdtn` -> `привет` / `привіт`), or
  - Cyrillic letters typed on EN layout.
- Rewrites the last word automatically.
- Updates extension badge with active language (`EN`, `RU`, `UA`).

## Configure language list

1. Open `chrome://extensions`
2. Find **LangSwitcher** and click **Details**
3. Open **Extension options**
4. Enable at least 2 languages from the list (EN/RU/UA)
5. Save settings

The content script immediately applies updated language list from storage.

## Important limitation

Chrome extensions generally **cannot switch your operating system keyboard layout** on Windows/macOS/Linux. This extension emulates that behavior by auto-correcting wrongly typed words and tracking an internal active language state.

## Install (developer mode)

1. Open `chrome://extensions`
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select this project folder

## Files

- `manifest.json` – extension manifest (MV3)
- `src/content.js` – typing tracker + auto rewrite logic
- `src/background.js` – badge + state updates
- `options/options.html` – configuration page
- `options/options.js` – settings persistence
- `options/options.css` – options page styles
