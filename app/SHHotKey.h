#import <AppKit/AppKit.h>
@interface SHHotKey : NSObject
// name: the prefix of the saved defaults, for example "shortcut" for shortcutCode, shortcutModifiers, and shortcutLabel.
// menu: the title of the menu bar item that does the same; the status names it as the fallback.
- (instancetype)initWithName:(NSString *)name identifier:(UInt32)identifier code:(UInt32)code modifiers:(UInt32)modifiers label:(NSString *)label menu:(NSString *)menu;
@property(nonatomic,copy) void (^invoked)(void);
@property(nonatomic,readonly) NSString *status;
@property(nonatomic,readonly) NSString *label;
@property(nonatomic,readonly) NSString *defaultLabel;
// The app's other shortcut; recordEvent: and useDefault refuse its keys.
@property(nonatomic,weak) SHHotKey *other;
- (BOOL)registerSaved;
- (BOOL)recordEvent:(NSEvent *)event;
- (void)useDefault;
- (void)openKeyboardSettings;
// Spotlight's ⌘Space shortcut, read and written in com.apple.symbolichotkeys. setSpotlightEnabled: saves the setting and applies it at once.
@property(class,nonatomic,readonly) NSDictionary *spotlightHotKeys;
+ (BOOL)setSpotlightEnabled:(BOOL)enabled;
@end
