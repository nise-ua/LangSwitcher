#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
int main() {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef ev = CGEventCreateKeyboardEvent(src, 0, true);
    CGEventSetIntegerValueField(ev, kCGEventSourceUserData, 1337);
    int64_t val = CGEventGetIntegerValueField(ev, kCGEventSourceUserData);
    NSLog(@"val = %lld", val);
    return 0;
}
