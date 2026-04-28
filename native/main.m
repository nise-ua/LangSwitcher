// LangSwitcher — native macOS menu bar app
// Compile: clang -framework Cocoa -framework Carbon main.m -o LangSwitcher
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

// Forward declaration
static CGEventRef tapCallback(CGEventTapProxy, CGEventType, CGEventRef, void*);

// ── File logging ──────────────────────────────────────────────────────────────
static FILE *gLog = NULL;
static void LSLog(const char *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void LSLog(const char *fmt, ...) {
    if (!gLog) return;
    time_t t = time(NULL);
    char ts[32]; strftime(ts, sizeof(ts), "%H:%M:%S", localtime(&t));
    fprintf(gLog, "[%s] ", ts);
    va_list ap; va_start(ap, fmt); vfprintf(gLog, fmt, ap); va_end(ap);
    fprintf(gLog, "\n"); fflush(gLog);
}
static void setupLog(void) {
    NSString *logPath = [@"~/Library/Logs/LangSwitcher.log" stringByExpandingTildeInPath];
    gLog = fopen(logPath.UTF8String, "a");
    LSLog("=== LangSwitcher started ===");
}


// ── Keycodes ─────────────────────────────────────────────────────────────────
#define kMyDelete  51
#define kMySpace   49
#define kMyReturn  36
#define kMyTab     48
#define kMyEscape  53
#define kMyLeft   123
#define kMyRight  124
#define kMyUp     126
#define kMyDown   125

// ── Globals ──────────────────────────────────────────────────────────────────
static CFMachPortRef      gTap;
static volatile BOOL      gInjecting = NO;

// ── Layout maps ───────────────────────────────────────────────────────────────
static NSDictionary<NSString*,NSString*> *gRU, *gUA, *gRU_inv, *gUA_inv;

static void buildLayouts(void) {
    gRU = @{
        @"q":@"й",@"w":@"ц",@"e":@"у",@"r":@"к",@"t":@"е",@"y":@"н",@"u":@"г",
        @"i":@"ш",@"o":@"щ",@"p":@"з",@"[":@"х",@"]":@"ъ",
        @"a":@"ф",@"s":@"ы",@"d":@"в",@"f":@"а",@"g":@"п",@"h":@"р",@"j":@"о",
        @"k":@"л",@"l":@"д",@";":@"ж",@"'":@"э",
        @"z":@"я",@"x":@"ч",@"c":@"с",@"v":@"м",@"b":@"и",@"n":@"т",@"m":@"ь",
        @",":@"б",@".":@"ю",@"`":@"ё"
    };
    gUA = @{
        @"q":@"й",@"w":@"ц",@"e":@"у",@"r":@"к",@"t":@"е",@"y":@"н",@"u":@"г",
        @"i":@"ш",@"o":@"щ",@"p":@"з",@"[":@"х",@"]":@"ї",
        @"a":@"ф",@"s":@"і",@"d":@"в",@"f":@"а",@"g":@"п",@"h":@"р",@"j":@"о",
        @"k":@"л",@"l":@"д",@";":@"ж",@"'":@"є",
        @"z":@"я",@"x":@"ч",@"c":@"с",@"v":@"м",@"b":@"и",@"n":@"т",@"m":@"ь",
        @",":@"б",@".":@"ю",@"`":@"ґ"
    };
    NSMutableDictionary *ri = [NSMutableDictionary new], *ui = [NSMutableDictionary new];
    [gRU enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s){ ri[v]=k; }];
    [gUA enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s){ ui[v]=k; }];
    gRU_inv = ri.copy; gUA_inv = ui.copy;
}

