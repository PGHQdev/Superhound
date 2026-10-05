#import "SHAppDelegate.h"
#import "SHLibrary.h"
#import "SHHotKey.h"
#import "SHSettingsController.h"
#import "SHSearchPanelController.h"
#import "SHResultActions.h"
#import "SHMetrics.h"
#import <ServiceManagement/ServiceManagement.h>
@implementation SHAppDelegate {
 NSStatusItem *_statusItem;SHLibrary *_library;SHHotKey *_hotKey;SHSettingsController *_settings;SHSearchPanelController *_panel;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
 (void)notification;double launched=SHTime();
 NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *state=[base URLByAppendingPathComponent:@"Superhound" isDirectory:YES];
 _library=[[SHLibrary alloc] initWithStateURL:state];_hotKey=SHHotKey.new;[_hotKey registerSaved];
 _panel=[[SHSearchPanelController alloc] initWithQueries:SHQueryController.new];_panel.emoji=[[SHEmoji alloc] initWithURL:[NSBundle.mainBundle URLForResource:@"emoji" withExtension:@"tsv"]];_panel.usage=[[SHUsage alloc] initWithURL:[state URLByAppendingPathComponent:@"usage.plist"]];_settings=[[SHSettingsController alloc] initWithLibrary:_library hotKey:_hotKey];
 __weak typeof(self) weak=self;
 _hotKey.invoked=^{[weak search:nil];};
 _panel.openResult=^(NSDictionary *result,BOOL reveal){[SHResultActions open:result reveal:reveal completion:^(NSString *error){SHAppDelegate *self=weak;if(error){[self->_panel showError:error];[self->_library refresh];}}];};
 _library.updated=^(SHSearchSnapshot *snapshot,NSArray<NSDictionary *> *roots,NSString *message){
  SHAppDelegate *self=weak;if(!self)return;[self->_settings updateRoots:roots message:message];
  NSUInteger indexing=0,unavailable=0,items=snapshot.count;for(NSDictionary *r in roots){if([r[@"state"] isEqual:@"Indexing"])indexing++;else if(![r[@"state"] isEqual:@"Ready"] && ![r[@"state"] hasPrefix:@"Covered by"])unavailable++;}
  NSString *status=[NSString stringWithFormat:@"%lu searchable items%@%@",(unsigned long)items,indexing?[NSString stringWithFormat:@" · %lu locations indexing",(unsigned long)indexing]:@"",unavailable?@" · Check Search Locations for coverage":@""];
  [self->_panel updateSnapshot:snapshot status:status];
 };
 NSMenu *menu=NSMenu.new;[menu addItemWithTitle:@"Search" action:@selector(search:) keyEquivalent:@""];[menu addItemWithTitle:@"Search Locations…" action:@selector(settings:) keyEquivalent:@","];[menu addItemWithTitle:@"Refresh Catalog" action:@selector(refresh:) keyEquivalent:@""];[menu addItemWithTitle:@"Open at Login" action:@selector(loginItem:) keyEquivalent:@""];[menu addItem:NSMenuItem.separatorItem];[menu addItemWithTitle:@"Quit Superhound" action:@selector(terminate:) keyEquivalent:@"q"];
 for(NSMenuItem *item in menu.itemArray)if(item.action!=@selector(terminate:))item.target=self;
 _statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];_statusItem.button.image=[NSImage imageWithSystemSymbolName:@"magnifyingglass.circle.fill" accessibilityDescription:@"Superhound"];_statusItem.button.accessibilityIdentifier=@"superhound.menu";_statusItem.button.toolTip=@"Superhound — Search apps and files";_statusItem.menu=menu;
 NSMenu *main=NSMenu.new;NSMenuItem *app=NSMenuItem.new;app.submenu=[menu copy];[main addItem:app];
 NSMenuItem *edit=NSMenuItem.new;edit.title=@"Edit";NSMenu *editMenu=[[NSMenu alloc] initWithTitle:@"Edit"];[editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];[editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];[editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];[editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];edit.submenu=editMenu;[main addItem:edit];NSApp.mainMenu=main;
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(wake:) name:NSWorkspaceDidWakeNotification object:nil];
 [_library start];
 if(![NSUserDefaults.standardUserDefaults boolForKey:@"setupShown"]){[_settings show];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"setupShown"];}
 // Registered once; later launches respect the choice made in the menu or System Settings.
 if(![NSUserDefaults.standardUserDefaults boolForKey:@"loginItemOffered"]){[SMAppService.mainAppService registerAndReturnError:nil];[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"loginItemOffered"];}
 SHMeasure(@"launch_delegate_to_ready",launched);
}
- (void)search:(id)sender {(void)sender;[_panel toggle];}
- (void)settings:(id)sender {(void)sender;[_settings show];}
- (void)refresh:(id)sender {(void)sender;[_library refresh];}
- (void)loginItem:(id)sender {
 (void)sender;SMAppService *service=SMAppService.mainAppService;NSError *error=nil;
 if(!(service.status==SMAppServiceStatusEnabled?[service unregisterAndReturnError:&error]:[service registerAndReturnError:&error]))[_panel showError:[NSString stringWithFormat:@"Open at Login could not be changed. %@",error.localizedDescription]];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {if(item.action==@selector(loginItem:))item.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled?NSControlStateValueOn:NSControlStateValueOff;return YES;}
- (void)wake:(NSNotification *)notification {(void)notification;[_library refresh];}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {(void)sender;(void)flag;[_panel toggle];return NO;}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {(void)sender;return NO;}
@end
