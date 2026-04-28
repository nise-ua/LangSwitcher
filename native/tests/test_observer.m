#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@interface Observer : NSObject
@end
@implementation Observer
- (void)inputSourceChanged:(NSNotification *)note {
    TISInputSourceRef src = TISCopyCurrentKeyboardInputSource();
    CFStringRef name = TISGetInputSourceProperty(src, kTISPropertyLocalizedName);
    printf("Layout changed to: %s\n", [(NSString*)name UTF8String]);
    CFRelease(src);
}
@end

int main() {
    @autoreleasepool {
        Observer *obs = [Observer new];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:obs selector:@selector(inputSourceChanged:) name:(NSString*)kTISNotifySelectedKeyboardInputSourceChanged object:nil];
        printf("Listening for layout changes for 5 seconds...\n");
        // Run runloop for 5 seconds
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:5];
        while ([end timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:end];
        }
    }
    return 0;
}