// ── Hint words & blocklist ────────────────────────────────────────────────────
static NSSet<NSString*> *gHintRU, *gHintUA, *gHintEN, *gEnBlock;
static void buildWordSets(void) {
    gHintRU = [NSSet setWithObjects:@"привет",@"как",@"это",@"что",@"для",@"всем",
               @"я",@"ты",@"мы",@"они",nil];
    gHintUA = [NSSet setWithObjects:@"привіт",@"як",@"це",@"що",@"для",@"усім",
               @"я",@"ти",@"ми",@"вони",@"є",@"її",nil];
    gHintEN = [NSSet setWithObjects:@"hello",@"this",@"with",@"from",@"report",
               @"switch",@"plugin",@"language",nil];
    gEnBlock = [NSSet setWithObjects:
        @"i",@"a",@"the",@"an",@"my",@"me",@"we",@"us",@"he",@"she",@"it",
        @"they",@"his",@"her",@"its",@"our",@"your",@"who",@"what",@"that",
        @"is",@"am",@"are",@"was",@"were",@"be",@"been",@"do",@"does",@"did",
        @"have",@"has",@"had",@"go",@"get",@"got",@"use",@"make",@"see",@"say",
        @"know",@"think",@"come",@"want",@"look",@"work",@"works",@"need",
        @"feel",@"try",@"run",@"in",@"on",@"at",@"to",@"of",@"or",@"if",@"as",
        @"by",@"up",@"so",@"no",@"ok",@"and",@"but",@"for",@"not",@"all",
        @"can",@"may",@"out",@"one",@"two",@"new",@"old",@"set",@"put",@"add",
        @"yes",@"let",@"now",@"any",@"how",@"too",@"off",@"key",@"way",@"day",
        @"end",@"top",@"still",@"just",@"also",@"when",@"then",@"click",
        @"change",@"actually",@"doesn",@"hello",@"world",@"test",@"here",
        @"there",@"about",@"after",@"before",@"some",@"with",@"from",@"this",
        @"that",@"they",@"have",@"will",@"been",@"more",@"than",@"your",
        nil];
}

static NSDictionary *gCustomMappings = nil;
static NSSet *gBlockedWords = nil;

