#import <Cocoa/Cocoa.h>
int main() {
    @autoreleasepool {
        NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
        NSRange r = [sc checkSpellingOfString:@"ghbdtn" startingAt:0 language:@"en" wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
        printf("is ghbdtn valid EN? %d\n", r.location == NSNotFound);
    }
    return 0;
}
