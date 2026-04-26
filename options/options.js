const DEFAULT_ENABLED_LANGS = ["en", "ru", "ua"];

const form = document.getElementById("lang-form");
const statusEl = document.getElementById("status");
const boxes = [...document.querySelectorAll('input[type="checkbox"]')];

init();

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const enabled = boxes.filter((box) => box.checked).map((box) => box.value);

  if (enabled.length < 2) {
    statusEl.textContent = "Choose at least 2 languages.";
    return;
  }

  await chrome.storage.local.set({ enabledLanguages: enabled });
  statusEl.textContent = "Saved.";
  setTimeout(() => {
    statusEl.textContent = "";
  }, 1600);
});

async function init() {
  const data = await chrome.storage.local.get("enabledLanguages");
  const enabled = Array.isArray(data.enabledLanguages) && data.enabledLanguages.length >= 2
    ? data.enabledLanguages
    : DEFAULT_ENABLED_LANGS;

  boxes.forEach((box) => {
    box.checked = enabled.includes(box.value);
  });
}