static void loadCustomDictionaries(void) {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [appSupport stringByAppendingPathComponent:@"ua.nise.langswitcher"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *excPath = [dir stringByAppendingPathComponent:@"exceptions.txt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:excPath]) {
        NSString *defaultExc = @"# Add words here to NEVER translate them (e.g., acronyms, names)\nmacbook\nibm\n\n# Add custom force-translations with an equals sign:\nghbdtn=привет\n";
        [defaultExc writeToFile:excPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    NSString *content = [NSString stringWithContentsOfFile:excPath encoding:NSUTF8StringEncoding error:nil];
    NSMutableDictionary *mappings = [NSMutableDictionary new];
    NSMutableSet *blocked = [NSMutableSet new];
    
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (t.length == 0 || [t hasPrefix:@"#"]) continue;
        
        NSArray *parts = [t componentsSeparatedByString:@"="];
        if (parts.count == 2) {
            mappings[[parts[0] lowercaseString]] = [parts[1] lowercaseString];
        } else {
            [blocked addObject:t.lowercaseString];
        }
    }
    gCustomMappings = mappings.copy;
    gBlockedWords = blocked.copy;
}

static BOOL isWordValidInLang(NSString *word, NSString *lang) {
    NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
    NSString *scLang = [lang isEqual:@"ua"] ? @"uk" : lang;
    NSRange r = [sc checkSpellingOfString:word startingAt:0 language:scLang wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
    return r.location == NSNotFound;
}

// ── String transform ──────────────────────────────────────────────────────────
static NSString *transformWord(NSString *word, NSDictionary<NSString*,NSString*> *map) {
    NSMutableString *out = [NSMutableString stringWithCapacity:word.length];
    for (NSUInteger i=0;i<word.length;i++) {
        unichar c=[word characterAtIndex:i];
        NSString *k=[NSString stringWithCharacters:&c length:1].lowercaseString;
        NSString *mapped=map[k];
        if (!mapped) { [out appendString:k]; continue; }
        BOOL upper = (c>='A'&&c<='Z') || 
                     (c>=0x0400 && c<=0x04FF && c == [k.uppercaseString characterAtIndex:0]);
        [out appendString: upper ? mapped.uppercaseString : mapped];
    }
    return out.copy;
}

// ── Correction ────────────────────────────────────────────────────────────────
typedef struct { NSString *corrected; NSString *lang; } Correction;

static Correction chooseCorrection(NSString *word, NSArray<NSString*> *enabled) {
    if (word.length < 2) return (Correction){nil,nil};
    NSString *lo = word.lowercaseString;
    
    if ([gBlockedWords containsObject:lo]) return (Correction){nil,nil};
    if (gCustomMappings[lo]) {
        NSString *mapped = gCustomMappings[lo];
        // Guess language of the mapped word
        NSString *lang = @"en";
        if ([mapped rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0x0400, 0x04FF)]].location != NSNotFound) {
            lang = [enabled containsObject:@"ru"] ? @"ru" : @"ua";
        }
        return (Correction){mapped, lang};
    }

    BOOL allLat=YES, hasCyr=NO;
    for(NSUInteger i=0;i<word.length;i++){
        unichar c=[word characterAtIndex:i];
        if(c>=0x0400 && c<=0x04FF){hasCyr=YES;allLat=NO;break;}
        if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z'))&&!isalnum(c))continue;
        if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')))allLat=NO;
    }

    if (allLat && !hasCyr) {
        // If it's already a valid English word, do not touch it
        if (isWordValidInLang(word, @"en")) return (Correction){nil,nil};
        if ([gEnBlock containsObject:word.lowercaseString]) return (Correction){nil,nil};
        
        for (NSString *lang in enabled) {
            if ([lang isEqual:@"en"]) continue;
            NSDictionary *map = [lang isEqual:@"ru"] ? gRU : gUA;
            if (!map) continue;
            NSString *cand = transformWord(word, map);
            if (isWordValidInLang(cand, lang)) return (Correction){cand, lang};
        }
    }

    BOOL allCyr=YES; BOOL hasLat=NO;
    for(NSUInteger i=0;i<word.length;i++){
        unichar c=[word characterAtIndex:i];
        if(((c>='a'&&c<='z')||(c>='A'&&c<='Z'))){hasLat=YES;allCyr=NO;break;}
        if(!(c>=0x0400 && c<=0x04FF)&&isalnum(c))allCyr=NO;
    }
    
    if (allCyr && !hasLat && [enabled containsObject:@"en"]) {
        // PREFER ENGLISH translation first to bypass learned typos in local dictionary
        for (NSString *lang in enabled) {
            if ([lang isEqual:@"en"]) continue;
            NSDictionary *map = [lang isEqual:@"ru"] ? gRU_inv : gUA_inv;
            if (!map) continue;
            NSString *cand = transformWord(word, map);
            if (isWordValidInLang(cand, @"en")) {
                // Protect short common Cyrillic words like "мы" (translates to "vs"), "он" (translates to "oh")
                if (word.length <= 2 && isWordValidInLang(word, lang)) {
                    continue;
                }
                return (Correction){cand, @"en"};
            }
        }
        
        // If it doesn't translate to valid English, check if it's valid Cyrillic
        BOOL validCyr = NO;
        for (NSString *lang in enabled) {
            if ([lang isEqual:@"en"]) continue;
            if (isWordValidInLang(word, lang)) validCyr = YES;
        }
        if (validCyr) return (Correction){nil,nil};
    }
    return (Correction){nil,nil};
}

// ── App Delegate ──────────────────────────────────────────────────────────────
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSStatusItem *statusItem;
@property (strong) NSMutableString *wordBuf;
@property BOOL cmdHeld;
@property (strong) NSArray<NSString*> *enabledLangs;
@property (strong) NSString *activeLang;
@property (strong) NSString *lastWordTyped;
@property (strong) NSString *lastBoundaryTyped;
@property (strong) NSString *hotkey;
@property (strong) NSWindow *excWindow;
@property (strong) NSTextView *excTextView;
- (void)handleDoubleCommand;
@end

@implementation AppDelegate

- (instancetype)init {
    self = [super init];
    _wordBuf = [NSMutableString new];
    _cmdHeld = NO;
    [self loadSettings];
    return self;
}

- (void)inputSourceChanged:(NSNotification *)note {
    TISInputSourceRef src = TISCopyCurrentKeyboardInputSource();
    if (!src) return;
    CFStringRef nameRef = TISGetInputSourceProperty(src, kTISPropertyLocalizedName);
    if (!nameRef) { CFRelease(src); return; }
    NSString *name = (__bridge NSString*)nameRef;
    
    NSString *detectedLang = nil;
    if ([name localizedCaseInsensitiveContainsString:@"Russian"]) detectedLang = @"ru";
    else if ([name localizedCaseInsensitiveContainsString:@"Ukrainian"]) detectedLang = @"ua";
    else if ([name localizedCaseInsensitiveContainsString:@"U.S."] ||
             [name localizedCaseInsensitiveContainsString:@"ABC"] ||
             [name localizedCaseInsensitiveContainsString:@"English"] ||
             [name localizedCaseInsensitiveContainsString:@"American"]) detectedLang = @"en";

    if (detectedLang && ![detectedLang isEqual:_activeLang] && [_enabledLangs containsObject:detectedLang]) {
        _activeLang = detectedLang;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self saveSettings]; [self updateIcon]; [self rebuildMenu];
        });
    }
    CFRelease(src);
}

