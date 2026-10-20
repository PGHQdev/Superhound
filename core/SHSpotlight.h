#import <Foundation/Foundation.h>
// Spotlight's ⌘Space shortcut is entry 64 of AppleSymbolicHotKeys in the com.apple.symbolichotkeys preferences. macOS treats a missing entry as on, with ⌘Space.
extern NSString *const SHSpotlightEntry;
// NO only when the entry is present and its enabled flag is off.
BOOL SHSpotlightEnabled(NSDictionary *hotKeys);
// The hot keys with only the entry's enabled flag changed; a missing or damaged entry gets macOS's ⌘Space.
NSDictionary *SHSpotlightHotKeys(NSDictionary *hotKeys,BOOL enabled);
// Spotlight's ⌘Space is off for Superhound when it is off and Superhound's search shortcut is ⌘Space; only then does an uninstall turn it on again.
BOOL SHSpotlightTakenOver(NSDictionary *hotKeys,NSInteger code,NSInteger modifiers);
