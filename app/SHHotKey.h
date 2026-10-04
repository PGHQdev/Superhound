#import <AppKit/AppKit.h>
@interface SHHotKey : NSObject
@property(nonatomic,copy) void (^invoked)(void);
@property(nonatomic,readonly) NSString *status;
@property(nonatomic,readonly) NSString *label;
- (BOOL)registerSaved;
- (BOOL)recordEvent:(NSEvent *)event;
- (void)useDefault;
- (void)openKeyboardSettings;
@end
