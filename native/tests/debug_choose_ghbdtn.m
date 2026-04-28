#import <Cocoa/Cocoa.h>

static NSDictionary<NSString*,NSString*> *gRU, *gUA;

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
}

static BOOL isWordValidInLang(NSString *word, NSString *lang) {
    NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
    NSString *scLang = [lang isEqual:@"ua"] ? @"uk" : lang;
    NSRange r = [sc checkSpellingOfString:word startingAt:0 language:scLang wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
    BOOL valid = (r.location == NSNotFound);
    printf("isWordValidInLang(%s, %s) -> %d\n", word.UTF8String, lang.UTF8String, valid);
    return valid;
}

static NSString *transformWord(NSString *word, NSDictionary<NSString*,NSString*> *map) {
    NSMutableString *out = [NSMutableString stringWithCapacity:word.length];
    for (NSUInteger i=0;i<word.length;i++) {
        unichar c=[word characterAtIndex:i];
        NSString *k=[NSString stringWithCharacters:&c length:1].lowercaseString;
        NSString *mapped=map[k];
        if (!mapped) return nil;
        [out appendString:mapped];
    }
    return out.copy;
}

int main() {
    @autoreleasepool {
        buildLayouts();
        NSArray *enabled = @[@"en", @"ru", @"ua"];
        NSString *word = @"ghbdtn";
        
        if (isWordValidInLang(word, @"en")) {
            printf("Valid EN, abort\n");
            return 0;
        }
        
        for (NSString *lang in enabled) {
            if ([lang isEqual:@"en"]) continue;
            NSDictionary *map = [lang isEqual:@"ru"] ? gRU : gUA;
            if (!map) continue;
            NSString *cand = transformWord(word, map);
            printf("lang %s, cand: %s\n", lang.UTF8String, cand.UTF8String);
            if (isWordValidInLang(cand, lang)) {
                printf("SUCCESS: %s (%s)\n", cand.UTF8String, lang.UTF8String);
                return 0;
            }
        }
    }
    return 0;
}