// ── Settings ──────────────────────────────────────────────────────────────────
- (void)loadSettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSArray *en = [d arrayForKey:@"enabledLangs"];
    NSArray *valid = @[@"en",@"ru",@"ua"];
    if (en.count >= 2) {
        NSMutableArray *f = [NSMutableArray new];
        for (NSString *l in en) if ([valid containsObject:l]) [f addObject:l];
        _enabledLangs = f.count>=2 ? f.copy : valid;
    } else {
        _enabledLangs = valid;
    }
    NSString *al = [d stringForKey:@"activeLang"];
    _activeLang = ([_enabledLangs containsObject:al]) ? al : _enabledLangs[0];
    _hotkey = [d stringForKey:@"hotkey"] ?: @"cmd";
}
- (void)saveSettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:_enabledLangs forKey:@"enabledLangs"];
    [d setObject:_activeLang   forKey:@"activeLang"];
    [d setObject:_hotkey       forKey:@"hotkey"];
}

// ── Menu bar ──────────────────────────────────────────────────────────────────
- (void)applicationDidFinishLaunching:(NSNotification *)n {
    [self loadSettings];
    loadCustomDictionaries();
    [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated|NSActivityLatencyCritical reason:@"LangSwitcher key monitor"];
    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    [self updateIcon];
    [self rebuildMenu];
    
    // Sync to current OS layout at startup
    [self inputSourceChanged:nil];
    
    // Listen to OS keyboard layout changes
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(inputSourceChanged:) name:(NSString*)kTISNotifySelectedKeyboardInputSourceChanged object:nil];
    
    [self setupEventTap];
    
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        LSLog("NSEvent monitor: kc=%d", event.keyCode);
    }];
}

- (NSColor *)colorForLang:(NSString*)lang {
    if ([lang isEqual:@"ru"]) return [NSColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1]; // Red
    if ([lang isEqual:@"ua"]) return [NSColor colorWithRed:0.98 green:0.80 blue:0.00 alpha:1]; // Yellow
    return [NSColor colorWithRed:0.00 green:0.47 blue:1.00 alpha:1]; // Blue for EN
}

- (void)updateIcon {
    NSString *label = _activeLang.uppercaseString;
    NSColor *color  = [self colorForLang:_activeLang];
    NSSize sz = NSMakeSize(28, 18);
    NSImage *img = [NSImage imageWithSize:sz flipped:NO drawingHandler:^BOOL(NSRect r){
        [color setFill];
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:4 yRadius:4] fill];
        NSDictionary *attrs = @{
            NSFontAttributeName:[NSFont boldSystemFontOfSize:10],
            NSForegroundColorAttributeName:NSColor.whiteColor
        };
        NSSize ts=[label sizeWithAttributes:attrs];
        NSPoint pt=NSMakePoint((r.size.width-ts.width)/2,(r.size.height-ts.height)/2);
        [label drawAtPoint:pt withAttributes:attrs];
        return YES;
    }];
    _statusItem.button.image = img;
    _statusItem.button.toolTip = [NSString stringWithFormat:@"LangSwitcher — %@", label];
}

