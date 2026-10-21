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
// NO when the saved keys did not register; status names the reason.
@property(nonatomic,readonly) BOOL registered;
// YES when the saved keys are ⌘Space.
@property(nonatomic,readonly) BOOL commandSpace;
// Moves these keys from ⌘Space to ⌥Space when ⌥Space registers; status names the result.
- (void)leaveCommandSpace;
// For the search shortcut. YES turns off Spotlight's ⌘Space and gives ⌘Space to these keys; NO gives it back to Spotlight and moves these keys to ⌥Space when ⌥Space is free.
// Returns NO when macOS did not save Spotlight's shortcut; the keys then stay as they are.
- (BOOL)replaceSpotlight:(BOOL)replace;
// Spotlight's ⌘Space shortcut, read and written in com.apple.symbolichotkeys. setSpotlightEnabled: saves the setting and applies it at once.
@property(class,nonatomic,readonly) NSDictionary *spotlightHotKeys;
+ (BOOL)setSpotlightEnabled:(BOOL)enabled;
@end
