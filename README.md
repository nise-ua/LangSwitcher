# LangSwitcher

A system-wide keyboard layout auto-corrector for **macOS** and **Windows**.

Ever typed a whole sentence only to realize you were in the wrong keyboard layout (e.g., `ghbdsn` instead of `привіт`)? LangSwitcher runs silently in the background and automatically detects when you type a word in the wrong layout. It instantly erases it, translates it to the correct layout, re-types it, and switches your OS keyboard language!

![LangSwitcher](https://img.shields.io/badge/Status-Active-brightgreen) ![macOS](https://img.shields.io/badge/macOS-Native-black?logo=apple) ![Windows](https://img.shields.io/badge/Windows-Supported-blue?logo=windows)

## 🌟 Features
- **Auto-Correction**: Instantly fixes mistyped words across *any* application.
- **Quick Correct Hotkey**: If a word wasn't auto-corrected, simply double-tap your modifier key (Command ⌘ on Mac, Ctrl on Windows) to force the correction! The app automatically learns this mapping for next time.
- **Custom Exceptions**: Easily add specific acronyms (e.g. `IT`) or enforce your own translations (e.g. `ghbdsn=привіт`).
- **Smart OS Sync**: Keeps track of your system language seamlessly. The menu bar icon changes color to show your current layout (Blue = EN, Yellow = UA, Red = RU).

---

## 📥 Installation

There is absolutely **no compilation or terminal required**. Just download, run, and go!

### 🍏 macOS
1. Go to the [Releases](../../releases) page and download `LangSwitcher-macOS.zip`.
2. Extract the ZIP file.
3. Drag `LangSwitcher.app` into your **Applications** folder and double-click to launch it.
4. **Permissions**: macOS requires Accessibility permissions to intercept keystrokes.
   - Open **System Settings** → **Privacy & Security** → **Accessibility**.
   - Check the box next to `LangSwitcher`.
5. You'll see the LangSwitcher icon appear in your top Menu Bar!

### 🪟 Windows
1. Go to the [Releases](../../releases) page and download `LangSwitcher-Windows.exe`.
2. Move the `.exe` file to a folder of your choice.
3. Double-click `LangSwitcher-Windows.exe` to run it.
4. The LangSwitcher icon will appear in your System Tray (bottom right corner).
   - *(Tip: You can place a shortcut to the `.exe` in your `shell:startup` folder to have it launch automatically when Windows starts).*

---

## 🛠 How to Use

Once running, LangSwitcher works entirely automatically in the background.

### Auto-Correction
Just type normally. If you accidentally type `ghbdsn ` (with a space or punctuation at the end), it will instantly delete the word, type `привіт `, and switch your system layout to Ukrainian!

### Quick Correct Hotkey
Sometimes a word is skipped because it looks like a valid English word. No problem!
1. Type your word.
2. **Double-tap your hotkey** (Default: `Command ⌘` on Mac, `Ctrl` on Windows). 
3. It will instantly translate the word *and* save it to your dictionary so it auto-corrects automatically next time!
*(You can customize the hotkey by clicking the LangSwitcher menu icon).*

### Managing Exceptions
Want to tweak the dictionary? Click the menu bar/tray icon and select **"Manage Exceptions..."**. This opens a simple text editor.
- **Ignore a word**: Just type the word on a new line (e.g., `git`). The app will never try to auto-correct it.
- **Force a translation**: Type `wrong=right` on a new line (e.g., `ghbdsn=привіт`).

### Supported Languages
By default, the app supports seamlessly swapping between **English (EN)** and **Ukrainian (UA)** (and Russian (RU)). You can easily toggle which languages are active directly from the menu.