- (void)rebuildMenu {
    NSMenu *m = [NSMenu new];
    // Header
    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:@"LangSwitcher" action:nil keyEquivalent:@""];
    header.enabled = NO; [m addItem:header]; [m addItem:NSMenuItem.separatorItem];
    // Switch layout
    NSMenuItem *sw = [[NSMenuItem alloc] initWithTitle:@"Switch layout" action:nil keyEquivalent:@""];
    NSMenu *swMenu = [NSMenu new];
    for (NSString *lang in @[@"en",@"ru",@"ua"]) {
        NSString *prefix = [_activeLang isEqual:lang] ? @"● " : @"   ";
        NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:[prefix stringByAppendingString:lang.uppercaseString]
                                                    action:@selector(switchLang:) keyEquivalent:@""];
        it.representedObject = lang; it.target = self;
        [swMenu addItem:it];
    }
    sw.submenu = swMenu; [m addItem:sw];
    
    // Quick Correct Hotkey
    NSMenuItem *hkMenu = [[NSMenuItem alloc] initWithTitle:@"Quick Correct Hotkey" action:nil keyEquivalent:@""];
    NSMenu *hkSub = [NSMenu new];
    for (NSString *hk in @[@"cmd", @"opt", @"ctrl"]) {
        NSString *label = @"";
        if ([hk isEqual:@"cmd"]) label = @"Double Command (⌘)";
        if ([hk isEqual:@"opt"]) label = @"Double Option (⌥)";
        if ([hk isEqual:@"ctrl"]) label = @"Double Control (⌃)";
        
        NSString *title = [NSString stringWithFormat:@"%@ %@", [_hotkey isEqual:hk]?@"✓":@"   ", label];
        NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectHotkey:) keyEquivalent:@""];
        it.representedObject = hk; it.target = self;
        [hkSub addItem:it];
    }
    hkMenu.submenu = hkSub; [m addItem:hkMenu];
    
    [m addItem:NSMenuItem.separatorItem];
    
    // Manage Exceptions
    [m addItemWithTitle:@"Manage Exceptions..." action:@selector(openExceptionsEditor:) keyEquivalent:@"e"].target = self;
    
    [m addItem:NSMenuItem.separatorItem];
    // Enable/disable
    NSMenuItem *tog = [[NSMenuItem alloc] initWithTitle:@"Auto-correct langs" action:nil keyEquivalent:@""];
    NSMenu *togMenu = [NSMenu new];
    for (NSString *lang in @[@"en",@"ru",@"ua"]) {
        BOOL on = [_enabledLangs containsObject:lang];
        NSString *title = [NSString stringWithFormat:@"%@ %@", on?@"✓":@"   ", lang.uppercaseString];
        NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:title action:@selector(toggleLang:) keyEquivalent:@""];
        it.representedObject = lang; it.target = self; [togMenu addItem:it];
    }
    tog.submenu = togMenu; [m addItem:tog];
    [m addItem:NSMenuItem.separatorItem];
    [m addItemWithTitle:@"Quit" action:@selector(quitApp:) keyEquivalent:@"q"].target = self;
    _statusItem.menu = m;
}

- (void)switchLang:(NSMenuItem*)item {
    NSString *lang = item.representedObject;
    if (![_enabledLangs containsObject:lang]) return;
    _activeLang = lang;
    [self saveSettings]; [self updateIcon]; [self rebuildMenu];
    [self switchOSInputSource:lang];
}

- (void)toggleLang:(NSMenuItem*)item {
    NSString *lang = item.representedObject;
    NSMutableArray *en = _enabledLangs.mutableCopy;
    if ([en containsObject:lang]) {
        if (en.count <= 2) return;
        [en removeObject:lang];
        if ([_activeLang isEqual:lang]) _activeLang = en[0];
    } else {
        [en addObject:lang];
    }
    _enabledLangs = en.copy;
    [self saveSettings]; [self rebuildMenu];
}

- (void)selectHotkey:(NSMenuItem*)item {
    _hotkey = item.representedObject;
    [self saveSettings]; [self rebuildMenu];
}

