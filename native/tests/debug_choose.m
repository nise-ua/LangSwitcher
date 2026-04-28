#import <Cocoa/Cocoa.h>

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
        if (!mapped) { [out appendString:k]; continue; }
        BOOL upper = (c>='A'&&c<='Z') || (c>=0x0400 && c<=0x04FF && c == [k.uppercaseString characterAtIndex:0]);
        [out appendString: upper ? mapped.uppercaseString : mapped];
    }
    return out.copy;
}

int main() {
    @autoreleasepool {
        buildLayouts();
        NSArray *enabled = @[@"en", @"ru", @"ua"];
        NSString *word = @"куфіщт";
        
        BOOL allCyr=YES; BOOL hasLat=NO;
        for(NSUInteger i=0;i<word.length;i++){
            unichar c=[word characterAtIndex:i];
            if(((c>='a'&&c<='z')||(c>='A'&&c<='Z'))){hasLat=YES;allCyr=NO;break;}
            if(!(c>=0x0400 && c<=0x04FF)&&isalnum(c))allCyr=NO;
        }
        
        printf("allCyr: %d, hasLat: %d\n", allCyr, hasLat);
        
        if (allCyr && !hasLat && [enabled containsObject:@"en"]) {
            BOOL validCyr = NO;
            for (NSString *lang in enabled) {
                if ([lang isEqual:@"en"]) continue;
                if (isWordValidInLang(word, lang)) validCyr = YES;
            }
            if (validCyr) printf("validCyr is YES, aborting\n");
            
            for (NSString *lang in enabled) {
                if ([lang isEqual:@"en"]) continue;
                NSDictionary *map = [lang isEqual:@"ru"] ? gRU_inv : gUA_inv;
                if (!map) continue;
                NSString *cand = transformWord(word, map);
                printf("lang %s, cand: %s\n", lang.UTF8String, cand.UTF8String);
                if (isWordValidInLang(cand, @"en")) {
                    printf("SUCCESS: %s (en)\n", cand.UTF8String);
                    break;
                }
            }
        }
    }
    return 0;
}
