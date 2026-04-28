#import <Cocoa/Cocoa.h>
int main() {
    @autoreleasepool {
        NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
        NSArray *tests = @[@"hello", @"switches", @"ghbdtn", @"wrong", @"цкщтп"];
        for (NSString *w in tests) {
            NSRange r = [sc checkSpellingOfString:w startingAt:0 language:@"en" wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
            printf("%s: %s\n", w.UTF8String, r.location == NSNotFound ? "VALID" : "INVALID");
        }
    }
    return 0;
}
