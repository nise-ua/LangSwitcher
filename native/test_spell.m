#import <Cocoa/Cocoa.h>
int main() {
    NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
    NSString *scLang = @"en";
    NSString *word = @"the";
    NSRange r = [sc checkSpellingOfString:word startingAt:0 language:scLang wrap:NO inSpellDocumentWithTag:0 wordCount:NULL];
    NSLog(@"'the' valid in en: %d", r.location == NSNotFound);
    return 0;
}
