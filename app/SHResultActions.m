#import "SHResultActions.h"
#import <CoreAudio/CoreAudio.h>
#import <dlfcn.h>
static NSString *Script(NSString *source){
 NSDictionary *error=nil;[[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];NSInteger code=[error[NSAppleScriptErrorNumber] integerValue];
 return !error || code==userCanceledErr?nil:code==errAEEventNotPermitted?@"macOS blocked this command. Allow Superhound in Privacy & Security → Automation.":@"The command did not finish.";
}
static NSString *ToggleMute(void){
 AudioObjectID device=0;UInt32 size=sizeof(device),muted=0;AudioObjectPropertyAddress address={kAudioHardwarePropertyDefaultOutputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
 if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&address,0,NULL,&size,&device) || !device)return @"No sound output is available.";
 address=(AudioObjectPropertyAddress){kAudioDevicePropertyMute,kAudioObjectPropertyScopeOutput,kAudioObjectPropertyElementMain};size=sizeof(muted);
 if(!AudioObjectHasProperty(device,&address) || AudioObjectGetPropertyData(device,&address,0,NULL,&size,&muted))return @"This sound output cannot be muted.";
 muted=!muted;return AudioObjectSetPropertyData(device,&address,0,NULL,size,&muted)?@"Could not change mute.":nil;
}
// Ejects what Finder's Eject All ejects: removable, ejectable, and network volumes. Blocks until each volume is done.
static NSString *EjectAll(void){
 NSArray *keys=@[NSURLVolumeIsEjectableKey,NSURLVolumeIsRemovableKey,NSURLVolumeIsLocalKey];NSUInteger ejected=0,failed=0;
 for(NSURL *volume in [NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:keys options:NSVolumeEnumerationSkipHiddenVolumes]){
  NSDictionary *values=[volume resourceValuesForKeys:keys error:nil];
  if(![values[NSURLVolumeIsEjectableKey] boolValue] && ![values[NSURLVolumeIsRemovableKey] boolValue] && [values[NSURLVolumeIsLocalKey] boolValue])continue;
  if([NSWorkspace.sharedWorkspace unmountAndEjectDeviceAtURL:volume error:nil])ejected++;else failed++;
 }
 return failed?[NSString stringWithFormat:@"%lu of %lu disks could not be ejected. An app may be using them.",(unsigned long)failed,(unsigned long)(failed+ejected)]:ejected?nil:@"There are no disks to eject.";
}
@implementation SHResultActions
+ (void)run:(NSString *)command completion:(void (^)(NSString *))completion {
 // Restart, Shut Down, and Log Out ask for confirmation in the system dialog (Apple Technical Q&A QA1134).
 // The events go without a reply: the login window can hold the reply while its dialog is open.
 NSNumber *event=@{@"command:sleep":@(kAESleep),@"command:restart":@(kAEShowRestartDialog),@"command:shutdown":@(kAEShowShutdownDialog),@"command:logout":@(kAELogOut)}[command];
 if(event){NSError *error=nil;NSAppleEventDescriptor *target=[NSAppleEventDescriptor descriptorWithBundleIdentifier:@"com.apple.loginwindow"];
  [[NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:event.unsignedIntValue targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID] sendEventWithOptions:NSAppleEventSendNoReply timeout:5 error:&error];
  completion(!error?nil:error.code==errAEEventNotPermitted?@"macOS blocked this command. Allow Superhound in Privacy & Security → Automation.":@"The command did not finish.");return;}
 if([command isEqual:@"command:lock"]){
  // macOS has no public call to lock the screen; this private one can change in a later macOS.
  void *login=dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login",RTLD_LAZY);int (*lock)(void)=login?(int (*)(void))dlsym(login,"SACLockScreenImmediate"):NULL;
  completion(lock?nil:@"This macOS does not let apps lock the screen.");if(lock)lock();return;
 }
 if([command isEqual:@"command:display"]){NSTask *task=[NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/usr/bin/pmset"] arguments:@[@"displaysleepnow"] error:nil terminationHandler:nil];completion(task?nil:@"Could not sleep the display.");return;}
 if([command isEqual:@"command:screensaver"]){[NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:@"/System/Library/CoreServices/ScreenSaverEngine.app"] configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:^(NSRunningApplication *app,NSError *error){(void)app;dispatch_async(dispatch_get_main_queue(),^{completion(error?@"Could not start the screen saver.":nil);});}];return;}
 if([command isEqual:@"command:mute"]){completion(ToggleMute());return;}
 if([command isEqual:@"command:dark"]){completion(Script(@"tell application id \"com.apple.systemevents\" to tell appearance preferences to set dark mode to not dark mode"));return;}
 if([command isEqual:@"command:trash"]){
  [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=@"Empty the Trash?";alert.informativeText=@"The items in the Trash are deleted permanently. You cannot undo this.";[alert addButtonWithTitle:@"Empty Trash"];[alert addButtonWithTitle:@"Cancel"];
  completion([alert runModal]==NSAlertFirstButtonReturn?Script(@"tell application id \"com.apple.finder\" to empty trash"):nil);return;
 }
 if([command isEqual:@"command:eject"]){dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSString *error=EjectAll();dispatch_async(dispatch_get_main_queue(),^{completion(error);});});return;}
 completion(@"This command is not available.");
}
+ (void)open:(NSDictionary *)result reveal:(BOOL)reveal completion:(void (^)(NSString *))completion {
 if([result[@"type"] isEqual:@"command"]){if(reveal)completion(@"A command has no location in Finder.");else [self run:result[@"path"] completion:completion];return;}
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
