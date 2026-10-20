#import <AppKit/AppKit.h>
@interface SHResultActions : NSObject
// action: open, reveal, openWith (application is the app to open with), trash, or paste (a ⌘V key press in the app in front).
// A result of type "url" or "web" opens its url in the default browser for any action.
+ (void)perform:(NSString *)action result:(NSDictionary *)result application:(NSURL *)application completion:(void (^)(NSString *error))completion;
@end
