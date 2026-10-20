#import <AppKit/AppKit.h>
#import "SHLicense.h"
// Activates and deactivates this Mac's license with superhound.app: the only network requests the app makes.
// The defaults key licenseServer replaces https://superhound.app for a local test server.
@interface SHActivation : NSObject
- (instancetype)initWithLicense:(SHLicense *)license;
// Called on the main thread after the license changes.
@property(nonatomic,copy) void (^changed)(void);
// Asks for a license key, with key as the first text, then activates this Mac.
- (void)enterKey:(NSString *)key;
// Asks first, then frees this Mac's activation and removes the license.
- (void)deactivate;
// superhound://activate?key=… from the purchase email or the install command.
- (void)openURL:(NSURL *)url;
@end
// The hardware UUID of this Mac, or nil.
NSString *SHHardwareUUID(void);
