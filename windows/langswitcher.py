import json
import logging
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
import pystray
from pynput import keyboard

# ─────────────────────────────────────────────────────────────────────────────
# Logging  (%APPDATA%\LangSwitcher\LangSwitcher.log)
# ─────────────────────────────────────────────────────────────────────────────
def _setup_logging():
    log_dir = Path(os.environ.get("APPDATA", Path.home())) / "LangSwitcher"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "LangSwitcher.log"
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(log_file, encoding="utf-8"),
            logging.StreamHandler(sys.stderr),
        ],
    )
    return log_file

LOG_FILE = _setup_logging()
log = logging.getLogger("langswitcher")
log.info("Starting LangSwitcher. Log: %s", LOG_FILE)

# ─────────────────────────────────────────────────────────────────────────────
# OS Input Source switching
# ─────────────────────────────────────────────────────────────────────────────
WINDOWS_LOCALE_MAP = {
    "en": "0409",   # English (US)
    "ru": "0419",   # Russian
    "ua": "0422",   # Ukrainian
}

def switch_os_layout(lang: str) -> bool:
    """Switch Windows keyboard layout via PowerShell."""
    locale = WINDOWS_LOCALE_MAP.get(lang)
    if not locale:
        return False
    try:
        script = f"""
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.InputLanguage]::InstalledInputLanguages |
  Where-Object {{ $_.Culture.LCID -eq [int]"0x{locale}" }} |
  Select-Object -First 1 |
  ForEach-Object {{ [System.Windows.Forms.InputLanguage]::CurrentInputLanguage = $_ }}
"""
        subprocess.run(["powershell", "-Command", script], check=True, capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0)
        return True
    except Exception as e:
        log.warning("Windows layout switch failed: %s", e)
        return False

# ─────────────────────────────────────────────────────────────────────────────
# Layout maps  (EN key → Cyrillic letter)
# ─────────────────────────────────────────────────────────────────────────────
_RU_PAIRS = [
    ("q","й"),("w","ц"),("e","у"),("r","к"),("t","е"),("y","н"),("u","г"),
    ("i","ш"),("o","щ"),("p","з"),("[","х"),("]","ъ"),
    ("a","ф"),("s","ы"),("d","в"),("f","а"),("g","п"),("h","р"),("j","о"),
    ("k","л"),("l","д"),(";","ж"),("'","э"),
    ("z","я"),("x","ч"),("c","с"),("v","м"),("b","и"),("n","т"),("m","ь"),
    (",","б"),(".","ю"),('`',"ё"),
]
_UA_PAIRS = [
    ("q","й"),("w","ц"),("e","у"),("r","к"),("t","е"),("y","н"),("u","г"),
    ("i","ш"),("o","щ"),("p","з"),("[","х"),("]","ї"),
    ("a","ф"),("s","і"),("d","в"),("f","а"),("g","п"),("h","р"),("j","о"),
    ("k","л"),("l","д"),(";","ж"),("'","є"),
    ("z","я"),("x","ч"),("c","с"),("v","м"),("b","и"),("n","т"),("m","ь"),
    (",","б"),(".","ю"),('`',"ґ"),
]

LAYOUTS = {"ru": dict(_RU_PAIRS), "ua": dict(_UA_PAIRS)}
CYR_TO_EN = {lang: {v: k for k, v in layout.items()} for lang, layout in LAYOUTS.items()}

HINT_WORDS = {
    "ru": {"привет","как","это","что","для","всем","я","ты","мы","они"},
    "ua": {"привіт","як","це","що","для","усім","я","ти","ми","вони","є","її"},
    "en": {"hello","this","with","from","report","switch","plugin","language"},
}

WORD_BOUNDARY = set(" \t\n.,!?;:()[]{}\"'-")
BADGE_COLORS = {"ru": (217, 51, 51), "ua": (250, 204, 0), "en": (0, 120, 255)}
VALID_LANGS = ["en", "ru", "ua"]
DEFAULT_ENABLED = ["en", "ru", "ua"]

# Custom Exceptions Dictionaries
CUSTOM_EXCEPTIONS = set()
CUSTOM_MAPPINGS = {}

def _exceptions_path() -> Path:
    return Path(os.environ.get("APPDATA", Path.home())) / "LangSwitcher" / "exceptions.txt"

