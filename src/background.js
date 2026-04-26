const DEFAULT_ENABLED_LANGS = ["en", "ru", "ua"];

chrome.runtime.onInstalled.addListener(async () => {
  const data = await chrome.storage.local.get(["activeLang", "enabledLanguages"]);
  const enabled = normalizeEnabled(data.enabledLanguages);

  await chrome.storage.local.set({ enabledLanguages: enabled });

  const activeLang = enabled.includes(data.activeLang) ? data.activeLang : enabled[0];
  await chrome.storage.local.set({ activeLang });
  updateBadge(activeLang);
});

chrome.runtime.onMessage.addListener(async (message) => {
  if (message?.type === "langsw:set-active-lang" && message.lang) {
    const { enabledLanguages } = await chrome.storage.local.get("enabledLanguages");
    const enabled = normalizeEnabled(enabledLanguages);
    if (!enabled.includes(message.lang)) return;

    await chrome.storage.local.set({ activeLang: message.lang });
    updateBadge(message.lang);
  }
});

chrome.storage.onChanged.addListener(async (changes, areaName) => {
  if (areaName !== "local" || !changes.enabledLanguages) return;

  const enabled = normalizeEnabled(changes.enabledLanguages.newValue);
  await chrome.storage.local.set({ enabledLanguages: enabled });

  const { activeLang } = await chrome.storage.local.get("activeLang");
  const next = enabled.includes(activeLang) ? activeLang : enabled[0];
  await chrome.storage.local.set({ activeLang: next });
  updateBadge(next);
});

async function updateBadge(lang) {
  const text = String(lang || "en").toUpperCase().slice(0, 2);
  await chrome.action.setBadgeText({ text });
  await chrome.action.setBadgeBackgroundColor({ color: badgeColor(lang) });
}

function normalizeEnabled(value) {
  const valid = ["en", "ru", "ua"];
  const enabled = Array.isArray(value) ? value.filter((lang) => valid.includes(lang)) : [];
  return enabled.length >= 2 ? [...new Set(enabled)] : [...DEFAULT_ENABLED_LANGS];
}

function badgeColor(lang) {
  switch (lang) {
    case "ru":
      return "#1565C0";
    case "ua":
      return "#F9A825";
    default:
      return "#2E7D32";
  }
}
