#import "SHResultActions.h"
#import <CoreAudio/CoreAudio.h>
#import <dlfcn.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
static NSString *Script(NSString *source){
 NSDictionary *error=nil;[[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];NSInteger code=[error[NSAppleScriptErrorNumber] integerValue];
 return !error || code==userCanceledErr?nil:code==errAEEventNotPermitted?NSLocalizedString(@"macOS blocked this command. Allow Superhound in Privacy & Security → Automation.",@"Error in the search panel; Privacy & Security → Automation is the place in System Settings"):NSLocalizedString(@"The command did not finish.",@"Error in the search panel");
}
static NSString *ToggleMute(void){
 AudioObjectID device=0;UInt32 size=sizeof(device),muted=0;AudioObjectPropertyAddress address={kAudioHardwarePropertyDefaultOutputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
 if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&address,0,NULL,&size,&device) || !device)return NSLocalizedString(@"No sound output is available.",nil);
 address=(AudioObjectPropertyAddress){kAudioDevicePropertyMute,kAudioObjectPropertyScopeOutput,kAudioObjectPropertyElementMain};size=sizeof(muted);
 if(!AudioObjectHasProperty(device,&address) || AudioObjectGetPropertyData(device,&address,0,NULL,&size,&muted))return NSLocalizedString(@"This sound output cannot be muted.",nil);
 muted=!muted;return AudioObjectSetPropertyData(device,&address,0,NULL,size,&muted)?NSLocalizedString(@"Could not change mute.",nil):nil;
}
// Ejects what Finder's Eject All ejects: removable, ejectable, and network volumes. Blocks until each volume is done.
static NSString *EjectAll(void){
 NSArray *keys=@[NSURLVolumeIsEjectableKey,NSURLVolumeIsRemovableKey,NSURLVolumeIsLocalKey];NSUInteger ejected=0,failed=0;
 for(NSURL *volume in [NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:keys options:NSVolumeEnumerationSkipHiddenVolumes]){
  NSDictionary *values=[volume resourceValuesForKeys:keys error:nil];
  if(![values[NSURLVolumeIsEjectableKey] boolValue] && ![values[NSURLVolumeIsRemovableKey] boolValue] && [values[NSURLVolumeIsLocalKey] boolValue])continue;
  if([NSWorkspace.sharedWorkspace unmountAndEjectDeviceAtURL:volume error:nil])ejected++;else failed++;
 }
 return failed?[NSString stringWithFormat:NSLocalizedString(@"%lu of %lu disks could not be ejected. An app may be using them.",@"The first argument is the number of failed disks, the second the number of all disks"),(unsigned long)failed,(unsigned long)(failed+ejected)]:ejected?nil:NSLocalizedString(@"There are no disks to eject.",nil);
}
// The key press goes when the previous app is in front again; after 1 second without it, nothing is pasted.
// kVK_ANSI_V is the V key position of ANSI and JIS keyboards; a layout with another letter there gets that letter's shortcut.
static void PressPaste(NSUInteger tries,void (^completion)(NSString *)){
 BOOL waiting=NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==NSProcessInfo.processInfo.processIdentifier;
 if(waiting && tries){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{PressPaste(tries-1,completion);});return;}
 if(waiting){completion(NSLocalizedString(@"The text is copied. Superhound could not return to the previous app, so nothing was pasted.",nil));return;}
 CGEventSourceRef source=CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
 for(int down=1;down>=0;down--){CGEventRef key=CGEventCreateKeyboardEvent(source,kVK_ANSI_V,down);CGEventSetFlags(key,kCGEventFlagMaskCommand);CGEventPost(kCGHIDEventTap,key);CFRelease(key);}
 if(source)CFRelease(source);completion(nil);
}
// A key press into another app needs Accessibility access. macOS asks once in each launch; without access the text stays copied.
static void Paste(void (^completion)(NSString *)){
 static BOOL asked;BOOL trusted=AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt:@(!asked)});asked=YES;
 if(trusted)PressPaste(20,completion);else completion(NSLocalizedString(@"The text is copied. To paste with Return, allow Superhound in System Settings → Privacy & Security → Accessibility.",@"System Settings → Privacy & Security → Accessibility is the place in System Settings"));
}
@implementation SHResultActions
+ (void)run:(NSString *)command completion:(void (^)(NSString *))completion {
 // Restart, Shut Down, and Log Out ask for confirmation in the system dialog (Apple Technical Q&A QA1134).
 // The events go without a reply: the login window can hold the reply while its dialog is open.
 NSNumber *event=@{@"command:sleep":@(kAESleep),@"command:restart":@(kAEShowRestartDialog),@"command:shutdown":@(kAEShowShutdownDialog),@"command:logout":@(kAELogOut)}[command];
 if(event){NSError *error=nil;NSAppleEventDescriptor *target=[NSAppleEventDescriptor descriptorWithBundleIdentifier:@"com.apple.loginwindow"];
  [[NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:event.unsignedIntValue targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID] sendEventWithOptions:NSAppleEventSendNoReply timeout:5 error:&error];
  completion(!error?nil:error.code==errAEEventNotPermitted?NSLocalizedString(@"macOS blocked this command. Allow Superhound in Privacy & Security → Automation.",@"Error in the search panel; Privacy & Security → Automation is the place in System Settings"):NSLocalizedString(@"The command did not finish.",@"Error in the search panel"));return;}
 if([command isEqual:@"command:lock"]){
  // macOS has no public call to lock the screen; this private one can change in a later macOS.
  void *login=dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login",RTLD_LAZY);int (*lock)(void)=login?(int (*)(void))dlsym(login,"SACLockScreenImmediate"):NULL;
  completion(lock?nil:NSLocalizedString(@"This macOS does not let apps lock the screen.",nil));if(lock)lock();return;
 }
 if([command isEqual:@"command:display"]){NSTask *task=[NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/usr/bin/pmset"] arguments:@[@"displaysleepnow"] error:nil terminationHandler:nil];completion(task?nil:NSLocalizedString(@"Could not sleep the display.",nil));return;}
 if([command isEqual:@"command:screensaver"]){[NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:@"/System/Library/CoreServices/ScreenSaverEngine.app"] configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:^(NSRunningApplication *app,NSError *error){(void)app;dispatch_async(dispatch_get_main_queue(),^{completion(error?NSLocalizedString(@"Could not start the screen saver.",nil):nil);});}];return;}
 if([command isEqual:@"command:mute"]){completion(ToggleMute());return;}
 if([command isEqual:@"command:dark"]){completion(Script(@"tell application id \"com.apple.systemevents\" to tell appearance preferences to set dark mode to not dark mode"));return;}
 if([command isEqual:@"command:trash"]){
  [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=NSLocalizedString(@"Empty the Trash?",nil);alert.informativeText=NSLocalizedString(@"The items in the Trash are deleted permanently. You cannot undo this.",nil);[alert addButtonWithTitle:NSLocalizedString(@"Empty Trash",@"Alert button")];[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Alert button")];
  completion([alert runModal]==NSAlertFirstButtonReturn?Script(@"tell application id \"com.apple.finder\" to empty trash"):nil);return;
 }
 if([command isEqual:@"command:eject"]){dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSString *error=EjectAll();dispatch_async(dispatch_get_main_queue(),^{completion(error);});});return;}
 completion(NSLocalizedString(@"This command is not available.",nil));
}
+ (void)perform:(NSString *)action result:(NSDictionary *)result application:(NSURL *)application completion:(void (^)(NSString *))completion {
 if([action isEqual:@"paste"]){Paste(completion);return;}
 if([@[@"url",@"web"] containsObject:result[@"type"]]){NSURL *url=[NSURL URLWithString:result[@"url"]];completion(url && [NSWorkspace.sharedWorkspace openURL:url]?nil:NSLocalizedString(@"Could not open this in your browser.",nil));return;}
 BOOL reveal=[action isEqual:@"reveal"];
 if([result[@"type"] isEqual:@"command"]){if(reveal)completion(NSLocalizedString(@"A command has no location in Finder.",nil));else [self run:result[@"path"] completion:completion];return;}
 NSURL *url=[NSURL fileURLWithPath:result[@"path"]];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  BOOL exists=[url checkResourceIsReachableAndReturnError:nil];
  dispatch_async(dispatch_get_main_queue(),^{
   if(!exists){completion(NSLocalizedString(@"This item is unavailable. Refreshing its location…",nil));return;}
   if(reveal){[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[url]];completion(nil);return;}
   if([action isEqual:@"trash"]){[NSWorkspace.sharedWorkspace recycleURLs:@[url] completionHandler:^(NSDictionary *moved,NSError *error){(void)moved;dispatch_async(dispatch_get_main_queue(),^{completion(error?NSLocalizedString(@"Could not move this item to the Trash. Check access and try again.",nil):nil);});}];return;}
   if(application){NSWorkspaceOpenConfiguration *config=NSWorkspaceOpenConfiguration.configuration;config.activates=YES;
    [NSWorkspace.sharedWorkspace openURLs:@[url] withApplicationAtURL:application configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){(void)app;dispatch_async(dispatch_get_main_queue(),^{completion(error?NSLocalizedString(@"Could not open this item with that app.",nil):nil);});}];return;}
   if([result[@"type"] isEqual:@"app"]){
    for(NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications)if([app.bundleURL.URLByStandardizingPath isEqual:url.URLByStandardizingPath]){
     BOOL activated=[app activateWithOptions:NSApplicationActivateAllWindows];completion(activated?nil:NSLocalizedString(@"Could not activate this app.",@"Error when the app could not come to the front"));return;
    }
    NSWorkspaceOpenConfiguration *config=NSWorkspaceOpenConfiguration.configuration;config.activates=YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){(void)app;dispatch_async(dispatch_get_main_queue(),^{completion(error?NSLocalizedString(@"Could not open this app. Check access and try again.",nil):nil);});}];
   }else if([result[@"type"] isEqual:@"settings"]){
    // System Settings opens a pane by its extension's bundle identifier.
    NSString *identifier=[NSBundle bundleWithURL:url].bundleIdentifier;NSURL *pane=identifier?[NSURL URLWithString:[@"x-apple.systempreferences:" stringByAppendingString:identifier]]:nil;
    completion(pane && [NSWorkspace.sharedWorkspace openURL:pane]?nil:NSLocalizedString(@"Could not open this setting.",@"A System Settings pane"));
   }else completion([NSWorkspace.sharedWorkspace openURL:url]?nil:NSLocalizedString(@"Could not open this item. Check access and try again.",nil));
  });
 });
}
@end