def load_custom_dictionaries():
    global CUSTOM_EXCEPTIONS, CUSTOM_MAPPINGS
    CUSTOM_EXCEPTIONS.clear()
    CUSTOM_MAPPINGS.clear()
    
    path = _exceptions_path()
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# Add words to ignore (e.g. IT acronyms) one per line.\n# To force a translation, use: original=corrected\n", encoding="utf-8")
        return
        
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"): continue
        
        if "=" in line:
            parts = line.split("=", 1)
            orig = parts[0].strip().lower()
            corr = parts[1].strip()
            if orig and corr:
                CUSTOM_MAPPINGS[orig] = corr
        else:
            CUSTOM_EXCEPTIONS.add(line.lower())

def save_custom_dictionary_entry(orig: str, corr: str):
    path = _exceptions_path()
    with path.open("a", encoding="utf-8") as f:
        f.write(f"\n{orig}={corr}\n")
    load_custom_dictionaries()


# ─────────────────────────────────────────────────────────────────────────────
# Settings persistence
# ─────────────────────────────────────────────────────────────────────────────
def _settings_path() -> Path:
    return Path(os.environ.get("APPDATA", Path.home())) / "LangSwitcher" / "settings.json"

def load_settings() -> dict:
    path = _settings_path()
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"enabledLanguages": DEFAULT_ENABLED, "activeLang": "en", "hotkey": "ctrl"}

def save_settings(data: dict):
    _settings_path().write_text(json.dumps(data, indent=2), encoding="utf-8")

# ─────────────────────────────────────────────────────────────────────────────
# Language correction logic
# ─────────────────────────────────────────────────────────────────────────────
def _is_latin(ch: str) -> bool: return ch.lower() in "abcdefghijklmnopqrstuvwxyz"
def _is_cyr(ch: str) -> bool: return bool(ch) and '\u0400' <= ch.lower() <= '\u04ff'
def _has_latin(word: str) -> bool: return any(_is_latin(c) for c in word)
def _has_cyr(word: str) -> bool: return any(_is_cyr(c) for c in word)

def _transform_with_case(source: str, mapping: dict) -> str:
    result = []
    for ch in source:
        lower = ch.lower()
        mapped = mapping.get(lower, ch)
        result.append(mapped.upper() if ch != lower else mapped)
    return "".join(result)

def choose_correction(word: str, enabled: list):
    """Return (corrected_word, target_lang) or None."""
    if not word: return None
    lower = word.lower()
    
    # Custom mappings strictly override everything
    if lower in CUSTOM_MAPPINGS:
        corr = CUSTOM_MAPPINGS[lower]
        target_lang = "en" if _has_latin(corr) else ("ua" if "ї" in corr or "є" in corr or "і" in corr or "ґ" in corr else "ru")
        return (_transform_with_case(lower, {k: v for k, v in zip(lower, corr.lower())}), target_lang)
        
    if lower in CUSTOM_EXCEPTIONS:
        return None
        
    if len(word) < 3: return None

    if _has_latin(word) and not _has_cyr(word):
        candidates = []
        for lang in enabled:
            if lang == "en" or lang not in LAYOUTS: continue
            corrected = _transform_with_case(word, LAYOUTS[lang])
            if lower in HINT_WORDS.get(lang, set()):
                return (corrected, lang) # Immediate accept if matches dictionary
            
            # Simplified heuristic for Windows: only auto-correct if strictly Cyrillic valid
            letters = [c for c in corrected.lower() if _is_cyr(c)]
            if letters:
                vowels = [c for c in letters if c in "аеёиоуыэюяіїє"]
                ratio = len(vowels) / len(letters)
                if 0.2 <= ratio <= 0.6:
                    candidates.append((corrected, lang))
                    
        if candidates: return candidates[0]

    elif _has_cyr(word) and not _has_latin(word) and "en" in enabled:
        for lang in enabled:
            if lang == "en" or lang not in CYR_TO_EN: continue
            corrected = _transform_with_case(word, CYR_TO_EN[lang])
            # If strictly english chars
            if not _has_cyr(corrected):
                return (corrected, "en")
    return None