- (void)openExceptionsEditor:(id)sender {
    if (_excWindow) {
        [_excWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }
    NSRect frame = NSMakeRect(0, 0, 440, 500);
    _excWindow = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    _excWindow.title = @"LangSwitcher Exceptions";
    [_excWindow center];
    _excWindow.releasedWhenClosed = NO;
    
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 60, 400, 420)];
    sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    sv.hasVerticalScroller = YES;
    
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,400,420)];
    tv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    tv.font = [NSFont userFixedPitchFontOfSize:13];
    
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *excPath = [appSupport stringByAppendingPathComponent:@"ua.nise.langswitcher/exceptions.txt"];
    tv.string = [NSString stringWithContentsOfFile:excPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
    
    sv.documentView = tv;
    _excTextView = tv;
    
    NSButton *saveBtn = [[NSButton alloc] initWithFrame:NSMakeRect(320, 15, 100, 30)];
    saveBtn.title = @"Save";
    saveBtn.bezelStyle = NSBezelStyleRounded;
    saveBtn.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    saveBtn.target = self;
    saveBtn.action = @selector(saveExceptions:);
    
    NSView *cv = _excWindow.contentView;
    [cv addSubview:sv];
    [cv addSubview:saveBtn];
    
    [_excWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)saveExceptions:(id)sender {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *excPath = [appSupport stringByAppendingPathComponent:@"ua.nise.langswitcher/exceptions.txt"];
    [_excTextView.string writeToFile:excPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    loadCustomDictionaries();
    [_excWindow close];
    _excWindow = nil;
}

- (void)quitApp:(id)s { [NSApp terminate:nil]; }

// ── OS input source switch ────────────────────────────────────────────────────
- (void)switchOSInputSource:(NSString*)lang {
    NSDictionary *keywords = @{
        @"en": @[@"U.S.", @"ABC", @"English", @"American"],
        @"ru": @[@"Russian"],
        @"ua": @[@"Ukrainian"]
    };
    NSArray *kws = keywords[lang];
    CFArrayRef list = TISCreateInputSourceList(NULL, false);
    for (CFIndex i=0; i<CFArrayGetCount(list); i++) {
        TISInputSourceRef src = (TISInputSourceRef)CFArrayGetValueAtIndex(list, i);
        CFStringRef nameRef = TISGetInputSourceProperty(src, kTISPropertyLocalizedName);
        if (!nameRef) continue;
        NSString *name = (__bridge NSString*)nameRef;
        for (NSString *kw in kws) {
            if ([name localizedCaseInsensitiveContainsString:kw]) {
                TISSelectInputSource(src); CFRelease(list); return;
            }
        }
    }
    CFRelease(list);
}

// ── Event tap ─────────────────────────────────────────────────────────────────
- (void)setupEventTap {
    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventFlagsChanged);
    gTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                            kCGEventTapOptionDefault, mask, tapCallback, (__bridge void*)self);
    LSLog("CGEventTapCreate result: %s", gTap ? "SUCCESS" : "FAILED");
    if (!gTap) {
        NSLog(@"Failed to create event tap — grant Accessibility in System Settings");
        NSAlert *a = [NSAlert new];
        a.messageText = @"Accessibility Permission Required";
        a.informativeText = @"LangSwitcher needs Accessibility access.\n\nSystem Settings → Privacy & Security → Accessibility → add LangSwitcher";
        [a addButtonWithTitle:@"Open Settings"];
        [a addButtonWithTitle:@"Quit"];
        if ([a runModal] == NSAlertFirstButtonReturn)
            [[NSWorkspace sharedWorkspace] openURL:
             [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
        [NSApp terminate:nil]; return;
    }
    CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(NULL, gTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopCommonModes);
    CGEventTapEnable(gTap, YES);
    CFRelease(src);
}

// ── Key event handling ────────────────────────────────────────────────────────
- (void)handleKey:(CGEventRef)event {
    CGEventFlags flags = CGEventGetFlags(event);
    CGKeyCode keyCode  = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    LSLog("keyDown kc=%d flags=0x%llx", (int)keyCode, (unsigned long long)flags);

    // Cmd/Ctrl held → reset buffer
    if (flags & (kCGEventFlagMaskCommand|kCGEventFlagMaskControl)) {
        [_wordBuf setString:@""]; return;
    }
    // Backspace
    if (keyCode == kMyDelete) {
        if (_wordBuf.length) [_wordBuf deleteCharactersInRange:NSMakeRange(_wordBuf.length-1,1)];
        return;
    }
    // Nav keys → reset
    if (keyCode==kMyLeft||keyCode==kMyRight||keyCode==kMyUp||keyCode==kMyDown||keyCode==kMyEscape) {
        [_wordBuf setString:@""]; return;
    }

    // Get the typed character
    UniChar buf[8]; UniCharCount cnt=0;
    CGEventKeyboardGetUnicodeString(event, 8, &cnt, buf);
    if (cnt == 0) return;
    NSString *ch = [NSString stringWithCharacters:buf length:cnt];

    // Word boundary?
    NSMutableCharacterSet *boundary = [NSMutableCharacterSet new];
    [boundary addCharactersInString:@" \t\n.,!?;:(){}\"'\\-"];
    [boundary addCharactersInRange:NSMakeRange('[', 1)];
    [boundary addCharactersInRange:NSMakeRange(']', 1)];
    if (keyCode==kMySpace||keyCode==kMyReturn||keyCode==kMyTab||
        [ch rangeOfCharacterFromSet:boundary].location != NSNotFound) {
        NSString *word = _wordBuf.copy;
        [_wordBuf setString:@""];
        
        if (word.length > 0) {
            _lastWordTyped = word;
            _lastBoundaryTyped = ch;
        }

        if (word.length >= 3) {
            NSArray *enabled = _enabledLangs;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE,0), ^{
                [self tryCorrectWord:word boundary:ch enabled:enabled];
            });
        }
        return;
    }
    [_wordBuf appendString:ch];
}

