#import "SHResultActions.h"
@implementation SHResultActions
+ (void)open:(NSDictionary *)result reveal:(BOOL)reveal completion:(void (^)(NSString *))completion {
 NSURL *url=[NSURL fileURLWithPath:result[@"path"]];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  BOOL exists=[url checkResourceIsReachableAndReturnError:nil];
  dispatch_async(dispatch_get_main_queue(),^{
   if(!exists){completion(@"This item is unavailable. Refreshing its location…");return;}
   if(reveal){[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[url]];completion(nil);return;}
   if([result[@"type"] isEqual:@"app"]){
    for(NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications)if([app.bundleURL.URLByStandardizingPath isEqual:url.URLByStandardizingPath]){
     BOOL activated=[app activateWithOptions:NSApplicationActivateAllWindows];completion(activated?nil:@"Could not activate this app.");return;
    }
    NSWorkspaceOpenConfiguration *config=NSWorkspaceOpenConfiguration.configuration;config.activates=YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){(void)app;dispatch_async(dispatch_get_main_queue(),^{completion(error?@"Could not open this app. Check access and try again.":nil);});}];
   }else if([result[@"type"] isEqual:@"settings"]){
    // System Settings opens a pane by its extension's bundle identifier.
    NSString *identifier=[NSBundle bundleWithURL:url].bundleIdentifier;NSURL *pane=identifier?[NSURL URLWithString:[@"x-apple.systempreferences:" stringByAppendingString:identifier]]:nil;
    completion(pane && [NSWorkspace.sharedWorkspace openURL:pane]?nil:@"Could not open this setting.");
   }else completion([NSWorkspace.sharedWorkspace openURL:url]?nil:@"Could not open this item. Check access and try again.");
  });
 });
}
@end
