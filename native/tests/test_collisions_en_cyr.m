#import <Cocoa/Cocoa.h>

static NSDictionary<NSString*,NSString*> *gRU;
static void buildLayouts(void) {
    gRU = @{
        @"q":@"й",@"w":@"ц",@"e":@"у",@"r":@"к",@"t":@"е",@"y":@"н",@"u":@"г",
        @"i":@"ш",@"o":@"щ",@"p":@"з",@"[":@"х",@"]":@"ъ",
        @"a":@"ф",@"s":@"ы",@"d":@"в",@"f":@"а",@"g":@"п",@"h":@"р",@"j":@"о",
        @"k":@"л",@"l":@"д",@";":@"ж",@"'":@"э",
        @"z":@"я",@"x":@"ч",@"c":@"с",@"v":@"м",@"b":@"и",@"n":@"т",@"m":@"ь",
        @",":@"б",@".":@"ю",@"`":@"ё"
    };
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
        NSArray *testWords = @[@"the", @"and", @"you", @"that", @"was", @"for", @"are", @"with", @"his", @"they", @"this", @"have", @"from", @"one", @"had", @"word", @"but", @"not", @"what", @"all", @"were", @"when", @"your", @"can", @"said", @"there", @"use", @"each", @"which", @"she", @"do", @"how", @"their", @"if", @"will", @"up", @"other", @"about", @"out", @"many", @"then", @"them", @"these", @"so", @"some", @"her", @"would", @"make", @"like", @"him", @"into", @"time", @"has", @"look", @"two", @"more", @"write", @"go", @"see", @"number", @"no", @"way", @"could", @"people", @"my", @"than", @"first", @"water", @"been", @"call", @"who", @"oil", @"its", @"now", @"find", @"long", @"down", @"day", @"did", @"get", @"come", @"made", @"may", @"part"];
        for (NSString *w in testWords) {
            NSString *cand = transformWord(w, gRU);
            if (cand && isWordValidInLang(cand, @"ru")) {
                printf("COLLISION: %s -> %s\n", w.UTF8String, cand.UTF8String);
            }
        }
    }
    return 0;
}
