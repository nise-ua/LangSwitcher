const DEFAULT_ENABLED_LANGS = ["en", "ru", "ua"];

const LAYOUTS = {
  ru: mapFromPairs([
    ["q", "й"], ["w", "ц"], ["e", "у"], ["r", "к"], ["t", "е"], ["y", "н"], ["u", "г"], ["i", "ш"], ["o", "щ"], ["p", "з"], ["[", "х"], ["]", "ъ"],
    ["a", "ф"], ["s", "ы"], ["d", "в"], ["f", "а"], ["g", "п"], ["h", "р"], ["j", "о"], ["k", "л"], ["l", "д"], [";", "ж"], ["'", "э"],
    ["z", "я"], ["x", "ч"], ["c", "с"], ["v", "м"], ["b", "и"], ["n", "т"], ["m", "ь"], [",", "б"], [".", "ю"], ["`", "ё"]
  ]),
  ua: mapFromPairs([
    ["q", "й"], ["w", "ц"], ["e", "у"], ["r", "к"], ["t", "е"], ["y", "н"], ["u", "г"], ["i", "ш"], ["o", "щ"], ["p", "з"], ["[", "х"], ["]", "ї"],
    ["a", "ф"], ["s", "і"], ["d", "в"], ["f", "а"], ["g", "п"], ["h", "р"], ["j", "о"], ["k", "л"], ["l", "д"], [";", "ж"], ["'", "є"],
    ["z", "я"], ["x", "ч"], ["c", "с"], ["v", "м"], ["b", "и"], ["n", "т"], ["m", "ь"], [",", "б"], [".", "ю"], ["`", "ґ"]
  ])
};

const CYR_TO_EN = Object.fromEntries(Object.entries(LAYOUTS).map(([lang, map]) => [lang, invertMap(map)]));

const HINT_WORDS = {
  ru: new Set(["привет", "как", "это", "что", "для", "всем", "я", "ты", "мы", "они"]),
  ua: new Set(["привіт", "як", "це", "що", "для", "усім", "я", "ти", "ми", "вони", "є", "її"]),
  en: new Set(["hello", "this", "with", "from", "report", "switch", "plugin", "language"])
};

let composing = false;
let enabledLanguages = [...DEFAULT_ENABLED_LANGS];
let activeLang = "en";

loadSettings();
chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  if (changes.enabledLanguages) {
    enabledLanguages = normalizeEnabled(changes.enabledLanguages.newValue);
    if (!enabledLanguages.includes(activeLang)) {
      activeLang = enabledLanguages[0];
    }
  }
  if (changes.activeLang?.newValue) {
    activeLang = changes.activeLang.newValue;
  }
});

document.addEventListener("compositionstart", () => (composing = true));
document.addEventListener("compositionend", () => (composing = false));
document.addEventListener("input", onInput, true);

async function loadSettings() {
  const data = await chrome.storage.local.get(["enabledLanguages", "activeLang"]);
  enabledLanguages = normalizeEnabled(data.enabledLanguages);
  activeLang = enabledLanguages.includes(data.activeLang) ? data.activeLang : enabledLanguages[0];
}

