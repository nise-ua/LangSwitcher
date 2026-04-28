using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LangSwitcher
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            Logger.Log("LangSwitcher Application Started.");
            try
            {
                using (var app = new LangSwitcherApp())
                {
                    Application.Run();
                }
            }
            catch (Exception ex)
            {
                Logger.Log($"FATAL ERROR: {ex}");
            }
            Logger.Log("LangSwitcher Application Exited.");
        }
    }

    static class Logger
    {
        private static string _logFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "LangSwitcher", "langswitcher.log");
        private static object _lock = new object();

        public static void Log(string message)
        {
            try
            {
                lock (_lock)
                {
                    File.AppendAllText(_logFile, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}\n");
                }
            }
            catch { }
        }
    }

    class Settings
    {
        public List<string> EnabledLanguages { get; set; } = new() { "en", "ru", "ua" };
        public string ActiveLang { get; set; } = "en";
        public string Hotkey { get; set; } = "ctrl";
    }

    class LangSwitcherApp : IDisposable
    {
        private NotifyIcon _trayIcon;
        private GlobalKeyboardHook _hook;
        private System.Windows.Forms.Timer _syncTimer;
        private Settings _settings;
        private string _settingsPath;
        private string _exceptionsPath;

        private List<char> _wordBuf = new();
        private string _lastWord = "";
        private char _lastBoundary = '\0';
        private bool _injecting = false;

        private long _lastHotkeyTime = 0;
        private int _hotkeyCount = 0;

        private HashSet<string> _customExceptions = new(StringComparer.OrdinalIgnoreCase);
        private Dictionary<string, string> _customMappings = new(StringComparer.OrdinalIgnoreCase);

        private static readonly Dictionary<string, (uint Hkl, Color Color)> _langInfo = new()
        {
            { "en", (0x04090409, Color.FromArgb(0, 120, 255)) }, // US English
            { "ru", (0x04190419, Color.FromArgb(217, 51, 51)) },   // Russian
            { "ua", (0x04220422, Color.FromArgb(250, 204, 0)) }    // Ukrainian
        };

        public LangSwitcherApp()
        {
            var appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "LangSwitcher");
            Directory.CreateDirectory(appData);
            _settingsPath = Path.Combine(appData, "settings.json");
            _exceptionsPath = Path.Combine(appData, "exceptions.txt");

            LoadSettings();
            LoadDictionaries();

            _trayIcon = new NotifyIcon
            {
                Text = "LangSwitcher",
                Visible = true
            };
            UpdateTrayIcon();

            _hook = new GlobalKeyboardHook();
            _hook.KeyDown += Hook_KeyDown;

            _syncTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            _syncTimer.Tick += SyncTimer_Tick;
            _syncTimer.Start();
        }

        private void SyncTimer_Tick(object? sender, EventArgs e)
        {
            if (_injecting) return;

            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return;
            uint threadId = GetWindowThreadProcessId(hwnd, out _);
            IntPtr hkl = GetKeyboardLayout(threadId);
            uint hklValue = (uint)hkl.ToInt64();

            foreach (var kvp in _langInfo)
            {
                // Match by language ID (low word)
                if ((hklValue & 0xFFFF) == (kvp.Value.Hkl & 0xFFFF))
                {
                    if (_settings.ActiveLang != kvp.Key)
                    {
                        Logger.Log($"Sync: OS layout changed to {kvp.Key} (HKL: 0x{hklValue:X8})");
                        _settings.ActiveLang = kvp.Key;
                        UpdateTrayIcon();
                    }
                    break;
                }
            }
        }

        private void LoadSettings()
        {
            if (File.Exists(_settingsPath))
            {
                try
                {
                    _settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText(_settingsPath)) ?? new Settings();
                }
                catch { _settings = new Settings(); }
            }
            else
            {
                _settings = new Settings();
            }
            if (!_settings.EnabledLanguages.Contains(_settings.ActiveLang))
                _settings.ActiveLang = _settings.EnabledLanguages.FirstOrDefault() ?? "en";
        }

        private void SaveSettings()
        {
            File.WriteAllText(_settingsPath, JsonSerializer.Serialize(_settings, new JsonSerializerOptions { WriteIndented = true }));
        }

        private void LoadDictionaries()
        {
            _customExceptions.Clear();
            _customMappings.Clear();

            if (!File.Exists(_exceptionsPath))
            {
                File.WriteAllText(_exceptionsPath, "# Add words to ignore (e.g. IT acronyms) one per line.\n# To force a translation, use: original=corrected\n");
                return;
            }

            foreach (var line in File.ReadAllLines(_exceptionsPath))
            {
                var trimmed = line.Trim();
                if (string.IsNullOrEmpty(trimmed) || trimmed.StartsWith("#")) continue;

                if (trimmed.Contains("="))
                {
                    var parts = trimmed.Split(new[] { '=' }, 2);
                    var orig = parts[0].Trim().ToLower();
                    var corr = parts[1].Trim();
                    if (!string.IsNullOrEmpty(orig) && !string.IsNullOrEmpty(corr))
                        _customMappings[orig] = corr;
                }
                else
                {
                    _customExceptions.Add(trimmed.ToLower());
                }
            }
        }

        private void SaveCustomDictionaryEntry(string orig, string corr)
        {
            File.AppendAllText(_exceptionsPath, $"\n{orig}={corr}\n");
            LoadDictionaries();
        }

        private void UpdateTrayIcon()
        {
            var color = _langInfo.TryGetValue(_settings.ActiveLang, out var info) ? info.Color : Color.Gray;
            var text = _settings.ActiveLang.ToUpper();

            using var bmp = new Bitmap(64, 64);
            using var g = Graphics.FromImage(bmp);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            using var brush = new SolidBrush(color);
            g.FillEllipse(brush, 0, 0, 63, 63);

            using var font = new Font("Arial", 20, FontStyle.Bold);
            var size = g.MeasureString(text, font);
            g.DrawString(text, font, Brushes.White, (64 - size.Width) / 2, (64 - size.Height) / 2);

            var oldIcon = _trayIcon.Icon;
            _trayIcon.Icon = Icon.FromHandle(bmp.GetHicon());
            if (oldIcon != null) DestroyIcon(oldIcon.Handle);

            _trayIcon.Text = $"LangSwitcher — {text}";
            BuildMenu();
        }

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        extern static bool DestroyIcon(IntPtr handle);

        private void BuildMenu()
        {
            var menu = new ContextMenuStrip();
            
            var switchItem = new ToolStripMenuItem("Switch layout");
            foreach (var lang in _langInfo.Keys)
            {
                var item = new ToolStripMenuItem($"{(_settings.ActiveLang == lang ? "● " : "   ")}{lang.ToUpper()}");
                item.Click += (s, e) => SetLang(lang, true);
                switchItem.DropDownItems.Add(item);
            }
            menu.Items.Add(switchItem);

            var hotkeyItem = new ToolStripMenuItem("Quick Correct Hotkey");
            foreach (var hk in new[] { "ctrl", "alt", "cmd" })
            {
                var item = new ToolStripMenuItem($"{(_settings.Hotkey == hk ? "✓ " : "   ")}Double {char.ToUpper(hk[0]) + hk.Substring(1)}");
                item.Click += (s, e) => { _settings.Hotkey = hk; SaveSettings(); BuildMenu(); };
                hotkeyItem.DropDownItems.Add(item);
            }
            menu.Items.Add(hotkeyItem);

            menu.Items.Add(new ToolStripSeparator());

            var exceptionsItem = new ToolStripMenuItem("Manage Exceptions...");
            exceptionsItem.Click += (s, e) => {
                if (!File.Exists(_exceptionsPath)) LoadDictionaries();
                Process.Start(new ProcessStartInfo(_exceptionsPath) { UseShellExecute = true });
            };
            menu.Items.Add(exceptionsItem);

            var toggleLangsItem = new ToolStripMenuItem("Auto-correct langs");
            foreach (var lang in _langInfo.Keys)
            {
                var enabled = _settings.EnabledLanguages.Contains(lang);
                var item = new ToolStripMenuItem($"{(enabled ? "✓ " : "   ")}{lang.ToUpper()} enabled");
                item.Click += (s, e) => {
                    if (enabled && _settings.EnabledLanguages.Count > 1)
                    {
                        _settings.EnabledLanguages.Remove(lang);
                        if (_settings.ActiveLang == lang) SetLang(_settings.EnabledLanguages[0], true);
                    }
                    else if (!enabled)
                    {
                        _settings.EnabledLanguages.Add(lang);
                    }
                    SaveSettings(); BuildMenu();
                };
                toggleLangsItem.DropDownItems.Add(item);
            }
            menu.Items.Add(toggleLangsItem);

            menu.Items.Add(new ToolStripSeparator());
            
            var quitItem = new ToolStripMenuItem("Quit");
            quitItem.Click += (s, e) => Application.Exit();
            menu.Items.Add(quitItem);

            _trayIcon.ContextMenuStrip = menu;
        }

        private void SetLang(string lang, bool switchOs)
        {
            if (!_settings.EnabledLanguages.Contains(lang)) return;
            _settings.ActiveLang = lang;
            SaveSettings();
            UpdateTrayIcon();

            if (switchOs && _langInfo.TryGetValue(lang, out var info))
            {
                var hwnd = GetForegroundWindow();
                if (hwnd != IntPtr.Zero)
                {
                    // Pass 1: standard request
                    PostMessage(hwnd, 0x0050, IntPtr.Zero, (IntPtr)info.Hkl);
                    // Pass 2: slightly different wParam, some apps prefer this
                    PostMessage(hwnd, 0x0050, (IntPtr)1, (IntPtr)info.Hkl);
                }
            }
        }

        [DllImport("user32.dll")]
        static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        private void Hook_KeyDown(object sender, GlobalKeyboardHookEventArgs e)
        {
            if (_injecting) return;

            var key = e.KeyboardData.VirtualCode;
            Logger.Log($"KeyDown: {key} (0x{key:X})");

            // Hotkey tracking
            bool isTrigger = false;
            if (_settings.Hotkey == "ctrl" && (key == 0xA2 || key == 0xA3)) isTrigger = true; // LControl, RControl
            if (_settings.Hotkey == "alt" && (key == 0xA4 || key == 0xA5)) isTrigger = true; // LMenu, RMenu
            if (_settings.Hotkey == "cmd" && (key == 0x5B || key == 0x5C)) isTrigger = true; // LWin, RWin

            if (isTrigger)
            {
                long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                if (now - _lastHotkeyTime < 400)
                {
                    _hotkeyCount++;
                    if (_hotkeyCount == 2)
                    {
                        _hotkeyCount = 0;
                        HandleDoubleHotkey();
                    }
                }
                else
                {
                    _hotkeyCount = 1;
                }
                _lastHotkeyTime = now;
                return;
            }

            if (key == 0x10 || key == 0xA0 || key == 0xA1) return; // Shift

            if (key == 0x08) // Backspace
            {
                if (_wordBuf.Count > 0) _wordBuf.RemoveAt(_wordBuf.Count - 1);
                return;
            }

            if (key == 0x20 || key == 0x0D || key == 0x09) // Space, Enter, Tab
            {
                ProcessWord(key == 0x20 ? ' ' : (key == 0x0D ? '\n' : '\t'));
                return;
            }

            if (key >= 0x25 && key <= 0x28 || key == 0x24 || key == 0x23 || key == 0x1B) // Arrows, Home, End, Esc
            {
                _wordBuf.Clear();
                return;
            }

            // Get char
            char ch = GetCharFromKey(e.KeyboardData);
            if (ch == '\0') return;

            if (" \t\n.,!?;:()[]{}\"'-".Contains(ch))
            {
                ProcessWord(ch);
            }
            else
            {
                _wordBuf.Add(ch);
            }
        }

        private void ProcessWord(char boundary)
        {
            var word = new string(_wordBuf.ToArray());
            _wordBuf.Clear();
            Logger.Log($"ProcessWord: '{word}', boundary: '{boundary}'");
            if (!string.IsNullOrEmpty(word))
            {
                _lastWord = word;
                _lastBoundary = boundary;
                Task.Run(() => TryCorrect(word, boundary));
            }
        }

        private char GetCharFromKey(GlobalKeyboardHook.KeyboardHookStruct kb)
        {
            var keyboardState = new byte[256];
            GetKeyboardState(keyboardState);
            var sb = new StringBuilder(2);
            var hkl = GetKeyboardLayout(GetWindowThreadProcessId(GetForegroundWindow(), out _));
            if (ToUnicodeEx(kb.VirtualCode, kb.ScanCode, keyboardState, sb, sb.Capacity, 0, hkl) > 0)
                return sb[0];
            return '\0';
        }

        [DllImport("user32.dll")]
        static extern bool GetKeyboardState(byte[] lpKeyState);
        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        [DllImport("user32.dll")]
        static extern IntPtr GetKeyboardLayout(uint idThread);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern int ToUnicodeEx(uint wVirtKey, uint wScanCode, byte[] lpKeyState, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff, int cchBuff, uint wFlags, IntPtr dwhkl);

        private void TryCorrect(string word, char boundary)
        {
            var (corrected, lang) = Translator.ChooseCorrection(word, _settings.EnabledLanguages, _customMappings, _customExceptions);
            Logger.Log($"TryCorrect: word='{word}', corrected='{corrected}', targetLang='{lang}'");
            if (corrected == null || corrected == word) return;

            _lastWord = corrected;
            Inject(word, corrected, lang, boundary);
        }

        private void HandleDoubleHotkey()
        {
            if (string.IsNullOrEmpty(_lastWord)) return;
            var (corr, lang) = Translator.ForceTranslate(_lastWord, _settings.EnabledLanguages.Contains("ru") ? "ru" : "ua");
            Logger.Log($"HandleDoubleHotkey: word='{_lastWord}', force corrected='{corr}', lang='{lang}'");
            SaveCustomDictionaryEntry(_lastWord, corr);

            _injecting = true;
            try
            {
                // Match macOS timing (80ms) for better reliability
                Thread.Sleep(80);
                int totalBackspaces = _lastWord.Length + (_lastBoundary != '\0' ? 1 : 0);
                for (int i = 0; i < totalBackspaces; i++)
                {
                    InputSimulator.SimulateKeyPress(0x08); // Backspace
                    Thread.Sleep(5);
                }
                Thread.Sleep(20);
                InputSimulator.SimulateText(corr + (_lastBoundary != '\0' ? _lastBoundary.ToString() : ""));
                _lastWord = corr;
            }
            finally { _injecting = false; }
            SetLang(lang, true);
        }

        private void Inject(string original, string corrected, string lang, char boundary)
        {
            _injecting = true;
            try
            {
                // Match macOS timing (80ms) for better reliability with OS layout changes
                Thread.Sleep(80);
                
                // Backspace the word + boundary if it was a space/tab/enter
                int backspaces = original.Length + (boundary != '\0' ? 1 : 0);
                for (int i = 0; i < backspaces; i++)
                {
                    InputSimulator.SimulateKeyPress(0x08); // Backspace
                    Thread.Sleep(2);
                }
                
                Thread.Sleep(10);
                // Type the corrected word + original boundary
                string textToInject = corrected;
                if (boundary != '\0') textToInject += boundary;
                
                InputSimulator.SimulateText(textToInject);
            }
            finally { _injecting = false; }
            SetLang(lang, false);
        }

        public void Dispose()
        {
            _hook?.Dispose();
            _trayIcon?.Dispose();
        }
    }

    public static class Translator
    {
        static Dictionary<string, Dictionary<char, char>> Layouts = new()
        {
            { "ru", new Dictionary<char, char> { {'q','й'},{'w','ц'},{'e','у'},{'r','к'},{'t','е'},{'y','н'},{'u','г'},{'i','ш'},{'o','щ'},{'p','з'},{'[','х'},{']','ъ'},{'a','ф'},{'s','ы'},{'d','в'},{'f','а'},{'g','п'},{'h','р'},{'j','о'},{'k','л'},{'l','д'},{';','ж'},{'\'','э'},{'z','я'},{'x','ч'},{'c','с'},{'v','м'},{'b','и'},{'n','т'},{'m','ь'},{',','б'},{'.','ю'},{'`','ё'} } },
            { "ua", new Dictionary<char, char> { {'q','й'},{'w','ц'},{'e','у'},{'r','к'},{'t','е'},{'y','н'},{'u','г'},{'i','ш'},{'o','щ'},{'p','з'},{'[','х'},{']','ї'},{'a','ф'},{'s','і'},{'d','в'},{'f','а'},{'g','п'},{'h','р'},{'j','о'},{'k','л'},{'l','д'},{';','ж'},{'\'','є'},{'z','я'},{'x','ч'},{'c','с'},{'v','м'},{'b','и'},{'n','т'},{'m','ь'},{',','б'},{'.','ю'},{'`','ґ'} } }
        };

        static Dictionary<string, Dictionary<char, char>> CyrToEn = new();
        
        static HashSet<string> EnBlock = new() {
            "i","a","the","an","my","me","we","us","he","she","it",
            "they","his","her","its","our","your","who","what","that",
            "is","am","are","was","were","be","been","do","does","did",
            "have","has","had","go","get","got","use","make","see","say",
            "know","think","come","want","look","work","works","need",
            "feel","try","run","in","on","at","to","of","or","if","as",
            "by","up","so","no","ok","and","but","for","not","all",
            "can","may","out","one","two","new","old","set","put","add",
            "yes","let","now","any","how","too","off","key","way","day",
            "end","top","still","just","also","when","then","click",
            "change","actually","doesn","hello","world","test","here",
            "there","about","after","before","some","with","from","this"
        };

        static HashSet<string> CyrHints = new() {
            "привет","как","это","что","для","всем","привіт","як","це",
            "що","усім","ми","вони","бути","є","її","вот","уже","меня",
            "было","очень","если","когда","только","через","после",
            "этого","тоже","даже","может","можно","надо","хочу",
            "будет","есть","нету","нету","вообще","сейчас","потом",
            "здесь","там","туда","сюда","почему","зачем","потому",
            "дела","делаю","сделать","пришел","пришла","сделал",
            "сделала","сказал","сказала","говорит","говорить"
        };

        static Translator()
        {
            foreach (var kvp in Layouts)
            {
                var rev = new Dictionary<char, char>();
                foreach (var inner in kvp.Value) rev[inner.Value] = inner.Key;
                CyrToEn[kvp.Key] = rev;
            }
        }

        static bool IsLatin(char c) => c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z';
        static bool IsCyr(char c) => c >= '\u0400' && c <= '\u04FF';

        static string Transform(string src, Dictionary<char, char> map)
        {
            var sb = new StringBuilder(src.Length);
            foreach (var c in src)
            {
                var lower = char.ToLower(c);
                if (map.TryGetValue(lower, out var mapped))
                    sb.Append(char.IsUpper(c) ? char.ToUpper(mapped) : mapped);
                else
                    sb.Append(c);
            }
            return sb.ToString();
        }

        public static (string, string) ChooseCorrection(string word, List<string> enabled, Dictionary<string, string> mappings, HashSet<string> exceptions)
        {
            var lower = word.ToLower();
            if (mappings.TryGetValue(lower, out var corr))
            {
                var targetLang = corr.Any(IsLatin) ? "en" : (corr.Contains("ї") || corr.Contains("є") || corr.Contains("і") || corr.Contains("ґ") ? "ua" : "ru");
                return (Transform(lower, lower.Zip(corr.ToLower(), (k, v) => new { k, v }).ToDictionary(x => x.k, x => x.v)), targetLang);
            }
            if (exceptions.Contains(lower) || word.Length < 3) return (null, null);

            if (word.Any(IsLatin) && !word.Any(IsCyr))
            {
                // First try direct reverse mapping (check if word uniquely maps to one layout's alphabet)
                foreach (var lang in enabled)
                {
                    if (lang == "en" || !Layouts.ContainsKey(lang)) continue;
                    
                    if (EnBlock.Contains(lower)) return (null, null);

                    var corrected = Transform(word, Layouts[lang]);
                    
                    var letters = corrected.Where(IsCyr).ToList();
                    if (letters.Count > 0)
                    {
                        // If it contains specific Ukrainian letters and we are checking UA, return immediately
                        if (lang == "ua" && letters.Any(c => "іїєґ".Contains(char.ToLower(c))))
                            return (corrected, lang);
                        // If it contains specific Russian letters and we are checking RU, return immediately
                        if (lang == "ru" && letters.Any(c => "ыэъё".Contains(char.ToLower(c))))
                            return (corrected, lang);
                            
                        var vowelsCount = letters.Count(c => "аеёиоуыэюяіїє".Contains(char.ToLower(c)));
                        var ratio = (double)vowelsCount / letters.Count;
                        if (ratio >= 0.2 && ratio <= 0.6) return (corrected, lang);
                    }
                }
            }
            else if (word.Any(IsCyr) && !word.Any(IsLatin) && enabled.Contains("en"))
            {
                if (CyrHints.Contains(lower)) return (null, null);

                foreach (var lang in enabled)
                {
                    if (lang == "en" || !CyrToEn.ContainsKey(lang)) continue;
                    var corrected = Transform(word, CyrToEn[lang]);
                    
                    // Only auto-correct to English if the result looks like English (vowel check)
                    // or if it's a long enough word to be a likely mistake.
                    // This prevents correcting valid Cyrillic words like "как", "дела" to nonsense.
                    var letters = corrected.Where(char.IsLetter).ToList();
                    if (letters.Count > 0)
                    {
                        var vowelsCount = letters.Count(c => "aeiouy".Contains(char.ToLower(c)));
                        var ratio = (double)vowelsCount / letters.Count;
                        
                        // English vowel ratio typically between 20-60%. 
                        // Removed the "length > 6" check as it caused false positives for valid Cyrillic words.
                        if (ratio >= 0.2 && ratio <= 0.6)
                            return (corrected, "en");
                    }
                }
            }
            return (null, null);
        }

        public static (string, string) ForceTranslate(string word, string langHint)
        {
            if (word.Any(IsLatin))
            {
                var target = langHint;
                return (Transform(word, Layouts[target]), target);
            }
            else
            {
                bool isUa = word.ToLower().Any(c => "іїєґ".Contains(c));
                var src = isUa ? "ua" : "ru";
                return (Transform(word, CyrToEn[src]), "en");
            }
        }
    }

    static class InputSimulator
    {
        [StructLayout(LayoutKind.Sequential)]
        struct INPUT
        {
            public uint type;
            public InputUnion U;
        }
        [StructLayout(LayoutKind.Explicit)]
        struct InputUnion
        {
            [FieldOffset(0)] public KEYBDINPUT ki;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [DllImport("user32.dll")]
        static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        public static void SimulateKeyPress(ushort vk)
        {
            var inputs = new INPUT[2];
            inputs[0].type = 1; // INPUT_KEYBOARD
            inputs[0].U.ki.wVk = vk;
            inputs[1].type = 1;
            inputs[1].U.ki.wVk = vk;
            inputs[1].U.ki.dwFlags = 0x0002; // KEYEVENTF_KEYUP
            SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
        }

        public static void SimulateText(string text)
        {
            var inputs = new INPUT[text.Length * 2];
            for (int i = 0; i < text.Length; i++)
            {
                inputs[i * 2].type = 1;
                inputs[i * 2].U.ki.wVk = 0;
                inputs[i * 2].U.ki.wScan = text[i];
                inputs[i * 2].U.ki.dwFlags = 0x0004; // KEYEVENTF_UNICODE

                inputs[i * 2 + 1].type = 1;
                inputs[i * 2 + 1].U.ki.wVk = 0;
                inputs[i * 2 + 1].U.ki.wScan = text[i];
                inputs[i * 2 + 1].U.ki.dwFlags = 0x0004 | 0x0002; // UNICODE | KEYUP
            }
            SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
        }
    }

    class GlobalKeyboardHook : IDisposable
    {
        public event EventHandler<GlobalKeyboardHookEventArgs> KeyDown;
        private IntPtr _hookID = IntPtr.Zero;
        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
        private LowLevelKeyboardProc _proc;

        public struct KeyboardHookStruct
        {
            public uint VirtualCode;
            public uint ScanCode;
            public uint Flags;
            public uint Time;
            public IntPtr ExtraInfo;
        }

        public GlobalKeyboardHook()
        {
            _proc = HookCallback;
            using (var curProcess = Process.GetCurrentProcess())
            using (var curModule = curProcess.MainModule)
            {
                _hookID = SetWindowsHookEx(13, _proc, GetModuleHandle(curModule.ModuleName), 0);
            }
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && (wParam == (IntPtr)0x0100 || wParam == (IntPtr)0x0104)) // WM_KEYDOWN || WM_SYSKEYDOWN
            {
                var kb = (KeyboardHookStruct)Marshal.PtrToStructure(lParam, typeof(KeyboardHookStruct));
                var args = new GlobalKeyboardHookEventArgs { KeyboardData = kb };
                KeyDown?.Invoke(this, args);
                if (args.Handled) return (IntPtr)1;
            }
            return CallNextHookEx(_hookID, nCode, wParam, lParam);
        }

        public void Dispose()
        {
            if (_hookID != IntPtr.Zero)
            {
                UnhookWindowsHookEx(_hookID);
                _hookID = IntPtr.Zero;
            }
        }

        [DllImport("user32.dll")]
        static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
        [DllImport("user32.dll")]
        static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll")]
        static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll")]
        static extern IntPtr GetModuleHandle(string lpModuleName);
    }

    class GlobalKeyboardHookEventArgs : EventArgs
    {
        public GlobalKeyboardHook.KeyboardHookStruct KeyboardData { get; set; }
        public bool Handled { get; set; }
    }
}
