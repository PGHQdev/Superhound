#import <AppKit/AppKit.h>
@interface SHResultActions : NSObject
// action: open, reveal, openWith (application is the app to open with), or trash.
+ (void)perform:(NSString *)action result:(NSDictionary *)result application:(NSURL *)application completion:(void (^)(NSString *error))completion;
@end
