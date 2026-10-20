#import "SHUpdater.h"
@implementation SHUpdater {NSURLSession *_session;NSTimer *_timer;SecRequirementRef _requirement;}
static void Tell(NSString *title,NSString *text){[NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=title;alert.informativeText=text;[alert runModal];}
static NSString *Version(void){return NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"";}
- (instancetype)init {
 if((self=[super init])){
  NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;configuration.timeoutIntervalForRequest=30;configuration.timeoutIntervalForResource=600;_session=[NSURLSession sessionWithConfiguration:configuration];
  [NSUserDefaults.standardUserDefaults registerDefaults:@{@"updateCheckAutomatically":@YES}];
  // An update must meet this build's own designated requirement, which names the Superhound certificate. An ad-hoc requirement names one code hash, so it cannot match a new build.
  SecCodeRef running=NULL;SecStaticCodeRef code=NULL;CFDictionaryRef info=NULL;
  if(SecCodeCopySelf(kSecCSDefaultFlags,&running)==errSecSuccess && SecCodeCopyStaticCode(running,kSecCSDefaultFlags,&code)==errSecSuccess && SecCodeCopySigningInformation(code,kSecCSSigningInformation,&info)==errSecSuccess && [((__bridge NSDictionary *)info)[(id)kSecCodeInfoCertificates] count])SecCodeCopyDesignatedRequirement(code,kSecCSDefaultFlags,&_requirement);
  if(info)CFRelease(info);if(code)CFRelease(code);if(running)CFRelease(running);
 }
 return self;
}
- (void)dealloc {if(_requirement)CFRelease(_requirement);}
- (BOOL)supported {return _requirement!=NULL;}
- (BOOL)automatic {return [NSUserDefaults.standardUserDefaults boolForKey:@"updateCheckAutomatically"];}
- (void)setAutomatic:(BOOL)automatic {[NSUserDefaults.standardUserDefaults setBool:automatic forKey:@"updateCheckAutomatically"];}
// A check 60 s after launch, then each hour; each one asks the server only when the last answer is a day old.
- (void)start {
 if(!self.supported)return;__weak typeof(self) weak=self;
 _timer=[NSTimer scheduledTimerWithTimeInterval:3600 repeats:YES block:^(NSTimer *timer){(void)timer;[weak checkIfDue];}];_timer.tolerance=600;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_SEC),dispatch_get_main_queue(),^{[weak checkIfDue];});
}
- (void)checkIfDue {if(self.automatic && !_busy && SHUpdateDue([NSUserDefaults.standardUserDefaults objectForKey:@"updateCheckedAt"],NSDate.date))[self fetch:NO];}
- (void)check {
 if(!self.supported){Tell(NSLocalizedString(@"This copy cannot update itself",nil),NSLocalizedString(@"This copy of Superhound was built from source. To update it, pull the latest code, then run the build and install commands again.",nil));return;}
 if(!_busy)[self fetch:YES];
}
- (void)setBusy:(BOOL)busy {_busy=busy;if(self.changed)self.changed();}
- (void)fetch:(BOOL)manual {
 NSString *server=[NSUserDefaults.standardUserDefaults stringForKey:@"licenseServer"]?:@"https://superhound.app";NSURL *url=[NSURL URLWithString:[server stringByAppendingString:@"/api/latest"]];
 if(!url){if(manual)Tell(NSLocalizedString(@"Superhound could not check for updates",nil),[NSString stringWithFormat:NSLocalizedString(@"The server address %@ is not valid.",@"The argument is a web address"),server]);return;}
 self.busy=YES;
 [[_session dataTaskWithURL:url completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
  NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;SHRelease *latest=status==200?[SHRelease releaseWithJSON:data]:nil;
  dispatch_async(dispatch_get_main_queue(),^{
   if(latest)[NSUserDefaults.standardUserDefaults setObject:NSDate.date forKey:@"updateCheckedAt"];
   if(latest)self->_latest=latest.build>[NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] integerValue]?latest:nil;
   self.busy=NO;if(!manual)return;
   if(self->_latest)[self install];
   else if(!latest)Tell(NSLocalizedString(@"Superhound could not check for updates",nil),error?error.localizedDescription:NSLocalizedString(@"superhound.app sent an answer that Superhound cannot read. Try again later.",nil));
   else Tell(NSLocalizedString(@"Superhound is up to date",nil),[NSString stringWithFormat:NSLocalizedString(@"Version %@ is the latest version.",@"The argument is a version number such as 0.4.0"),Version()]);
  });
 }] resume];
}
- (void)install {
 SHRelease *release=_latest;if(!release || _busy)return;
 [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=[NSString stringWithFormat:NSLocalizedString(@"Superhound %@ is available",@"The argument is a version number such as 0.5.0"),release.version];
 alert.informativeText=[NSString stringWithFormat:NSLocalizedString(@"You have version %@. Superhound downloads the update, checks its signature, and opens again.",@"The argument is the installed version number"),Version()];
 [alert addButtonWithTitle:NSLocalizedString(@"Install and Relaunch",@"Alert button")];[alert addButtonWithTitle:NSLocalizedString(@"Later",@"Alert button: ask again later")];[alert addButtonWithTitle:NSLocalizedString(@"Release Notes",@"Alert button that opens the release notes web page")];
 NSModalResponse response=[alert runModal];if(response==NSAlertThirdButtonReturn)[NSWorkspace.sharedWorkspace openURL:release.notes];if(response!=NSAlertFirstButtonReturn)return;
 self.busy=YES;SecRequirementRef requirement=(SecRequirementRef)CFRetain(_requirement);NSURL *installed=NSBundle.mainBundle.bundleURL;
 [[_session downloadTaskWithURL:release.url completionHandler:^(NSURL *location,NSURLResponse *answer,NSError *error){
  // The downloaded file is deleted when this block returns, so the install runs here, off the main thread.
  NSInteger status=[answer isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)answer).statusCode:0;
  NSString *message=error?[NSString stringWithFormat:NSLocalizedString(@"The download failed. %@",@"The argument is the system network error text"),error.localizedDescription]:status!=200?[NSString stringWithFormat:NSLocalizedString(@"The download failed with error %ld.",@"The argument is an HTTP status code such as 404"),(long)status]:SHUpdateInstall(location,release,installed,requirement);
  CFRelease(requirement);
  dispatch_async(dispatch_get_main_queue(),^{
   self.busy=NO;if(message){Tell(NSLocalizedString(@"Superhound is not updated",nil),message);return;}
   // A shell waits until this process ends, then opens the new app at the same path.
   NSTask *task=NSTask.new;task.executableURL=[NSURL fileURLWithPath:@"/bin/sh"];task.arguments=@[@"-c",@"while /bin/kill -0 \"$0\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\"",[NSString stringWithFormat:@"%d",NSProcessInfo.processInfo.processIdentifier],installed.path];
   if([task launchAndReturnError:nil])[NSApp terminate:nil];else Tell(NSLocalizedString(@"Superhound is updated",nil),NSLocalizedString(@"Quit Superhound and open it again to use the new version.",nil));
  });
 }] resume];
}
@end
