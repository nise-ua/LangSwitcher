#import <Cocoa/Cocoa.h>

static BOOL isLatinChar(unichar c) { return (c>='a'&&c<='z')||(c>='A'&&c<='Z'); }
static BOOL isCyrChar(unichar c) { return c>=0x0400 && c<=0x04FF; }
static BOOL isCyrVowel(unichar c) {
    static const unichar v[]={0x430,0x435,0x451,0x438,0x456,0x457,0x454,0x43E,0x443,0x44B,0x44D,0x44E,0x44F,0};
    for(int i=0;v[i];i++) if(c==v[i]) return YES; return NO;
}
static BOOL isEnVowel(unichar c) { unichar l=c|32; return l=='a'||l=='e'||l=='i'||l=='o'||l=='u'||l=='y'; }

static double scoreCyr(NSString *word) {
    NSString *lo = word.lowercaseString;
    NSUInteger cyr=0, vow=0, alpha=0;
    for (NSUInteger i=0;i<lo.length;i++) {
        unichar c=[lo characterAtIndex:i];
        if (!isalpha(c)&&!isCyrChar(c)) continue;
        alpha++; if (isCyrChar(c)) { cyr++; if(isCyrVowel(c)) vow++; }
    }
    if (alpha==0 || (double)cyr/alpha < 0.85) return 0.0;
    double ratio = cyr ? (double)vow/cyr : 0;
    return MAX(0.0, 0.5 - fabs(ratio-0.42));
}

static double scoreEn(NSString *word) {
    NSString *lo = word.lowercaseString;
    NSUInteger lat=0, vow=0, alpha=0;
    for (NSUInteger i=0;i<lo.length;i++) {
        unichar c=[lo characterAtIndex:i];
        if (!isalpha(c)) continue;
        alpha++; if (isLatinChar(c)) { lat++; if(isEnVowel(c)) vow++; }
    }
    if (alpha==0 || (double)lat/alpha < 0.85) return 0.0;
    double ratio = lat ? (double)vow/lat : 0;
    return MAX(0.0, 0.5 - fabs(ratio-0.40));
}

int main() {
    @autoreleasepool {
        printf("the: %f vs еру: %f\n", scoreEn(@"the"), scoreCyr(@"еру"));
        printf("reason: %f vs куфіщт: %f\n", scoreEn(@"reason"), scoreCyr(@"куфіщт"));
    }
    return 0;
}
