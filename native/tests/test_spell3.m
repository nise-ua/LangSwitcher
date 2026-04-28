#import <Cocoa/Cocoa.h>
int main() {
    @autoreleasepool {
        NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
        NSArray *tests = @[@"привіт", @"як", @"це"];
        for (NSString *w in tests) {
            NSRange r = [sc checkSpellingOfString:w startingAt:0 language:@"uk" wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
            printf("uk %s: %s\n", w.UTF8String, r.location == NSNotFound ? "VALID" : "INVALID");
            
            NSRange r2 = [sc checkSpellingOfString:w startingAt:0 language:@"uk_UA" wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
            printf("uk_UA %s: %s\n", w.UTF8String, r2.location == NSNotFound ? "VALID" : "INVALID");
        }
    }
    return 0;
}