// ── Correction ────────────────────────────────────────────────────────────────
- (void)tryCorrectWord:(NSString*)word boundary:(NSString*)boundary enabled:(NSArray*)enabled {
    LSLog("tryCorrect: '%s'", word.UTF8String);
    Correction c = chooseCorrection(word, enabled);
    if (!c.corrected || [c.corrected isEqual:word]) { LSLog("no correction"); return; }
    LSLog("correcting to: '%s' (%s)", c.corrected.UTF8String, c.lang.UTF8String);
    // Inject must happen on main thread
    NSString *corrected = c.corrected; NSString *lang = c.lang;
    NSUInteger nBack = word.length + 1; // +1 to delete the boundary character that was just typed
    dispatch_async(dispatch_get_main_queue(), ^{
        [self inject:nBack corrected:corrected boundary:boundary lang:lang];
    });
}

- (void)inject:(NSUInteger)nBack corrected:(NSString*)corrected boundary:(NSString*)boundary lang:(NSString*)lang {
    // Must be called on main thread
    gInjecting = YES;
    // Use dispatch_after so the boundary key is fully processed first
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80*NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        [self doInject:nBack corrected:corrected boundary:boundary lang:lang];
    });
}
- (void)doInject:(NSUInteger)nBack corrected:(NSString*)corrected boundary:(NSString*)boundary lang:(NSString*)lang {
    usleep(10000);

    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

    // Backspaces
    for (NSUInteger i=0;i<nBack;i++) {
        CGEventRef dn=CGEventCreateKeyboardEvent(src,kMyDelete,true);
        CGEventRef up=CGEventCreateKeyboardEvent(src,kMyDelete,false);
        CGEventSetIntegerValueField(dn, kCGEventSourceUserData, 1337);
        CGEventSetIntegerValueField(up, kCGEventSourceUserData, 1337);
        CGEventPost(kCGSessionEventTap,dn); usleep(5000);
        CGEventPost(kCGSessionEventTap,up); usleep(3000);
        CFRelease(dn); CFRelease(up);
    }
    usleep(20000);

    // Type corrected string character by character
    NSString *finalStr = [corrected stringByAppendingString:boundary];
    for (NSUInteger i=0;i<finalStr.length;i++) {
        unichar uch=[finalStr characterAtIndex:i];
        CGEventRef dn=CGEventCreateKeyboardEvent(src,0,true);
        CGEventRef up=CGEventCreateKeyboardEvent(src,0,false);
        CGEventSetIntegerValueField(dn, kCGEventSourceUserData, 1337);
        CGEventSetIntegerValueField(up, kCGEventSourceUserData, 1337);
        CGEventKeyboardSetUnicodeString(dn,1,&uch);
        CGEventKeyboardSetUnicodeString(up,1,&uch);
        CGEventPost(kCGSessionEventTap,dn); usleep(5000);
        CGEventPost(kCGSessionEventTap,up); usleep(3000);
        CFRelease(dn); CFRelease(up);
    }
    CFRelease(src);
    gInjecting = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_enabledLangs containsObject:lang]) {
            self->_activeLang = lang;
            [self saveSettings]; [self updateIcon]; [self rebuildMenu];
            [self switchOSInputSource:lang];
        }
    });
}

