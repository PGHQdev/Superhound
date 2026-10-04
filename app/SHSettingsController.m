#import "SHSettingsController.h"
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
 SHLibrary *_library;SHHotKey *_hotKey;NSArray<NSDictionary *> *_roots;
 NSTableView *_table;NSTextField *_message,*_shortcutStatus;SHShortcutButton *_recorder;NSButton *_remove,*_reselect;
}
static NSTextField *Label(NSView *view,NSString *text,NSRect frame,CGFloat size,BOOL secondary) {
 NSTextField *label=[NSTextField wrappingLabelWithString:text];label.frame=frame;label.font=[NSFont systemFontOfSize:size];if(secondary)label.textColor=NSColor.secondaryLabelColor;[view addSubview:label];return label;
}
static NSButton *Button(NSView *view,NSString *title,NSRect frame,id target,SEL action) {NSButton *button=[NSButton buttonWithTitle:title target:target action:action];button.frame=frame;[view addSubview:button];return button;}
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey {
 NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,740,660) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:window]))return nil;
 _library=library;_hotKey=hotKey;_roots=@[];window.title=@"Superhound · Search Locations";window.releasedWhenClosed=NO;window.accessibilityIdentifier=@"superhound.settings";
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
 Button(view,@"Use ⌘Space",NSMakeRect(320,136,120,32),self,@selector(defaultShortcut:));Button(view,@"Retry",NSMakeRect(442,136,70,32),self,@selector(retry:));Button(view,@"Keyboard Settings…",NSMakeRect(520,136,199,32),self,@selector(keyboardSettings:));
 _shortcutStatus=Label(view,@"",NSMakeRect(24,91,690,40),12,NO);_shortcutStatus.accessibilityIdentifier=@"superhound.shortcut.status";
 Label(view,@"Set up ⌘Space in System Settings → Keyboard → Keyboard Shortcuts: add an App Shortcut for Superhound with menu title “Search” and ⌘Space, and disable Spotlight’s “Show Spotlight search”. Both bindings must be configured; one does not replace the other. Then Retry here. To restore Spotlight later, quit Superhound and re-enable its shortcut.",NSMakeRect(24,15,690,68),11,YES);
 [self shortcutStatus];[self updateButtons];[window center];return self;
}
- (void)show {[NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self shortcutStatus];}
- (void)shortcutStatus {_shortcutStatus.stringValue=_hotKey.status?:@"Use Search in the menu bar while setting up your shortcut.";}
- (void)updateRoots:(NSArray<NSDictionary *> *)roots message:(NSString *)message {
 NSInteger selected=_table.selectedRow;NSString *identifier=selected>=0 && selected<(NSInteger)_roots.count?_roots[(NSUInteger)selected][@"id"]:nil;
 _roots=roots;[_table reloadData];for(NSUInteger i=0;i<roots.count;i++)if([roots[i][@"id"] isEqual:identifier])[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
 _message.stringValue=message;[self updateButtons];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return (NSInteger)_roots.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
 (void)tableView;(void)column;NSDictionary *root=_roots[(NSUInteger)row];NSView *cell=[[NSView alloc] initWithFrame:NSMakeRect(0,0,670,49)];
 NSTextField *name=Label(cell,[root[@"path"] stringByAbbreviatingWithTildeInPath],NSMakeRect(10,26,650,20),13,NO);name.lineBreakMode=NSLineBreakByTruncatingMiddle;
 Label(cell,[NSString stringWithFormat:@"%@ · %@ items%@",root[@"state"],root[@"count"],[root[@"apps"] boolValue]?@" · applications only":@""],NSMakeRect(10,6,650,19),11,YES);return cell;
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
- (void)retry:(id)sender {(void)sender;[_hotKey registerSaved];[self shortcutStatus];}
- (void)defaultShortcut:(id)sender {(void)sender;[_hotKey useDefault];[self shortcutStatus];}
- (void)keyboardSettings:(id)sender {(void)sender;[_hotKey openKeyboardSettings];}
@end
