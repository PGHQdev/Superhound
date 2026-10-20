#import "SHAppDelegate.h"
#import "SHLibrary.h"
#import "SHHotKey.h"
#import "SHSettingsController.h"
#import "SHSearchPanelController.h"
#import "SHResultActions.h"
#import "SHMetrics.h"
#import "SHClipboard.h"
#import "SHActivation.h"
#import "SHUpdater.h"
#import <Carbon/Carbon.h>
#import <ServiceManagement/ServiceManagement.h>
@implementation SHAppDelegate {
 NSStatusItem *_statusItem;SHLibrary *_library;SHHotKey *_hotKey,*_historyKey;SHSettingsController *_settings;SHSearchPanelController *_panel;SHClipboard *_clipboard;NSInteger _pasteboardCount;NSTimer *_pasteboardTimer;SHLicense *_license;SHActivation *_activation;SHUpdater *_updater;
}
// The public half of the key that superhound.app signs activations with.
static NSString *const LicensePublicKey=@"BB1mBfflJqWXPJerDDR+MLSwGOCcP/HFGM8f+HPNMfzveASmPB5nxJDLeVq75oJGlcI+vaNjTXAJLArVLjLUFi4=";
// The license exists before launch ends, because a superhound://activate link can launch the app.
- (void)applicationWillFinishLaunching:(NSNotification *)notification {
 (void)notification;NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 _license=[[SHLicense alloc] initWithURL:[base URLByAppendingPathComponent:@"Superhound/license.plist"] publicKey:[[NSData alloc] initWithBase64EncodedString:LicensePublicKey options:0] device:SHLicenseDevice(SHHardwareUUID())];_activation=[[SHActivation alloc] initWithLicense:_license];
 [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(openURLEvent:reply:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}
- (void)openURLEvent:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)reply {
 (void)reply;NSString *text=[event paramDescriptorForKeyword:keyDirectObject].stringValue;NSURL *url=text?[NSURL URLWithString:text]:nil;
 if(url)dispatch_async(dispatch_get_main_queue(),^{[self->_activation openURL:url];});
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
 (void)notification;double launched=SHTime();
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *state=[base URLByAppendingPathComponent:@"Superhound" isDirectory:YES];
 _library=[[SHLibrary alloc] initWithStateURL:state];
 _hotKey=[[SHHotKey alloc] initWithName:@"shortcut" identifier:1 code:kVK_Space modifiers:cmdKey label:@"⌘Space" menu:@"Search"];[_hotKey registerSaved];
 _historyKey=[[SHHotKey alloc] initWithName:@"historyShortcut" identifier:2 code:kVK_ANSI_V modifiers:cmdKey|optionKey label:@"⌥⌘V" menu:@"Clipboard History"];[_historyKey registerSaved];
 _panel=[[SHSearchPanelController alloc] initWithQueries:SHQueryController.new];_panel.emoji=[[SHEmoji alloc] initWithURL:[NSBundle.mainBundle URLForResource:@"emoji" withExtension:@"tsv"]];_panel.usage=[[SHUsage alloc] initWithURL:[state URLByAppendingPathComponent:@"usage.plist"]];_settings=[[SHSettingsController alloc] initWithLibrary:_library hotKey:_hotKey historyKey:_historyKey];
 _panel.licensed=_license.licensed;
 _clipboard=[[SHClipboard alloc] initWithURL:[state URLByAppendingPathComponent:@"clipboard.plist"]];_panel.clipboard=_clipboard;_pasteboardCount=NSPasteboard.generalPasteboard.changeCount;
 __weak typeof(self) weak=self;
 _activation.changed=^{SHAppDelegate *self=weak;if(self)self->_panel.licensed=self->_license.licensed;};
 _updater=SHUpdater.new;_updater.changed=^{SHAppDelegate *self=weak;if(self)self->_panel.update=self->_updater.busy?nil:self->_updater.latest.version;};_panel.installUpdate=^{SHAppDelegate *self=weak;[self->_updater install];};
 _hotKey.invoked=^{[weak search:nil];};_historyKey.invoked=^{[weak history:nil];};
 // macOS sends no notice when the pasteboard changes, so its change count is read twice a second.
 _pasteboardTimer=[NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer){(void)timer;[weak readPasteboard];}];_pasteboardTimer.tolerance=0.25;
 _panel.openResult=^(NSDictionary *result,NSString *action,NSURL *application){[SHResultActions perform:action result:result application:application completion:^(NSString *error){SHAppDelegate *self=weak;if(error){[self->_panel showError:error];if(![@[@"command",@"clipboard"] containsObject:result[@"type"]])[self->_library refresh];}}];};
 _library.updated=^(SHSearchSnapshot *snapshot,NSArray<NSDictionary *> *roots,NSString *message){
  SHAppDelegate *self=weak;if(!self)return;[self->_settings updateRoots:roots message:message];
  NSUInteger indexing=0,unavailable=0,items=snapshot.count;for(NSDictionary *r in roots){if([r[@"state"] isEqual:@"Indexing"])indexing++;else if(![r[@"state"] isEqual:@"Ready"] && ![r[@"state"] hasPrefix:@"Covered by"])unavailable++;}
  NSString *status=[NSString stringWithFormat:@"%lu searchable items%@%@",(unsigned long)items,indexing?[NSString stringWithFormat:@" · %lu locations indexing",(unsigned long)indexing]:@"",unavailable?@" · Check Search Locations for coverage":@""];
  [self->_panel updateSnapshot:snapshot status:status];
 };
 NSMenu *menu=NSMenu.new;[menu addItemWithTitle:@"Update" action:@selector(installUpdate:) keyEquivalent:@""];[menu addItemWithTitle:@"Search" action:@selector(search:) keyEquivalent:@""];[menu addItemWithTitle:@"Clipboard History" action:@selector(history:) keyEquivalent:@""];[menu addItemWithTitle:@"Search Locations…" action:@selector(settings:) keyEquivalent:@","];[menu addItemWithTitle:@"Refresh Catalog" action:@selector(refresh:) keyEquivalent:@""];[menu addItemWithTitle:@"Clear Clipboard History" action:@selector(clearHistory:) keyEquivalent:@""];[menu addItemWithTitle:@"Open at Login" action:@selector(loginItem:) keyEquivalent:@""];[menu addItemWithTitle:@"Enter License…" action:@selector(license:) keyEquivalent:@""];[menu addItem:NSMenuItem.separatorItem];[menu addItemWithTitle:@"About Superhound" action:@selector(about:) keyEquivalent:@""];[menu addItemWithTitle:@"Check for Updates…" action:@selector(checkUpdates:) keyEquivalent:@""];[menu addItemWithTitle:@"Check for Updates Automatically" action:@selector(automaticUpdates:) keyEquivalent:@""];[menu addItem:NSMenuItem.separatorItem];[menu addItemWithTitle:@"Quit Superhound" action:@selector(terminate:) keyEquivalent:@"q"];
 for(NSMenuItem *item in menu.itemArray)if(item.action!=@selector(terminate:))item.target=self;
 _statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];_statusItem.button.image=[NSImage imageWithSystemSymbolName:@"magnifyingglass.circle.fill" accessibilityDescription:@"Superhound"];_statusItem.button.accessibilityIdentifier=@"superhound.menu";_statusItem.button.toolTip=@"Superhound — Search apps and files";_statusItem.menu=menu;
 NSMenu *main=NSMenu.new;NSMenuItem *app=NSMenuItem.new;app.submenu=[menu copy];[main addItem:app];
 NSMenuItem *edit=NSMenuItem.new;edit.title=@"Edit";NSMenu *editMenu=[[NSMenu alloc] initWithTitle:@"Edit"];[editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];[editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];[editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];[editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];edit.submenu=editMenu;[main addItem:edit];NSApp.mainMenu=main;
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(wake:) name:NSWorkspaceDidWakeNotification object:nil];
 [_library start];[_updater start];
 if(![NSUserDefaults.standardUserDefaults boolForKey:@"setupShown"]){[_settings show];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"setupShown"];}
 // Registered once; later launches respect the choice made in the menu or System Settings.
 if(![NSUserDefaults.standardUserDefaults boolForKey:@"loginItemOffered"]){[SMAppService.mainAppService registerAndReturnError:nil];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"loginItemOffered"];}
 SHMeasure(@"launch_delegate_to_ready",launched);
}
- (void)search:(id)sender {(void)sender;[_panel toggle];}
- (void)history:(id)sender {(void)sender;[_panel toggleHistory];}
- (void)clearHistory:(id)sender {
 (void)sender;[NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=@"Clear the clipboard history?";alert.informativeText=[NSString stringWithFormat:@"All %lu copied items are deleted from this Mac. You cannot undo this.",(unsigned long)_clipboard.count];[alert addButtonWithTitle:@"Clear History"];[alert addButtonWithTitle:@"Cancel"];
 if([alert runModal]==NSAlertFirstButtonReturn)[_clipboard clear];
}
- (void)readPasteboard {
 NSPasteboard *board=NSPasteboard.generalPasteboard;NSInteger count=board.changeCount;if(count==_pasteboardCount)return;_pasteboardCount=count;
 // The app in front when the change is read is named as the source; Superhound marks its own copies.
 NSArray<NSString *> *types=board.types;NSRunningApplication *front=NSWorkspace.sharedWorkspace.frontmostApplication;BOOL own=[types containsObject:SHOwnCopyType];
 [_clipboard addText:[board stringForType:NSPasteboardTypeString] types:types application:own?nil:front.bundleIdentifier source:own?@"Superhound":front.localizedName];
}
- (void)license:(id)sender {(void)sender;if(_license.licensed)[_activation deactivate];else [_activation enterKey:nil];}
- (void)installUpdate:(id)sender {(void)sender;[_updater install];}
- (void)checkUpdates:(id)sender {(void)sender;[_updater check];}
- (void)automaticUpdates:(id)sender {(void)sender;_updater.automatic=!_updater.automatic;}
- (void)about:(id)sender {
 (void)sender;[NSApp activateIgnoringOtherApps:YES];
 NSString *credits=_license.licensed?@"Licensed for this Mac.":@"Unlicensed. A license is $19 for 3 Macs at superhound.app.";
 [NSApp orderFrontStandardAboutPanelWithOptions:@{NSAboutPanelOptionCredits:[[NSAttributedString alloc] initWithString:credits attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}]}];
}
- (void)settings:(id)sender {(void)sender;[_settings show];}
- (void)refresh:(id)sender {(void)sender;[_library refresh];}
- (void)loginItem:(id)sender {
 (void)sender;SMAppService *service=SMAppService.mainAppService;NSError *error=nil;
 if(!(service.status==SMAppServiceStatusEnabled?[service unregisterAndReturnError:&error]:[service registerAndReturnError:&error]))[_panel showError:[NSString stringWithFormat:@"Open at Login could not be changed. %@",error.localizedDescription]];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
 if(item.action==@selector(installUpdate:)){item.hidden=!_updater.latest;item.title=_updater.latest?[NSString stringWithFormat:@"Update to %@…",_updater.latest.version]:@"Update";return !_updater.busy;}
 if(item.action==@selector(checkUpdates:))return !_updater.busy;if(item.action==@selector(automaticUpdates:)){item.hidden=!_updater.supported;item.state=_updater.automatic?NSControlStateValueOn:NSControlStateValueOff;}
 if(item.action==@selector(license:))item.title=_license.licensed?@"Deactivate License…":@"Enter License…";if(item.action==@selector(clearHistory:))return _clipboard.count>0;if(item.action==@selector(loginItem:))item.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled?NSControlStateValueOn:NSControlStateValueOff;return YES;}
- (void)wake:(NSNotification *)notification {(void)notification;[_library refresh];}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {(void)sender;(void)flag;[_panel toggle];return NO;}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {(void)sender;return NO;}
@end
