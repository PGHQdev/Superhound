#import <AppKit/AppKit.h>
#import "SHUpdate.h"
// Asks superhound.app for the latest release once a day, and installs a newer one when the user chooses it. The request carries no
// license key and no device ID. The defaults key updateCheckAutomatically (default YES) turns the daily check off; licenseServer replaces the server.
@interface SHUpdater : NSObject
// NO for a build without a certificate signature, such as a build from source: it cannot check that an update has the same signature.
@property(nonatomic,readonly) BOOL supported;
// A release newer than this build, or nil.
@property(nonatomic,readonly) SHRelease *latest;
// YES during a check or a download.
@property(nonatomic,readonly) BOOL busy;
@property(nonatomic) BOOL automatic;
// Called on the main thread when latest or busy changes.
@property(nonatomic,copy) void (^changed)(void);
- (void)start;
// Checks now and always reports the result.
- (void)check;
// Asks first, then downloads, checks, and installs the release, and relaunches.
- (void)install;
@end
