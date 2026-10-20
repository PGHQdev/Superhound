#import "SHSettingsController.h"
#import "SHSpotlight.h"
#import "SHWeb.h"
@interface SHShortcutButton : NSButton
@property(copy) void (^recorded)(NSEvent *);
@property BOOL recording;
@end
@implementation SHShortcutButton
- (BOOL)acceptsFirstResponder{return YES;}
- (void)keyDown:(NSEvent *)event {if(_recording){_recording=NO;if(event.keyCode==53){self.title=@"Record Shortcut…";return;}if(self.recorded)self.recorded(event);}else [super keyDown:event];}
- (BOOL)performKeyEquivalent:(NSEvent *)event {if(_recording){[self keyDown:event];return YES;}return [super performKeyEquivalent:event];}
@end
@interface SHSettingsController () <NSTableViewDataSource,NSTableViewDelegate>
@end
@implementation SHSettingsController {
 SHLibrary *_library;SHHotKey *_hotKey,*_historyKey;NSArray<NSDictionary *> *_roots;
 NSTableView *_table;NSTextField *_message,*_shortcutStatus,*_historyStatus;SHShortcutButton *_recorder,*_historyRecorder;NSButton *_remove,*_reselect,*_spotlight;
}
static NSTextField *Label(NSView *view,NSString *text,NSRect frame,CGFloat size,BOOL secondary) {
 NSTextField *label=[NSTextField wrappingLabelWithString:text];label.frame=frame;label.font=[NSFont systemFontOfSize:size];if(secondary)label.textColor=NSColor.secondaryLabelColor;[view addSubview:label];return label;
}
static NSButton *Button(NSView *view,NSString *title,NSRect frame,id target,SEL action) {NSButton *button=[NSButton buttonWithTitle:title target:target action:action];button.frame=frame;[view addSubview:button];return button;}
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey historyKey:(SHHotKey *)historyKey {
 NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,740,812) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:window]))return nil;
 _library=library;_hotKey=hotKey;_historyKey=historyKey;_roots=@[];window.title=@"Superhound Settings";window.releasedWhenClosed=NO;window.accessibilityIdentifier=@"superhound.settings";
 NSView *view=window.contentView;
 Label(view,@"Your apps. Your folders. A shortcut away.",NSMakeRect(24,606,690,30),22,NO);
 Label(view,@"Apps are included automatically. Files are searched only inside folders you select. File contents stay unread.",NSMakeRect(24,558,690,40),13,YES);
 NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,326,692,222)];scroll.hasVerticalScroller=YES;scroll.borderType=NSBezelBorder;
 _table=[[NSTableView alloc] initWithFrame:scroll.bounds];_table.headerView=nil;_table.rowHeight=49;_table.delegate=self;_table.dataSource=self;_table.allowsEmptySelection=YES;_table.accessibilityIdentifier=@"superhound.locations";_table.accessibilityLabel=@"Search locations and coverage";NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"location"];column.width=670;[_table addTableColumn:column];scroll.documentView=_table;[view addSubview:scroll];
 Button(view,@"Add Folder…",NSMakeRect(20,286,120,32),self,@selector(add:));
 _remove=Button(view,@"Remove",NSMakeRect(144,286,90,32),self,@selector(remove:));
 _reselect=Button(view,@"Select Again…",NSMakeRect(238,286,135,32),self,@selector(reselect:));
 Button(view,@"Refresh Catalog",NSMakeRect(568,286,152,32),self,@selector(refresh:));
 _message=Label(view,@"Preparing catalog…",NSMakeRect(24,248,690,34),11,YES);_message.accessibilityIdentifier=@"superhound.locations.status";
 NSButton *exclude=[NSButton checkboxWithTitle:@"Skip generated folders (.git, node_modules, vendor, build, dist, DerivedData)" target:self action:@selector(exclude:)];exclude.frame=NSMakeRect(24,214,690,24);
 NSDictionary *settings=[NSDictionary dictionaryWithContentsOfURL:[library.stateURL URLByAppendingPathComponent:@"folders.plist"]];exclude.state=settings[@"excludeGenerated"] && ![settings[@"excludeGenerated"] boolValue]?NSControlStateValueOff:NSControlStateValueOn;[view addSubview:exclude];
 Label(view,@"Hidden descendants, package contents, online-only placeholders, and Superhound’s own data are skipped. Symbolic links are listed without following them.",NSMakeRect(24,176,690,32),11,YES);
 Label(view,@"Open search",NSMakeRect(24,142,115,24),15,NO);
 _recorder=[[SHShortcutButton alloc] initWithFrame:NSMakeRect(144,136,170,32)];_recorder.bezelStyle=NSBezelStyleRounded;_recorder.title=@"Record Shortcut…";_recorder.target=self;_recorder.action=@selector(record:);_recorder.accessibilityLabel=@"Record global search shortcut";[view addSubview:_recorder];
 __weak typeof(self) weak=self;_recorder.recorded=^(NSEvent *event){SHSettingsController *self=weak;[self->_hotKey recordEvent:event];self->_recorder.title=@"Record Shortcut…";[self shortcutStatus];};
 Button(view,@"Retry",NSMakeRect(320,136,70,32),self,@selector(retry:));Button(view,@"Keyboard Settings…",NSMakeRect(398,136,199,32),self,@selector(keyboardSettings:));
 _shortcutStatus=Label(view,@"",NSMakeRect(24,91,690,40),12,NO);_shortcutStatus.accessibilityIdentifier=@"superhound.shortcut.status";
 _spotlight=[NSButton checkboxWithTitle:@"Use ⌘Space in place of Spotlight" target:self action:@selector(spotlight:)];_spotlight.frame=NSMakeRect(24,58,690,24);_spotlight.accessibilityIdentifier=@"superhound.spotlight";[view addSubview:_spotlight];
 Label(view,@"Turns off Spotlight’s ⌘Space shortcut and opens Superhound with ⌘Space. To give ⌘Space back to Spotlight, turn this off, or choose Uninstall Superhound… in the menu bar.",NSMakeRect(44,15,670,38),11,YES);
 // The clipboard history row sits under the search shortcut text.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+52)];
 Label(view,@"Clipboard",NSMakeRect(24,24,115,24),15,NO);
 _historyRecorder=[[SHShortcutButton alloc] initWithFrame:NSMakeRect(144,18,170,32)];_historyRecorder.bezelStyle=NSBezelStyleRounded;_historyRecorder.title=@"Record Shortcut…";_historyRecorder.target=self;_historyRecorder.action=@selector(recordHistory:);_historyRecorder.accessibilityLabel=@"Record clipboard history shortcut";[view addSubview:_historyRecorder];
 _historyRecorder.recorded=^(NSEvent *event){SHSettingsController *self=weak;[self->_historyKey recordEvent:event];self->_historyRecorder.title=@"Record Shortcut…";[self shortcutStatus];};
 Button(view,[@"Use " stringByAppendingString:historyKey.defaultLabel],NSMakeRect(320,18,120,32),self,@selector(defaultHistoryShortcut:));
 _historyStatus=Label(view,@"",NSMakeRect(448,12,270,40),11,YES);_historyStatus.accessibilityIdentifier=@"superhound.history.shortcut.status";
 // The web search row sits under the clipboard row.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+44)];
 Label(view,@"Web search",NSMakeRect(24,24,115,24),15,NO);
 NSPopUpButton *engines=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(144,20,170,28) pullsDown:NO];engines.target=self;engines.action=@selector(engine:);engines.accessibilityIdentifier=@"superhound.search.engine";engines.accessibilityLabel=@"Web search engine";
 NSString *chosen=[NSUserDefaults.standardUserDefaults stringForKey:@"searchEngine"];for(NSDictionary *e in SHWeb.engines){[engines addItemWithTitle:e[@"name"]];if([e[@"id"] isEqual:chosen])[engines selectItemAtIndex:engines.numberOfItems-1];}[view addSubview:engines];
 Label(view,@"The last row of each search opens your text with this engine in your browser.",NSMakeRect(320,14,394,36),11,YES);
 // The completion switch sits under the web search row and starts off.
 for(NSView *v in view.subviews)[v setFrameOrigin:NSMakePoint(v.frame.origin.x,v.frame.origin.y+56)];
 NSButton *complete=[NSButton checkboxWithTitle:@"Complete the top result as you type" target:self action:@selector(complete:)];complete.frame=NSMakeRect(24,34,690,24);complete.accessibilityIdentifier=@"superhound.completion";
 complete.state=[NSUserDefaults.standardUserDefaults boolForKey:@"inlineCompletion"]?NSControlStateValueOn:NSControlStateValueOff;[view addSubview:complete];
 Label(view,@"The rest of the top result’s name appears after your text, selected. Tab or → keeps it; any other key replaces it.",NSMakeRect(44,6,670,26),11,YES);
 [self shortcutStatus];[self updateButtons];[window center];return self;
}
- (void)show {[NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self shortcutStatus];}
- (void)shortcutStatus {_spotlight.state=SHSpotlightEnabled(SHHotKey.spotlightHotKeys)?NSControlStateValueOff:NSControlStateValueOn;_shortcutStatus.stringValue=_hotKey.status?:@"Use Search in the menu bar while setting up your shortcut.";_historyStatus.stringValue=_historyKey.status?:@"";}
- (void)updateRoots:(NSArray<NSDictionary *> *)roots message:(NSString *)message {
 NSInteger selected=_table.selectedRow;NSString *identifier=selected>=0 && selected<(NSInteger)_roots.count?_roots[(NSUInteger)selected][@"id"]:nil;
 _roots=roots;[_table reloadData];for(NSUInteger i=0;i<roots.count;i++)if([roots[i][@"id"] isEqual:identifier])[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
 _message.stringValue=message;[self updateButtons];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return (NSInteger)_roots.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
 (void)tableView;(void)column;NSDictionary *root=_roots[(NSUInteger)row];NSView *cell=[[NSView alloc] initWithFrame:NSMakeRect(0,0,670,49)];
 NSTextField *name=Label(cell,[root[@"path"] stringByAbbreviatingWithTildeInPath],NSMakeRect(10,26,650,20),13,NO);name.lineBreakMode=NSLineBreakByTruncatingMiddle;
 Label(cell,[NSString stringWithFormat:@"%@ · %@ items%@",root[@"state"],[NSNumberFormatter localizedStringFromNumber:root[@"count"] numberStyle:NSNumberFormatterDecimalStyle],[root[@"apps"] boolValue]?@" · applications only":@""],NSMakeRect(10,6,650,19),11,YES);return cell;
}
- (NSString *)selectedRoot {NSInteger row=_table.selectedRow;return row>=0 && row<(NSInteger)_roots.count && ![_roots[(NSUInteger)row][@"apps"] boolValue]?_roots[(NSUInteger)row][@"id"]:nil;}
- (void)updateButtons {_remove.enabled=self.selectedRoot!=nil;_reselect.enabled=_remove.enabled;}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {(void)notification;[self updateButtons];}
- (void)chooseReplacing:(NSString *)identifier {
 NSOpenPanel *panel=NSOpenPanel.openPanel;panel.canChooseFiles=NO;panel.canChooseDirectories=YES;panel.allowsMultipleSelection=identifier==nil;panel.prompt=@"Search This Folder";panel.message=@"Search names in this folder and its local subfolders. File contents are not read.";
 [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){if(response==NSModalResponseOK)[self->_library addURLs:panel.URLs replacingRoot:identifier];}];
}
- (void)add:(id)sender {(void)sender;[self chooseReplacing:nil];}
- (void)reselect:(id)sender {(void)sender;if(self.selectedRoot)[self chooseReplacing:self.selectedRoot];}
- (void)remove:(id)sender {(void)sender;if(self.selectedRoot)[_library removeRoot:self.selectedRoot];}
- (void)refresh:(id)sender {(void)sender;[_library refresh];}
- (void)exclude:(NSButton *)sender {[_library setExcludeGenerated:sender.state==NSControlStateValueOn];}
- (void)record:(id)sender {(void)sender;_recorder.recording=YES;_recorder.title=@"Press shortcut…";[self.window makeFirstResponder:_recorder];}
- (void)retry:(id)sender {(void)sender;[_hotKey registerSaved];[_historyKey registerSaved];[self shortcutStatus];}
- (void)recordHistory:(id)sender {(void)sender;_historyRecorder.recording=YES;_historyRecorder.title=@"Press shortcut…";[self.window makeFirstResponder:_historyRecorder];}
- (void)defaultHistoryShortcut:(id)sender {(void)sender;[_historyKey useDefault];[self shortcutStatus];}
// On gives ⌘Space to Superhound. Off gives it back to Spotlight and moves Superhound to ⌥Space when ⌥Space is free.
- (void)spotlight:(NSButton *)sender {
 BOOL take=sender.state==NSControlStateValueOn;
 if(![SHHotKey setSpotlightEnabled:!take]){[self shortcutStatus];_shortcutStatus.stringValue=@"macOS did not save the Spotlight shortcut. Change it in Keyboard Settings….";return;}
 if(take)[_hotKey useDefault];else [_hotKey leaveCommandSpace];
 [self shortcutStatus];
}
- (void)complete:(NSButton *)sender {[NSUserDefaults.standardUserDefaults setBool:sender.state==NSControlStateValueOn forKey:@"inlineCompletion"];}
- (void)engine:(NSPopUpButton *)sender {[NSUserDefaults.standardUserDefaults setObject:SHWeb.engines[(NSUInteger)sender.indexOfSelectedItem][@"id"] forKey:@"searchEngine"];}
- (void)keyboardSettings:(id)sender {(void)sender;[_hotKey openKeyboardSettings];}
@end