def force_translate(word: str, lang_hint: str):
    if not word: return word, "en"
    if _has_latin(word):
        target = lang_hint if lang_hint in ["ru", "ua"] else "ru"
        return _transform_with_case(word, LAYOUTS[target]), target
    else:
        target = "en"
        # determine if it was typed in UA or RU layout
        is_ua = any(c in "іїєґ" for c in word.lower())
        src = "ua" if is_ua else "ru"
        return _transform_with_case(word, CYR_TO_EN[src]), target

# ─────────────────────────────────────────────────────────────────────────────
# Tray icon rendering
# ─────────────────────────────────────────────────────────────────────────────
def _make_icon(lang: str, size: int = 64) -> Image.Image:
    color = BADGE_COLORS.get(lang, (0, 120, 255))
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([0, 0, size - 1, size - 1], fill=color)
    label = lang.upper()[:2]
    try:
        font = ImageFont.truetype("arial.ttf", size // 3)
    except Exception:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((size - tw) // 2, (size - th) // 2), label, fill="white", font=font)
    return img

# ─────────────────────────────────────────────────────────────────────────────
# Main App
# ─────────────────────────────────────────────────────────────────────────────
class LangSwitcherApp:
    def __init__(self):
        load_custom_dictionaries()
        cfg = load_settings()
        self.enabled_langs = [l for l in cfg.get("enabledLanguages", DEFAULT_ENABLED) if l in VALID_LANGS]
        self.active_lang = cfg.get("activeLang", self.enabled_langs[0])
        self.hotkey = cfg.get("hotkey", "ctrl")
        if self.active_lang not in self.enabled_langs:
            self.active_lang = self.enabled_langs[0]

        self._word_buf = []
        self._last_word = ""
        self._last_boundary = ""
        self._injecting = False

        # Hotkey tracking
        self._last_hotkey_time = 0
        self._hotkey_count = 0
        
        self._tray = None
        self._listener = None
        self._ctrl = keyboard.Controller()

    def _save(self):
        save_settings({"enabledLanguages": self.enabled_langs, "activeLang": self.active_lang, "hotkey": self.hotkey})

    def _set_lang(self, lang: str, switch_os: bool = True):
        if lang not in self.enabled_langs: return
        self.active_lang = lang
        self._save()
        if switch_os:
            threading.Thread(target=switch_os_layout, args=(lang,), daemon=True).start()
        if self._tray:
            try:
                self._tray.icon = _make_icon(lang)
                self._tray.title = f"LangSwitcher — {lang.upper()}"
                self._tray.update_menu()
            except Exception: pass

    def _handle_double_hotkey(self):
        word = self._last_word
        boundary = self._last_boundary
        if not word: return
        log.info("Double-hotkey triggered! Translating: %s", word)
        
        corr, lang = force_translate(word, "ru" if "ru" in self.enabled_langs else "ua")
        save_custom_dictionary_entry(word, corr)
        
        self._injecting = True
        try:
            total_backspaces = len(word) + len(boundary)
            for _ in range(total_backspaces):
                self._ctrl.press(keyboard.Key.backspace)
                self._ctrl.release(keyboard.Key.backspace)
                time.sleep(0.005)
            time.sleep(0.02)
            self._ctrl.type(corr + boundary)
            self._last_word = corr
        finally:
            self._injecting = False
        
        self._set_lang(lang, switch_os=True)

    def _on_press(self, key):
        if self._injecting: return
        
        # Hotkey tracking
        is_trigger = False
        if self.hotkey == "ctrl" and key in (keyboard.Key.ctrl_l, keyboard.Key.ctrl_r): is_trigger = True
        if self.hotkey == "alt" and key in (keyboard.Key.alt_l, keyboard.Key.alt_r, keyboard.Key.alt_gr): is_trigger = True
        if self.hotkey == "cmd" and key in (keyboard.Key.cmd, keyboard.Key.cmd_r): is_trigger = True
        
        if is_trigger:
            now = time.time()
            if now - self._last_hotkey_time < 0.4:
                self._hotkey_count += 1
                if self._hotkey_count == 2:
                    self._hotkey_count = 0
                    self._handle_double_hotkey()
            else:
                self._hotkey_count = 1
            self._last_hotkey_time = now
            return
            
        if hasattr(key, 'name') and key.name in ('shift', 'shift_r'):
            return

        if key == keyboard.Key.backspace:
            if self._word_buf: self._word_buf.pop()
            return

        if key in (keyboard.Key.space, keyboard.Key.enter, keyboard.Key.tab):
            word = "".join(self._word_buf)
            self._word_buf.clear()
            if word:
                self._last_word = word
                self._last_boundary = " " if key == keyboard.Key.space else ("\n" if key == keyboard.Key.enter else "\t")
                threading.Thread(target=self._try_correct, args=(word,), daemon=True).start()
            return

        if hasattr(key, 'name') and key.name in ('left', 'right', 'up', 'down', 'home', 'end', 'esc'):
            self._word_buf.clear()
            return

        try: ch = key.char
        except AttributeError: ch = ""
        if not ch: return

        if ch in WORD_BOUNDARY:
            word = "".join(self._word_buf)
            self._word_buf.clear()
            if word:
                self._last_word = word
                self._last_boundary = ch
                threading.Thread(target=self._try_correct, args=(word,), daemon=True).start()
        else:
            self._word_buf.append(ch)

    def _on_release(self, key):
        pass

    def _try_correct(self, word: str):
        result = choose_correction(word, self.enabled_langs)
        if not result: return
        corrected, lang = result
        if corrected == word: return
        self._last_word = corrected
        self._inject(word, corrected, lang)

    def _inject(self, original: str, corrected: str, lang: str):
        self._injecting = True
        try:
            time.sleep(0.08)
            for _ in range(len(original)):
                self._ctrl.press(keyboard.Key.backspace)
                self._ctrl.release(keyboard.Key.backspace)
                time.sleep(0.005)
            time.sleep(0.02)
            self._ctrl.type(corrected)
        finally:
            self._injecting = False
        self._set_lang(lang, switch_os=False)

    # ── Tray menu ─────────────────────────────────────────────────────────
    def _menu_lang_item(self, lang: str):
        def _action(icon, item): self._set_lang(lang, switch_os=True)
        return pystray.MenuItem(
            lambda item: f"{'● ' if self.active_lang == lang else '   '}{lang.upper()}",
            _action, checked=lambda item: self.active_lang == lang,
        )

    def _toggle_lang(self, lang: str):
        def _action(icon, item):
            if lang in self.enabled_langs:
                if len(self.enabled_langs) <= 2: return
                self.enabled_langs.remove(lang)
                if self.active_lang == lang: self.active_lang = self.enabled_langs[0]
            else:
                self.enabled_langs.append(lang)
            self._save()
            if self._tray: self._tray.update_menu()
        return pystray.MenuItem(
            lambda item: f"{'✓ ' if lang in self.enabled_langs else '   '}{lang.upper()} enabled",
            _action, checked=lambda item: lang in self.enabled_langs,
        )
        
    def _set_hotkey(self, hk: str):
        def _action(icon, item):
            self.hotkey = hk
            self._save()
            if self._tray: self._tray.update_menu()
        return pystray.MenuItem(
            lambda item: f"{'✓ ' if self.hotkey == hk else '   '}Double {hk.capitalize()}",
            _action, checked=lambda item: self.hotkey == hk,
        )
        
    def _open_exceptions(self, icon, item):
        path = _exceptions_path()
        if not path.exists(): load_custom_dictionaries()
        os.startfile(str(path))

    def _build_menu(self) -> pystray.Menu:
        return pystray.Menu(
            pystray.MenuItem("LangSwitcher", None, enabled=False),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Switch layout", pystray.Menu(*[self._menu_lang_item(l) for l in VALID_LANGS])),
            pystray.MenuItem("Quick Correct Hotkey", pystray.Menu(
                self._set_hotkey("ctrl"), self._set_hotkey("alt"), self._set_hotkey("cmd")
            )),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Manage Exceptions...", self._open_exceptions),
            pystray.MenuItem("Auto-correct langs", pystray.Menu(*[self._toggle_lang(l) for l in VALID_LANGS])),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", self._on_quit),
        )

    def _on_quit(self, icon, item):
        if self._listener: self._listener.stop()
        icon.stop()

    def run(self):
        self._listener = keyboard.Listener(on_press=self._on_press, on_release=self._on_release)
        self._listener.start()
        self._tray = pystray.Icon("LangSwitcher", _make_icon(self.active_lang), f"LangSwitcher — {self.active_lang.upper()}", menu=self._build_menu())
        self._tray.run()

if __name__ == "__main__":
    app = LangSwitcherApp()
    app.run()
