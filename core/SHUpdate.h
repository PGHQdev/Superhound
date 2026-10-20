#import <Foundation/Foundation.h>
#import <Security/Security.h>
// One release from superhound.app/api/latest: {version, build, url, sha256, notes}.
@interface SHRelease : NSObject
// nil unless version is text, build a positive integer, url and notes https (or http to 127.0.0.1 or localhost with a port), and sha256 64 lowercase hex digits.
+ (instancetype)releaseWithJSON:(NSData *)data;
@property(nonatomic,readonly) NSString *version,*sha256;
@property(nonatomic,readonly) NSInteger build;
@property(nonatomic,readonly) NSURL *url,*notes;
@end
// The automatic check runs once a day.
BOOL SHUpdateDue(NSDate *last,NSDate *now);
// Puts the app in the downloaded zip in place of the installed app, the same way scripts/install.sh does: the previous app goes
// to .superhound-backup.*/previous.app next to it. It first checks that the installed app is no symlink and is older, then the zip's SHA-256, the bundle identifier, the build number,
// and that the new app's signature is valid and meets requirement. Returns nil, or a message for the user; on failure the installed app is unchanged.
NSString *SHUpdateInstall(NSURL *zip,SHRelease *release,NSURL *installed,SecRequirementRef requirement);
