#import "SHWelcomeController.h"
#import "SHSettingsController.h"
#import "SHSpotlight.h"
@interface SHWelcomeController () <NSTableViewDataSource,NSTableViewDelegate,NSWindowDelegate>
@end
@implementation SHWelcomeController {
 SHLibrary *_library;SHHotKey *_hotKey,*_historyKey;NSArray<NSDictionary *> *_folders;NSArray<NSArray *> *_rows;
 NSTableView *_table;SHShortcutButton *_recorder,*_historyRecorder;NSTextField *_shortcuts,*_spotlightNote,*_empty,*_try,*_progress,*_done;NSButton *_spotlight;NSImageView *_check;BOOL _shown,_tried;
}
// Step text is 20 points right of the step titles; buttons sit 4 points left of the text, as in Settings.
static const CGFloat Width=640,Text=Width-44-24;
static CGFloat RowHeight(NSArray *row){CGFloat height=0;for(NSUInteger i=1;i<row.count;i++)height=MAX(height,NSHeight([row[i] frame]));return height;}
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey historyKey:(SHHotKey *)historyKey {
 NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,Width,600) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:window]))return nil;
 _library=library;_hotKey=hotKey;_historyKey=historyKey;_folders=@[];window.title=NSLocalizedString(@"Welcome to Superhound",@"Welcome window title and heading");window.releasedWhenClosed=NO;window.delegate=self;window.accessibilityIdentifier=@"superhound.welcome";
 NSView *view=window.contentView;
 NSTextField *heading=SHLabel(view,window.title,NSMakeRect(24,0,Width-48,30),22,NO),*intro=SHLabel(view,NSLocalizedString(@"Three steps to your first search.",@"Welcome window text under the heading"),NSMakeRect(24,0,Width-48,20),13,YES);
 NSTextField *step1=SHLabel(view,NSLocalizedString(@"1. Your shortcut",@"Welcome window step title"),NSMakeRect(24,0,Width-48,22),15,NO);
 _shortcuts=SHLabel(view,@"",NSMakeRect(44,0,Text,20),13,NO);_shortcuts.accessibilityIdentifier=@"superhound.welcome.shortcuts";
 _spotlight=[NSButton checkboxWithTitle:NSLocalizedString(@"Use ⌘Space in place of Spotlight",@"Settings check box") target:self action:@selector(spotlight:)];_spotlight.frame=NSMakeRect(44,0,Text,24);_spotlight.accessibilityIdentifier=@"superhound.welcome.spotlight";[view addSubview:_spotlight];
 _spotlightNote=SHLabel(view,NSLocalizedString(@"Turns off Spotlight’s ⌘Space shortcut and opens Superhound with ⌘Space. To give ⌘Space back to Spotlight, turn this off, or choose Uninstall Superhound… in the menu bar.",@"Uninstall Superhound… is a menu item title"),NSMakeRect(64,0,Text-20,30),11,YES);
 // The recorders sit at x 200, 4 points left of a 160-point label column after the step text, as in Settings.
 NSTextField *searchLabel=SHLabel(view,NSLocalizedString(@"Open search",@"Settings row label for the search shortcut; 160 points wide"),NSMakeRect(44,0,152,20),13,NO),*historyLabel=SHLabel(view,NSLocalizedString(@"Clipboard",@"Section label: the clipboard history; Settings row label (160 points wide) and search panel band; keep it short"),NSMakeRect(44,0,152,20),13,NO);
 _recorder=[[SHShortcutButton alloc] initWithFrame:NSMakeRect(200,0,170,32) hotKey:hotKey];_recorder.accessibilityLabel=NSLocalizedString(@"Record global search shortcut",@"VoiceOver label of the shortcut button");[view addSubview:_recorder];
 _historyRecorder=[[SHShortcutButton alloc] initWithFrame:NSMakeRect(200,0,170,32) hotKey:historyKey];_historyRecorder.accessibilityLabel=NSLocalizedString(@"Record clipboard history shortcut",@"VoiceOver label of the shortcut button");[view addSubview:_historyRecorder];
 __weak typeof(self) weak=self;_recorder.changed=_historyRecorder.changed=^{[weak refresh];};
 NSTextField *step2=SHLabel(view,NSLocalizedString(@"2. Your folders",@"Welcome window step title"),NSMakeRect(24,0,Width-48,22),15,NO);
 NSTextField *apps=SHLabel(view,NSLocalizedString(@"Apps are included automatically. Files are searched only inside folders you select. File contents stay unread.",nil),NSMakeRect(44,0,Text,34),13,YES);
 NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(44,0,Text,100)];scroll.hasVerticalScroller=YES;scroll.borderType=NSBezelBorder;
 _table=[[NSTableView alloc] initWithFrame:scroll.bounds];_table.headerView=nil;_table.rowHeight=49;_table.delegate=self;_table.dataSource=self;_table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleNone;_table.accessibilityIdentifier=@"superhound.welcome.locations";_table.accessibilityLabel=NSLocalizedString(@"Search locations and coverage",@"VoiceOver label of the list of search locations");
 NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"location"];column.width=Text-20;[_table addTableColumn:column];scroll.documentView=_table;[view addSubview:scroll];
 // Before the first folder, the empty list says what to do.
 _empty=SHLabel(view,NSLocalizedString(@"Only selected folders are searched. Click Add Folder… to add one.",@"Add Folder… is the button title in Settings"),NSMakeRect(60,0,Text-32,20),13,YES);_empty.alignment=NSTextAlignmentCenter;
 NSButton *add=SHButton(view,NSLocalizedString(@"Add Folder…",@"Settings button; 120 points wide"),NSMakeRect(40,0,120,32),self,@selector(add:));
 NSTextField *permissions=SHLabel(view,NSLocalizedString(@"macOS asks once for access to folders such as Documents. Click Allow so Superhound can find your files. macOS also asks for Accessibility access the first time you paste from the clipboard history.",@"Welcome window note; Allow is the button title in the macOS permission window; Accessibility is the System Settings item"),NSMakeRect(44,0,Text,44),11,YES);
 NSTextField *step3=SHLabel(view,NSLocalizedString(@"3. Your first search",@"Welcome window step title"),NSMakeRect(24,0,Width-48,22),15,NO);
 _try=SHLabel(view,@"",NSMakeRect(44,0,Text,34),13,NO);
 NSButton *search=SHButton(view,NSLocalizedString(@"Open Search Panel",@"Welcome window button; 170 points wide"),NSMakeRect(40,0,170,32),self,@selector(search:));
 _progress=SHLabel(view,NSLocalizedString(@"Preparing catalog…",@"Status in Settings while the app starts"),NSMakeRect(222,0,Width-24-222,20),12,YES);_progress.accessibilityIdentifier=@"superhound.welcome.progress";
 _check=[NSImageView imageViewWithImage:[[NSImage imageWithSystemSymbolName:@"checkmark.circle.fill" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightRegular]]];_check.frame=NSMakeRect(44,0,18,18);_check.contentTintColor=NSColor.systemGreenColor;_check.accessibilityElement=NO;[view addSubview:_check];
 _done=SHLabel(view,NSLocalizedString(@"Done. Superhound learns what you open.",@"Welcome window line after the first opened search result"),NSMakeRect(68,0,Text-24,20),13,NO);_done.accessibilityIdentifier=@"superhound.welcome.done";
 _rows=@[@[@20,heading],@[@2,intro],@[@18,step1],@[@4,_shortcuts],@[@8,searchLabel,_recorder],@[@4,historyLabel,_historyRecorder],@[@8,_spotlight],@[@2,_spotlightNote],@[@18,step2],@[@4,apps],@[@8,scroll,_empty],@[@8,add],@[@6,permissions],@[@18,step3],@[@4,_try],@[@8,search,_progress],@[@10,_done,_check]];
 _spotlight.hidden=_spotlightNote.hidden=YES;[self refresh];[window center];return self;
}
// The Spotlight switch shows when the search shortcut is ⌘Space and Spotlight still has ⌘Space; it stays while the window is open, so a click does not move the rows.
- (void)show {
 _shown=YES;_spotlight.hidden=_spotlightNote.hidden=!(_hotKey.commandSpace && SHSpotlightEnabled(SHHotKey.spotlightHotKeys));
 [_table reloadData];[self refresh];[NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];
}
// Shortcut changes in Settings show when the window becomes key again.
- (void)windowDidBecomeKey:(NSNotification *)notification {(void)notification;[self refresh];}
- (void)refresh {
 [_recorder showKeys];[_historyRecorder showKeys];_spotlight.state=SHSpotlightEnabled(SHHotKey.spotlightHotKeys)?NSControlStateValueOff:NSControlStateValueOn;
 _shortcuts.stringValue=!_hotKey.registered?(_hotKey.status?:@""):!_historyKey.registered?(_historyKey.status?:@""):[NSString stringWithFormat:NSLocalizedString(@"Press %@ to search. Press %@ for the clipboard history.",@"Welcome window text; the arguments are shortcuts such as ⌘Space and ⌥⌘V"),_hotKey.label,_historyKey.label];
 _try.stringValue=[NSString stringWithFormat:NSLocalizedString(@"Press %@ and type part of an app name. Typos work, such as safri.",@"Welcome window text; the argument is a shortcut such as ⌘Space; safri is a typing error for Safari, keep it as it is"),_hotKey.label];
 _empty.hidden=_folders.count>0;_done.hidden=_check.hidden=!_tried;[self layout];
}
// Rows from the top, each after its gap. A row with a hidden first view takes no space, the views of a row share its middle, and the window keeps its top edge.
- (void)layout {
 CGFloat total=24;
 for(NSArray *row in _rows){for(NSUInteger i=1;i<row.count;i++)if([row[i] isKindOfClass:NSTextField.class]){NSTextField *label=row[i];NSRect frame=label.frame;frame.size.height=ceil([label.cell cellSizeForBounds:NSMakeRect(0,0,NSWidth(frame),CGFLOAT_MAX)].height);label.frame=frame;}if(![row[1] isHidden])total+=[row[0] doubleValue]+RowHeight(row);}
 NSRect frame=self.window.frame,size=[self.window frameRectForContentRect:NSMakeRect(0,0,Width,total)];[self.window setFrame:NSMakeRect(NSMinX(frame),NSMaxY(frame)-NSHeight(size),NSWidth(size),NSHeight(size)) display:YES];
 CGFloat y=total;for(NSArray *row in _rows){if([row[1] isHidden])continue;CGFloat height=RowHeight(row);y-=[row[0] doubleValue]+height;for(NSUInteger i=1;i<row.count;i++){NSView *v=row[i];[v setFrameOrigin:NSMakePoint(NSMinX(v.frame),round(y+(height-NSHeight(v.frame))/2))];}}
}
- (void)updateRoots:(NSArray<NSDictionary *> *)roots count:(NSUInteger)count indexing:(BOOL)indexing {
 // As in Settings, a closed window reloads its list only when it opens.
 _folders=[roots filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"apps == NO"]];if(self.window.isVisible || self.window.isMiniaturized)[_table reloadData];
 NSString *items=[NSNumberFormatter localizedStringFromNumber:@(count) numberStyle:NSNumberFormatterDecimalStyle];
 _progress.stringValue=[NSString stringWithFormat:indexing?NSLocalizedString(@"Indexing… %@ items so far",@"Welcome window status; the argument is a number"):NSLocalizedString(@"Ready: %@ items",@"Welcome window status; the argument is a number"),items];[self refresh];
}
- (void)resultOpened {if(!_shown || _tried)return;_tried=YES;[self refresh];NSAccessibilityPostNotification(_done,NSAccessibilityLayoutChangedNotification);}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return (NSInteger)_folders.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {(void)tableView;(void)column;return SHRootCell(_folders[(NSUInteger)row],Text-20);}
- (void)spotlight:(NSButton *)sender {
 BOOL saved=[_hotKey replaceSpotlight:sender.state==NSControlStateValueOn];[self refresh];
 if(!saved){_shortcuts.stringValue=NSLocalizedString(@"macOS did not save the Spotlight shortcut. Change it in Keyboard Settings….",@"Keyboard Settings… is the button title");[self layout];}
}
- (void)add:(id)sender {(void)sender;SHChooseFolders(self.window,_library,nil);}
- (void)search:(id)sender {(void)sender;[self.window close];if(self.openSearch)self.openSearch();}
@end
