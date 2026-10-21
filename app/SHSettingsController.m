#import "SHSettingsController.h"
#import "SHSpotlight.h"
#import "SHWeb.h"
#import "SHUpdater.h"
@interface SHShortcutButton : NSButton
@property(copy) void (^recorded)(NSEvent *);
@property BOOL recording;
@end
@implementation SHShortcutButton
- (BOOL)acceptsFirstResponder{return YES;}
- (void)keyDown:(NSEvent *)event {if(_recording){_recording=NO;if(event.keyCode==53){self.title=NSLocalizedString(@"Record Shortcut…",@"Button in Settings that starts a shortcut recording; 170 points wide");return;}if(self.recorded)self.recorded(event);}else [super keyDown:event];}
- (BOOL)performKeyEquivalent:(NSEvent *)event {if(_recording){[self keyDown:event];return YES;}return [super performKeyEquivalent:event];}
@end
@interface SHSettingsController () <NSTableViewDataSource,NSTableViewDelegate>
@end
@implementation SHSettingsController {
 SHLibrary *_library;SHHotKey *_hotKey,*_historyKey;NSArray<NSDictionary *> *_roots;
 NSTableView *_table;NSTextField *_message,*_shortcutStatus,*_historyStatus;SHShortcutButton *_recorder,*_historyRecorder;NSButton *_remove,*_reselect,*_spotlight;
}
NSTextField *SHLabel(NSView *view,NSString *text,NSRect frame,CGFloat size,BOOL secondary) {
 NSTextField *label=[NSTextField wrappingLabelWithString:text];label.frame=frame;label.font=[NSFont systemFontOfSize:size];if(secondary)label.textColor=NSColor.secondaryLabelColor;[view addSubview:label];return label;
}
// The app's languages: the code for AppleLanguages and the name in that language.
static NSArray<NSArray<NSString *> *> *Languages(void){return @[@[@"en",@"English"],@[@"ja",@"日本語"],@[@"de",@"Deutsch"],@[@"fr",@"Français"],@[@"es",@"Español"],@[@"zh-Hans",@"简体中文"],@[@"pt-BR",@"Português (Brasil)"]];}
NSButton *SHButton(NSView *view,NSString *title,NSRect frame,id target,SEL action) {NSButton *button=[NSButton buttonWithTitle:title target:target action:action];button.frame=frame;[view addSubview:button];return button;}
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey historyKey:(SHHotKey *)historyKey {
 NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,740,834) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:window]))return nil;
 _library=library;_hotKey=hotKey;_historyKey=historyKey;_roots=@[];window.title=NSLocalizedString(@"Superhound Settings",@"Settings window title");window.releasedWhenClosed=NO;window.accessibilityIdentifier=@"superhound.settings";
 NSView *view=window.contentView;
 SHLabel(view,NSLocalizedString(@"Your apps. Your folders. A shortcut away.",@"Heading at the top of Settings"),NSMakeRect(24,540,690,30),22,NO);
 SHLabel(view,NSLocalizedString(@"Apps are included automatically. Files are searched only inside folders you select. File contents stay unread.",nil),NSMakeRect(24,492,690,40),13,YES);
 NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,326,692,156)];scroll.hasVerticalScroller=YES;scroll.borderType=NSBezelBorder;
 _table=[[NSTableView alloc] initWithFrame:scroll.bounds];_table.headerView=nil;_table.rowHeight=49;_table.delegate=self;_table.dataSource=self;_table.allowsEmptySelection=YES;_table.accessibilityIdentifier=@"superhound.locations";_table.accessibilityLabel=NSLocalizedString(@"Search locations and coverage",@"VoiceOver label of the list of search locations");NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"location"];column.width=670;[_table addTableColumn:column];scroll.documentView=_table;[view addSubview:scroll];
 SHButton(view,NSLocalizedString(@"Add Folder…",@"Settings button; 120 points wide"),NSMakeRect(20,286,120,32),self,@selector(add:));
 _remove=SHButton(view,NSLocalizedString(@"Remove",@"Settings button: remove the selected search location; 90 points wide"),NSMakeRect(144,286,90,32),self,@selector(remove:));
 _reselect=SHButton(view,NSLocalizedString(@"Select Again…",@"Settings button: select the folder again to give access; 135 points wide"),NSMakeRect(238,286,135,32),self,@selector(reselect:));
 SHButton(view,NSLocalizedString(@"Refresh Catalog",@"Menu item and Settings button: scan the search locations again"),NSMakeRect(568,286,152,32),self,@selector(refresh:));
 _message=SHLabel(view,NSLocalizedString(@"Preparing catalog…",@"Status in Settings while the app starts"),NSMakeRect(24,248,690,34),11,YES);_message.accessibilityIdentifier=@"superhound.locations.status";
 NSButton *exclude=[NSButton checkboxWithTitle:NSLocalizedString(@"Skip generated folders (.git, node_modules, vendor, build, dist, DerivedData)",@"Settings check box; keep the folder names as they are") target:self action:@selector(exclude:)];exclude.frame=NSMakeRect(24,214,690,24);
 NSDictionary *settings=[NSDictionary dictionaryWithContentsOfURL:[library.stateURL URLByAppendingPathComponent:@"folders.plist"]];exclude.state=settings[@"excludeGenerated"] && ![settings[@"excludeGenerated"] boolValue]?NSControlStateValueOff:NSControlStateValueOn;[view addSubview:exclude];
 SHLabel(view,NSLocalizedString(@"Hidden descendants, package contents, online-only placeholders, and Superhound’s own data are skipped. Symbolic links are listed without following them.",nil),NSMakeRect(24,176,690,32),11,YES);
 SHLabel(view,NSLocalizedString(@"Open search",@"Settings row label for the search shortcut; 160 points wide"),NSMakeRect(24,142,160,24),15,NO);
 _recorder=[[SHShortcutButton alloc] initWithFrame:NSMakeRect(189,136,170,32)];_recorder.bezelStyle=NSBezelStyleRounded;_recorder.title=NSLocalizedString(@"Record Shortcut…",@"Button in Settings that starts a shortcut recording; 170 points wide");_recorder.target=self;_recorder.action=@selector(record:);_recorder.accessibilityLabel=NSLocalizedString(@"Record global search shortcut",@"VoiceOver label of the shortcut button");[view addSubview:_recorder];
 __weak typeof(self) weak=self;_recorder.recorded=^(NSEvent *event){SHSettingsController *self=weak;[self->_hotKey recordEvent:event];self->_recorder.title=NSLocalizedString(@"Record Shortcut…",@"Button in Settings that starts a shortcut recording; 170 points wide");[self shortcutStatus];};
 SHButton(view,NSLocalizedString(@"Retry",@"Settings button: register the shortcuts again; 100 points wide"),NSMakeRect(365,136,100,32),self,@selector(retry:));SHButton(view,NSLocalizedString(@"Keyboard Settings…",@"Settings button that opens System Settings → Keyboard; 199 points wide"),NSMakeRect(473,136,199,32),self,@selector(keyboardSettings:));
 _shortcutStatus=SHLabel(view,@"",NSMakeRect(24,91,690,40),12,NO);_shortcutStatus.accessibilityIdentifier=@"superhound.shortcut.status";
 _spotlight=[NSButton checkboxWithTitle:NSLocalizedString(@"Use ⌘Space in place of Spotlight",@"Settings check box") target:self action:@selector(spotlight:)];_spotlight.frame=NSMakeRect(24,58,690,24);_spotlight.accessibilityIdentifier=@"superhound.spotlight";[view addSubview:_spotlight];
 SHLabel(view,NSLocalizedString(@"Turns off Spotlight’s ⌘Space shortcut and opens Superhound with ⌘Space. To give ⌘Space back to Spotlight, turn this off, or choose Uninstall Superhound… in the menu bar.",@"Uninstall Superhound… is a menu item title"),NSMakeRect(44,15,670,38),11,YES);
 // The clipboard history row sits under the search shortcut text, with its status under it.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+96)];
 SHLabel(view,NSLocalizedString(@"Clipboard",@"Section label: the clipboard history; Settings row label (160 points wide) and search panel band; keep it short"),NSMakeRect(24,68,160,24),15,NO);
 _historyRecorder=[[SHShortcutButton alloc] initWithFrame:NSMakeRect(189,62,170,32)];_historyRecorder.bezelStyle=NSBezelStyleRounded;_historyRecorder.title=NSLocalizedString(@"Record Shortcut…",@"Button in Settings that starts a shortcut recording; 170 points wide");_historyRecorder.target=self;_historyRecorder.action=@selector(recordHistory:);_historyRecorder.accessibilityLabel=NSLocalizedString(@"Record clipboard history shortcut",@"VoiceOver label of the shortcut button");[view addSubview:_historyRecorder];
 _historyRecorder.recorded=^(NSEvent *event){SHSettingsController *self=weak;[self->_historyKey recordEvent:event];self->_historyRecorder.title=NSLocalizedString(@"Record Shortcut…",@"Button in Settings that starts a shortcut recording; 170 points wide");[self shortcutStatus];};
 SHButton(view,[NSString stringWithFormat:NSLocalizedString(@"Use %@",@"Settings button that restores the default shortcut; the argument is a shortcut such as ⌥⌘V; 120 points wide"),historyKey.defaultLabel],NSMakeRect(365,62,120,32),self,@selector(defaultHistoryShortcut:));
 _historyStatus=SHLabel(view,@"",NSMakeRect(24,12,690,44),12,NO);_historyStatus.accessibilityIdentifier=@"superhound.history.shortcut.status";
 // The web search row sits under the clipboard row.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+44)];
 SHLabel(view,NSLocalizedString(@"Web search",@"Settings row label; 160 points wide"),NSMakeRect(24,24,160,24),15,NO);
 NSPopUpButton *engines=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(189,20,170,28) pullsDown:NO];engines.target=self;engines.action=@selector(engine:);engines.accessibilityIdentifier=@"superhound.search.engine";engines.accessibilityLabel=NSLocalizedString(@"Web search engine",@"VoiceOver label of the search engine menu");
 NSString *chosen=[NSUserDefaults.standardUserDefaults stringForKey:@"searchEngine"];for(NSDictionary *e in SHWeb.engines){[engines addItemWithTitle:e[@"name"]];if([e[@"id"] isEqual:chosen])[engines selectItemAtIndex:engines.numberOfItems-1];}[view addSubview:engines];
 SHLabel(view,NSLocalizedString(@"The last row of each search opens your text with this engine in your browser.",nil),NSMakeRect(365,14,349,36),11,YES);
 // The completion switch sits under the web search row; completion stays off until the user turns it on.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+56)];
 NSButton *complete=[NSButton checkboxWithTitle:NSLocalizedString(@"Complete the top result as you type",@"Settings check box") target:self action:@selector(complete:)];complete.frame=NSMakeRect(24,34,690,24);complete.accessibilityIdentifier=@"superhound.completion";
 complete.state=[NSUserDefaults.standardUserDefaults boolForKey:@"inlineCompletion"]?NSControlStateValueOn:NSControlStateValueOff;[view addSubview:complete];
 SHLabel(view,NSLocalizedString(@"The rest of the top result’s name appears after your text, selected. Tab or → keeps it; any other key replaces it.",@"Tab is the key name"),NSMakeRect(44,6,670,26),11,YES);
 // The language row sits at the bottom. Each language shows its own name; System Default follows the macOS language order.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+44)];
 SHLabel(view,NSLocalizedString(@"Language",@"Settings row label; 160 points wide"),NSMakeRect(24,20,160,24),15,NO);
 NSPopUpButton *languages=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(189,16,300,28) pullsDown:NO];languages.target=self;languages.action=@selector(language:);languages.accessibilityIdentifier=@"superhound.language";languages.accessibilityLabel=NSLocalizedString(@"Language",@"Settings row label; 160 points wide");
 [languages addItemWithTitle:NSLocalizedString(@"System Default",@"First item of the language menu: use the macOS language order")];NSString *own=[[NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier][@"AppleLanguages"] firstObject];
 for(NSArray *l in Languages()){[languages addItemWithTitle:l[1]];if([own isKindOfClass:NSString.class] && ([own isEqual:l[0]] || [own hasPrefix:[l[0] stringByAppendingString:@"-"]]))[languages selectItemAtIndex:languages.numberOfItems-1];}[view addSubview:languages];
 [self shortcutStatus];[self updateButtons];[window center];return self;
}
- (void)show {[NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self shortcutStatus];}
- (void)shortcutStatus {_spotlight.state=SHSpotlightEnabled(SHHotKey.spotlightHotKeys)?NSControlStateValueOff:NSControlStateValueOn;_shortcutStatus.stringValue=_hotKey.status?:NSLocalizedString(@"Use Search in the menu bar while setting up your shortcut.",@"Search is the menu item title");_historyStatus.stringValue=_historyKey.status?:@"";}
- (void)updateRoots:(NSArray<NSDictionary *> *)roots message:(NSString *)message {
 NSInteger selected=_table.selectedRow;NSString *identifier=selected>=0 && selected<(NSInteger)_roots.count?_roots[(NSUInteger)selected][@"id"]:nil;
 _roots=roots;[_table reloadData];for(NSUInteger i=0;i<roots.count;i++)if([roots[i][@"id"] isEqual:identifier])[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
 _message.stringValue=message;[self updateButtons];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return (NSInteger)_roots.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {(void)tableView;(void)column;return SHRootCell(_roots[(NSUInteger)row],670);}
NSView *SHRootCell(NSDictionary *root,CGFloat width) {
 NSView *cell=[[NSView alloc] initWithFrame:NSMakeRect(0,0,width,49)];
 NSTextField *name=SHLabel(cell,[root[@"path"] stringByAbbreviatingWithTildeInPath],NSMakeRect(10,26,width-20,20),13,NO);name.lineBreakMode=NSLineBreakByTruncatingMiddle;
 SHLabel(cell,[NSString stringWithFormat:[root[@"apps"] boolValue]?NSLocalizedString(@"%@ · %@ items · applications only",@"Search location row in Settings; the first argument is a state such as Ready, the second a number"):NSLocalizedString(@"%@ · %@ items",@"Search location row in Settings; the first argument is a state such as Ready, the second a number"),root[@"label"],[NSNumberFormatter localizedStringFromNumber:root[@"count"] numberStyle:NSNumberFormatterDecimalStyle]],NSMakeRect(10,6,width-20,19),11,YES);return cell;
}
void SHChooseFolders(NSWindow *window,SHLibrary *library,NSString *replacing) {
 NSOpenPanel *panel=NSOpenPanel.openPanel;panel.canChooseFiles=NO;panel.canChooseDirectories=YES;panel.allowsMultipleSelection=replacing==nil;panel.prompt=NSLocalizedString(@"Search This Folder",@"Button of the folder selection window");panel.message=NSLocalizedString(@"Search names in this folder and its local subfolders. File contents are not read.",@"Message in the folder selection window");
 [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response){if(response==NSModalResponseOK)[library addURLs:panel.URLs replacingRoot:replacing];}];
}
- (NSString *)selectedRoot {NSInteger row=_table.selectedRow;return row>=0 && row<(NSInteger)_roots.count && ![_roots[(NSUInteger)row][@"apps"] boolValue]?_roots[(NSUInteger)row][@"id"]:nil;}
- (void)updateButtons {_remove.enabled=self.selectedRoot!=nil;_reselect.enabled=_remove.enabled;}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {(void)notification;[self updateButtons];}
- (void)add:(id)sender {(void)sender;SHChooseFolders(self.window,_library,nil);}
- (void)reselect:(id)sender {(void)sender;if(self.selectedRoot)SHChooseFolders(self.window,_library,self.selectedRoot);}
- (void)remove:(id)sender {(void)sender;if(self.selectedRoot)[_library removeRoot:self.selectedRoot];}
- (void)refresh:(id)sender {(void)sender;[_library refresh];}
- (void)exclude:(NSButton *)sender {[_library setExcludeGenerated:sender.state==NSControlStateValueOn];}
- (void)record:(id)sender {(void)sender;_recorder.recording=YES;_recorder.title=NSLocalizedString(@"Press shortcut…",@"Button in Settings while it records a shortcut; 170 points wide");[self.window makeFirstResponder:_recorder];}
- (void)retry:(id)sender {(void)sender;[_hotKey registerSaved];[_historyKey registerSaved];[self shortcutStatus];}
- (void)recordHistory:(id)sender {(void)sender;_historyRecorder.recording=YES;_historyRecorder.title=NSLocalizedString(@"Press shortcut…",@"Button in Settings while it records a shortcut; 170 points wide");[self.window makeFirstResponder:_historyRecorder];}
- (void)defaultHistoryShortcut:(id)sender {(void)sender;[_historyKey useDefault];[self shortcutStatus];}
- (void)spotlight:(NSButton *)sender {
 BOOL saved=[_hotKey replaceSpotlight:sender.state==NSControlStateValueOn];[self shortcutStatus];
 if(!saved)_shortcutStatus.stringValue=NSLocalizedString(@"macOS did not save the Spotlight shortcut. Change it in Keyboard Settings….",@"Keyboard Settings… is the button title");
}
- (void)complete:(NSButton *)sender {[NSUserDefaults.standardUserDefaults setBool:sender.state==NSControlStateValueOn forKey:@"inlineCompletion"];}
- (void)engine:(NSPopUpButton *)sender {[NSUserDefaults.standardUserDefaults setObject:SHWeb.engines[(NSUInteger)sender.indexOfSelectedItem][@"id"] forKey:@"searchEngine"];}
// AppKit reads the language only at launch, so a change offers to relaunch, with the alert text of the macOS Language & Region pane.
- (void)language:(NSPopUpButton *)sender {
 NSInteger i=sender.indexOfSelectedItem;if(i<=0)[NSUserDefaults.standardUserDefaults removeObjectForKey:@"AppleLanguages"];else [NSUserDefaults.standardUserDefaults setObject:@[Languages()[(NSUInteger)i-1][0]] forKey:@"AppleLanguages"];
 NSAlert *alert=NSAlert.new;alert.messageText=[NSString stringWithFormat:NSLocalizedString(@"Language setting for %@ has changed. Do you want to relaunch the app now?",@"Alert after a language change; the argument is Superhound"),@"Superhound"];
 [alert addButtonWithTitle:NSLocalizedString(@"Relaunch Now",@"Alert button")];[alert addButtonWithTitle:NSLocalizedString(@"Don’t Relaunch",@"Alert button")];
 [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){if(response==NSAlertFirstButtonReturn)SHRelaunch(NSBundle.mainBundle.bundleURL);}];
}
- (void)keyboardSettings:(id)sender {(void)sender;[_hotKey openKeyboardSettings];}
@end