function onInput(event) {
  if (composing) return;
  const target = event.target;
  if (!isTextInput(target)) return;

  const value = target.value;
  const caret = target.selectionStart;
  if (caret == null || caret < 1) return;

  const justTyped = value[caret - 1];
  if (!/[\s.,!?;:()\[\]{}"'\-]/.test(justTyped)) return;

  const before = value.slice(0, caret - 1);
  const wordMatch = before.match(/([\p{L}`'.,;\[\]]+)$/u);
  if (!wordMatch) return;

  const wrongWord = wordMatch[1];
  const decision = chooseCorrection(wrongWord, enabledLanguages, activeLang);
  if (!decision || decision.corrected === wrongWord) return;

  const wordStart = before.length - wrongWord.length;
  const newValue = `${value.slice(0, wordStart)}${decision.corrected}${value.slice(wordStart + wrongWord.length)}`;
  const delta = decision.corrected.length - wrongWord.length;

  target.value = newValue;
  const newCaret = caret + delta;
  target.setSelectionRange(newCaret, newCaret);

  activeLang = decision.lang;
  chrome.runtime.sendMessage({ type: "langsw:set-active-lang", lang: decision.lang });
}

function chooseCorrection(word, enabled, preferredLang) {
  const lower = word.toLowerCase();
  const hasLatin = /[a-z]/i.test(lower);
  const hasCyr = /[а-яёіїєґ]/i.test(lower);

  if (hasLatin && !hasCyr) {
    const cyrEnabled = enabled.filter((lang) => lang !== "en" && LAYOUTS[lang]);
    if (!cyrEnabled.length) return null;

    if (preferredLang !== "en" && cyrEnabled.includes(preferredLang)) {
      const forced = transformWithCase(word, LAYOUTS[preferredLang]);
      if (forced !== word) {
        return { corrected: forced, lang: preferredLang };
      }
    }

    const candidates = cyrEnabled.map((lang) => {
      const corrected = transformWithCase(word, LAYOUTS[lang]);
      return { corrected, lang, score: scoreCyrCandidate(corrected, lang) };
    });

    return pickCandidate(candidates);
  }

  if (hasCyr && !hasLatin && enabled.includes("en")) {
    const cyrEnabled = enabled.filter((lang) => lang !== "en" && CYR_TO_EN[lang]);
    if (!cyrEnabled.length) return null;

    if (preferredLang === "en") {
      const preferredSource = cyrEnabled[0];
      const forced = transformWithCase(word, CYR_TO_EN[preferredSource]);
      if (forced !== word) {
        return { corrected: forced, lang: "en" };
      }
    }

    const candidates = cyrEnabled.map((lang) => {
      const corrected = transformWithCase(word, CYR_TO_EN[lang]);
      return { corrected, lang: "en", score: scoreEnCandidate(corrected) };
    });

    return pickCandidate(candidates);
  }

  return null;
}

function pickCandidate(candidates) {
  if (!candidates.length) return null;
  candidates.sort((a, b) => b.score - a.score);
  return candidates[0].score >= 0.35
    ? { corrected: candidates[0].corrected, lang: candidates[0].lang }
    : null;
}

function scoreCyrCandidate(word, lang) {
  const lower = word.toLowerCase();
  const vowels = (lower.match(/[аеёиоуыэюяіїє]/g) || []).length;
  const letters = (lower.match(/[а-яёіїєґ]/g) || []).length;
  const vowelRatio = letters ? vowels / letters : 0;
  const hintSet = HINT_WORDS[lang] || new Set();
  const hintBonus = hintSet.has(lower) ? 0.5 : 0;
  const specialBonus = lang === "ua" && /[іїєґ]/.test(lower) ? 0.2 : 0;
  const ratioScore = Math.max(0, 0.5 - Math.abs(vowelRatio - 0.42));
  return ratioScore + hintBonus + specialBonus;
}

function scoreEnCandidate(word) {
  const lower = word.toLowerCase();
  const letters = (lower.match(/[a-z]/g) || []).length;
  if (!letters) return 0;
  const vowels = (lower.match(/[aeiouy]/g) || []).length;
  const ratioScore = Math.max(0, 0.5 - Math.abs(vowels / letters - 0.4));
  const hintBonus = HINT_WORDS.en.has(lower) ? 0.5 : 0;
  const bigramBonus = /(th|he|in|er|re|on|an|st|ing)/.test(lower) ? 0.15 : 0;
  return ratioScore + hintBonus + bigramBonus;
}

function transformWithCase(source, map) {
  return [...source].map((ch) => {
    const lower = ch.toLowerCase();
    const mapped = map[lower] ?? ch;
    return ch === lower ? mapped : mapped.toUpperCase();
  }).join("");
}

function mapFromPairs(pairs) {
  return Object.fromEntries(pairs);
}

function invertMap(map) {
  const inverted = {};
  for (const [k, v] of Object.entries(map)) {
    inverted[v] = k;
  }
  return inverted;
}

function normalizeEnabled(value) {
  const valid = ["en", "ru", "ua"];
  const enabled = Array.isArray(value) ? value.filter((lang) => valid.includes(lang)) : [];
  return enabled.length >= 2 ? [...new Set(enabled)] : [...DEFAULT_ENABLED_LANGS];
}

function isTextInput(el) {
  return el && (el.tagName === "TEXTAREA" || (el.tagName === "INPUT" && (!el.type || el.type === "text" || el.type === "search" || el.type === "email")));
}
