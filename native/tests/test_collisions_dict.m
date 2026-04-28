#import <Cocoa/Cocoa.h>

static NSDictionary<NSString*,NSString*> *gRU_inv;
static void buildLayouts(void) {
    NSDictionary *gRU = @{
        @"q":@"й",@"w":@"ц",@"e":@"у",@"r":@"к",@"t":@"е",@"y":@"н",@"u":@"г",
        @"i":@"ш",@"o":@"щ",@"p":@"з",@"[":@"х",@"]":@"ъ",
        @"a":@"ф",@"s":@"ы",@"d":@"в",@"f":@"а",@"g":@"п",@"h":@"р",@"j":@"о",
        @"k":@"л",@"l":@"д",@";":@"ж",@"'":@"э",
        @"z":@"я",@"x":@"ч",@"c":@"с",@"v":@"м",@"b":@"и",@"n":@"т",@"m":@"ь",
        @",":@"б",@".":@"ю",@"`":@"ё"
    };
    NSMutableDictionary *ri = [NSMutableDictionary new];
    [gRU enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s){ ri[v]=k; }];
    gRU_inv = ri.copy;
}

static BOOL isWordValidInLang(NSString *word, NSString *lang) {
    NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
    NSRange r = [sc checkSpellingOfString:word startingAt:0 language:lang wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
    return r.location == NSNotFound;
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
        // Just test all valid 3-letter combinations (brute force a bit)
        // Actually, let's just use the logic:
        // Prefer English if word.length >= 3 and cand is valid English.
    }
    return 0;
}
