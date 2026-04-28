#import <Cocoa/Cocoa.h>
int main() {
    @autoreleasepool {
        NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
        NSArray *tests = @[@"привет", @"как", @"дела", @"привіт", @"фзз", @"цкщтп"];
        for (NSString *w in tests) {
            NSRange r = [sc checkSpellingOfString:w startingAt:0 language:@"ru" wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
            printf("ru %s: %s\n", w.UTF8String, r.location == NSNotFound ? "VALID" : "INVALID");
        }
    }
    return 0;
}