- (void)handleDoubleCommand {
    NSString *targetWord = _wordBuf.length > 0 ? [_wordBuf copy] : _lastWordTyped;
    if (!targetWord || targetWord.length == 0) return;
    
    BOOL allLat=YES, hasCyr=NO, allCyr=YES, hasLat=NO;
    for(NSUInteger i=0;i<targetWord.length;i++){
        unichar c=[targetWord characterAtIndex:i];
        if (((c>='a'&&c<='z')||(c>='A'&&c<='Z'))) { allCyr=NO; hasLat=YES; }
        else if (c>=0x0400 && c<=0x04FF) { allLat=NO; hasCyr=YES; }
        else { allLat=NO; allCyr=NO; }
    }
    
    NSString *mapped = nil;
    NSString *lang = nil;
    
    if (allLat && !hasCyr) {
        NSString *destLang = [_activeLang isEqual:@"ru"] ? @"ru" : @"ua";
        NSDictionary *map = [destLang isEqual:@"ru"] ? gRU : gUA;
        mapped = transformWord(targetWord, map);
        lang = destLang;
    } else if (allCyr && !hasLat) {
        NSDictionary *map = gRU_inv;
        if ([targetWord containsString:@"і"] || [targetWord containsString:@"ї"] || [targetWord containsString:@"є"]) {
            map = gUA_inv;
        }
        mapped = transformWord(targetWord, map);
        lang = @"en";
    }
    
    if (!mapped) return;
    
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *excPath = [appSupport stringByAppendingPathComponent:@"ua.nise.langswitcher/exceptions.txt"];
    NSString *line = [NSString stringWithFormat:@"\n%@=%@\n", targetWord.lowercaseString, mapped.lowercaseString];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:excPath];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
    loadCustomDictionaries();
    
    NSString *boundary = @"";
    NSUInteger nBack = 0;
    if (_wordBuf.length > 0) {
        nBack = _wordBuf.length;
        [_wordBuf setString:@""];
        _lastWordTyped = mapped;
        _lastBoundaryTyped = @"";
    } else {
        nBack = _lastWordTyped.length + _lastBoundaryTyped.length;
        boundary = _lastBoundaryTyped ?: @"";
        _lastWordTyped = mapped;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self inject:nBack corrected:mapped boundary:boundary lang:lang];
    });
}

@end // AppDelegate

// ── CGEventTap C callback ─────────────────────────────────────────────────────
static NSTimeInterval gLastCmdTime = 0;
static int gCmdPressCount = 0;
static BOOL gCancelCmd = NO;

static CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type,
                               CGEventRef event, void *userInfo) {
    LSLog("tapCallback: type=%d", (int)type);
    if (type == kCGEventMouseMoved) return event;
    if (type==kCGEventTapDisabledByTimeout||type==kCGEventTapDisabledByUserInput) {
        LSLog("event tap disabled, re-enabling");
        CGEventTapEnable(gTap, YES); return event;
    }
    AppDelegate *app = (__bridge AppDelegate*)userInfo;
    if (CGEventGetIntegerValueField(event, kCGEventSourceUserData) == 1337) {
        LSLog("ignoring our own injected event");
        return event;
    }

    if (type == kCGEventFlagsChanged) {
        int64_t kc = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        BOOL isTriggerKey = NO;
        if ([app.hotkey isEqual:@"cmd"] && (kc == 55 || kc == 54)) isTriggerKey = YES;
        if ([app.hotkey isEqual:@"opt"] && (kc == 58 || kc == 61)) isTriggerKey = YES;
        if ([app.hotkey isEqual:@"ctrl"] && (kc == 59 || kc == 62)) isTriggerKey = YES;
        
        if (isTriggerKey) {
            CGEventFlags flags = CGEventGetFlags(event);
            BOOL isDown = NO;
            if ([app.hotkey isEqual:@"cmd"]) isDown = (flags & kCGEventFlagMaskCommand) != 0;
            if ([app.hotkey isEqual:@"opt"]) isDown = (flags & kCGEventFlagMaskAlternate) != 0;
            if ([app.hotkey isEqual:@"ctrl"]) isDown = (flags & kCGEventFlagMaskControl) != 0;
            
            if (isDown) {
                NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
                if (gCancelCmd) {
                    gCmdPressCount = 1;
                    gCancelCmd = NO;
                } else {
                    if (now - gLastCmdTime < 0.4) {
                        gCmdPressCount++;
                    } else {
                        gCmdPressCount = 1;
                    }
                }
                gLastCmdTime = now;
            } else {
                if (gCmdPressCount == 2 && !gCancelCmd) {
                    gCmdPressCount = 0;
                    [app handleDoubleCommand];
                }
            }
        } else {
            gCancelCmd = YES;
        }
        return event;
    } else if (type == kCGEventKeyDown) {
        gCancelCmd = YES;
        [app handleKey:event];
    }
    return event;
}

// ── main ──────────────────────────────────────────────────────────────────────
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        setupLog();
        buildLayouts();
        buildWordSets();
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
