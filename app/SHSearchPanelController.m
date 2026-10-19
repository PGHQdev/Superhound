#import "SHSearchPanelController.h"
#import "SHMetrics.h"
#import "SHAnswer.h"
#import <Quartz/Quartz.h>
@interface SHPanel : NSPanel
@property(copy) BOOL (^shortcut)(NSEvent *);
@end
@implementation SHPanel
- (BOOL)canBecomeKeyWindow{return YES;}
- (BOOL)canBecomeMainWindow{return NO;}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
 if([self.firstResponder isKindOfClass:NSTextView.class] && [(NSTextView *)self.firstResponder hasMarkedText])return NO;
 return (self.shortcut && self.shortcut(event)) || [super performKeyEquivalent:event];
}
@end
@interface SHResultsTable : NSTableView
@property(copy) BOOL (^command)(NSEvent *);
@end
@implementation SHResultsTable
- (void)keyDown:(NSEvent *)event {if(!self.command || !self.command(event))[super keyDown:event];}
@end
@interface SHSearchPanelController () <NSTextFieldDelegate,NSTableViewDataSource,NSTableViewDelegate,NSWindowDelegate,NSMenuDelegate,QLPreviewPanelDataSource>
@end
@implementation SHSearchPanelController {
 SHQueryController *_queries;
 NSTextField *_field;
 NSTableView *_table;
 NSTextField *_status;
 NSArray<NSDictionary *> *_results;
 NSRunningApplication *_previous;
 BOOL _navigated,_reloading,_pending;
 id _selectedID;
 NSString *_coverage;
 NSCache *_icons;
 NSMutableSet *_loadingIcons;
 dispatch_queue_t _iconQueue;
 NSURL *_preview;
}
- (instancetype)initWithQueries:(SHQueryController *)queries {
 SHPanel *panel=[[SHPanel alloc] initWithContentRect:NSMakeRect(0,0,640,516) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:panel]))return nil;
 _queries=queries;_results=@[];_coverage=@"Preparing search…";_icons=NSCache.new;_icons.countLimit=128;_loadingIcons=NSMutableSet.set;_iconQueue=dispatch_queue_create("com.superhound.icons",DISPATCH_QUEUE_SERIAL);
 panel.title=@"Superhound";panel.titleVisibility=NSWindowTitleHidden;panel.titlebarAppearsTransparent=YES;panel.level=NSFloatingWindowLevel;panel.hidesOnDeactivate=NO;panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;panel.delegate=self;panel.releasedWhenClosed=NO;
 panel.backgroundColor=NSColor.windowBackgroundColor;panel.accessibilityIdentifier=@"superhound.search.panel";
 NSView *view=panel.contentView;
 // The system search bezel has a fixed height that clips 24-point text, so the field draws no bezel.
 NSImageView *glass=[NSImageView imageViewWithImage:[[NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightRegular]]];glass.frame=NSMakeRect(22,456,26,32);glass.contentTintColor=NSColor.secondaryLabelColor;[view addSubview:glass];
 _field=[[NSTextField alloc] initWithFrame:NSMakeRect(56,456,564,32)];_field.bordered=NO;_field.drawsBackground=NO;_field.focusRingType=NSFocusRingTypeNone;_field.usesSingleLineMode=YES;_field.cell.scrollable=YES;_field.font=[NSFont systemFontOfSize:24];_field.placeholderString=@"Search apps and files";_field.delegate=self;_field.accessibilityIdentifier=@"superhound.search.input";_field.accessibilityLabel=@"Search apps and selected folders";[view addSubview:_field];
 NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(12,62,616,384)];scroll.hasVerticalScroller=NO;scroll.drawsBackground=NO;
 _table=[[SHResultsTable alloc] initWithFrame:scroll.bounds];
 __weak typeof(self) weak=self;
 panel.shortcut=^BOOL(NSEvent *event){return [weak shortcut:event];};
 ((SHResultsTable *)_table).command=^BOOL(NSEvent *event){if(event.keyCode==53){[weak dismiss:YES];return YES;}if(event.keyCode==36 || event.keyCode==76){[weak openSelected:(event.modifierFlags&NSEventModifierFlagCommand)!=0];return YES;}return NO;};_table.headerView=nil;_table.rowHeight=48;_table.intercellSpacing=NSMakeSize(0,0);_table.backgroundColor=NSColor.clearColor;_table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleRegular;_table.delegate=self;_table.dataSource=self;_table.allowsEmptySelection=YES;_table.target=self;_table.doubleAction=@selector(openClicked:);_table.menu=NSMenu.new;_table.menu.delegate=self;_table.accessibilityIdentifier=@"superhound.search.results";_table.accessibilityLabel=@"Search results";
 NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"result"];column.width=616;[_table addTableColumn:column];scroll.documentView=_table;[view addSubview:scroll];
 _status=[NSTextField labelWithString:_coverage];_status.frame=NSMakeRect(22,37,596,20);_status.font=[NSFont systemFontOfSize:11];_status.textColor=NSColor.secondaryLabelColor;_status.lineBreakMode=NSLineBreakByTruncatingTail;_status.accessibilityIdentifier=@"superhound.search.status";[view addSubview:_status];
 NSTextField *help=[NSTextField labelWithString:@"↑ ↓ Move    ↩ Open    ⌘↩ Reveal in Finder    ⌘K Actions    Esc Close"];help.frame=NSMakeRect(22,14,456,18);help.font=[NSFont systemFontOfSize:11];help.textColor=NSColor.secondaryLabelColor;[view addSubview:help];
 NSMutableParagraphStyle *right=NSMutableParagraphStyle.new;right.alignment=NSTextAlignmentRight;
 NSTextField *mark=[NSTextField labelWithAttributedString:[[NSAttributedString alloc] initWithString:@"SUPERHOUND" attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],NSKernAttributeName:@2,NSForegroundColorAttributeName:NSColor.tertiaryLabelColor,NSParagraphStyleAttributeName:right}]];mark.frame=NSMakeRect(478,14,140,18);mark.accessibilityElement=NO;[view addSubview:mark];
 return self;
}
- (void)toggle {
 double activated=SHTime();
 if(self.window.isVisible && self.window.isKeyWindow){[self dismiss:YES];return;}
 _previous=NSWorkspace.sharedWorkspace.frontmostApplication;
 NSScreen *screen=NSScreen.mainScreen?:NSScreen.screens.firstObject;
 NSPoint mouse=NSEvent.mouseLocation;for(NSScreen *candidate in NSScreen.screens)if(NSPointInRect(mouse,candidate.frame)){screen=candidate;break;}
 NSRect frame=screen.visibleFrame;[self.window setFrameOrigin:NSMakePoint(NSMidX(frame)-320,NSMaxY(frame)-MIN(frame.size.height-20,100+516))];
 [NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self.window makeFirstResponder:_field];
 [_field selectText:nil];[self search:YES];SHMeasure(@"panel_activation",activated);
}
- (void)dismiss:(BOOL)restore {
 [_queries cancel];[self.window orderOut:nil];
 if(QLPreviewPanel.sharedPreviewPanelExists && QLPreviewPanel.sharedPreviewPanel.isVisible)[QLPreviewPanel.sharedPreviewPanel orderOut:nil];
 if(restore && _previous && _previous.processIdentifier!=NSProcessInfo.processInfo.processIdentifier)[_previous activateWithOptions:0];
}
- (void)windowDidResignKey:(NSNotification *)notification {(void)notification;if(self.window.isVisible && !(QLPreviewPanel.sharedPreviewPanelExists && QLPreviewPanel.sharedPreviewPanel.isVisible))[self dismiss:NO];}
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status {
 _coverage=status;BOOL changed=_queries.snapshot!=snapshot;
 if(changed)_queries.snapshot=snapshot;
 if(self.window.isVisible){if(changed)[self search:NO];else [self updateStatus];}
}
- (void)showError:(NSString *)error {if(!self.window.isVisible)[self toggle];_status.stringValue=error;NSAccessibilityPostNotification(_status,NSAccessibilityValueChangedNotification);}
- (void)updateStatus {
 NSString *prompt=_field.stringValue.length?(_results.count?@"":@"No matches. "):@"Type to search files. ";
 _status.stringValue=[prompt stringByAppendingString:_coverage?:@""];
}
- (void)controlTextDidChange:(NSNotification *)notification {(void)notification;[self search:YES];}
- (void)search:(BOOL)changedQuery {
 double requested=SHTime();
 _pending=YES;
 if(changedQuery){_navigated=NO;_selectedID=nil;}
 // The previous rows stay visible until the new results arrive; _pending stops Return opening them.
 __weak typeof(self) weak=self;NSDictionary *answer=[SHAnswer answerForQuery:_field.stringValue];
 NSArray<NSDictionary *> *preferred=[_usage preferredForQuery:_field.stringValue],*emoji=[_emoji search:_field.stringValue limit:8];
 [_queries submit:_field.stringValue preferred:preferred completion:^(NSArray<NSDictionary *> *results){
  SHSearchPanelController *self=weak;if(!self || !self.window.isVisible)return;
  // A calculation or conversion takes the first of the eight rows.
  // Order: answer, results the user chose before, applications, settings panes, and commands, up to 3 emoji, then files and folders.
  NSMutableArray *rows=NSMutableArray.array,*otherEmoji=[emoji mutableCopy];if(answer)[rows addObject:answer];
  NSSet *chosen=[NSSet setWithArray:[preferred valueForKey:@"path"]];
  for(NSDictionary *p in preferred)for(NSDictionary *e in emoji)if([e[@"path"] isEqual:p[@"path"]]){[rows addObject:e];[otherEmoji removeObjectIdenticalTo:e];}
  NSUInteger lead=0;while(lead<results.count && (SHLaunchable(results[lead]) || [chosen containsObject:results[lead][@"path"]]))lead++;
  NSUInteger shown=MIN((NSUInteger)3,otherEmoji.count);
  for(NSUInteger i=0;i<lead && rows.count+shown<8;i++)[rows addObject:results[i]];
  for(NSUInteger i=0;i<shown;i++)[rows addObject:otherEmoji[i]];
  for(NSUInteger i=lead;i<results.count && rows.count<8;i++)[rows addObject:results[i]];
  // With few other results, more emoji fill the free rows.
  for(NSUInteger i=shown;i<otherEmoji.count && rows.count<8;i++)[rows addObject:otherEmoji[i]];
  results=rows;
  self->_pending=NO;self->_results=results;NSInteger selection=-1;
  if(self->_navigated){for(NSUInteger i=0;i<results.count;i++)if([results[i][@"id"] isEqual:self->_selectedID]){selection=(NSInteger)i;break;}}
  else if(results.count)selection=0;
  self->_reloading=YES;[self->_table reloadData];
  if(selection>=0)[self->_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selection] byExtendingSelection:NO];else [self->_table deselectAll:nil];
  self->_reloading=NO;self->_selectedID=selection>=0?results[(NSUInteger)selection][@"id"]:nil;
  [self updateStatus];
  if([NSUserDefaults.standardUserDefaults boolForKey:@"measurePerformance"])[self.window displayIfNeeded];
  SHMeasure(@"query_to_text_presentation",requested);
 }];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return (NSInteger)_results.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
 (void)tableView;(void)column;
 NSDictionary *result=_results[(NSUInteger)row];NSString *path=result[@"path"];BOOL emoji=[result[@"type"] isEqual:@"emoji"],answer=emoji || [result[@"type"] isEqual:@"answer"];
 NSTableCellView *cell=[[NSTableCellView alloc] initWithFrame:NSMakeRect(0,0,616,48)];
 NSImageView *icon=[[NSImageView alloc] initWithFrame:NSMakeRect(10,8,32,32)];icon.image=emoji?nil:answer?[NSImage imageWithSystemSymbolName:@"equal.circle" accessibilityDescription:nil]:result[@"symbol"]?[NSImage imageWithSystemSymbolName:result[@"symbol"] accessibilityDescription:nil]:[_icons objectForKey:path];icon.contentTintColor=NSColor.secondaryLabelColor;cell.imageView=icon;[cell addSubview:icon];
 if(emoji){NSTextField *glyph=[NSTextField labelWithString:result[@"emoji"]];glyph.frame=NSMakeRect(8,6,38,36);glyph.font=[NSFont systemFontOfSize:26];glyph.alignment=NSTextAlignmentCenter;[cell addSubview:glyph];}
 NSTextField *name=[NSTextField labelWithString:result[@"name"]];name.frame=NSMakeRect(54,24,550,21);name.font=[NSFont systemFontOfSize:15 weight:NSFontWeightMedium];name.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.textField=name;[cell addSubview:name];
 NSString *type=[@{@"app":@"Application",@"folder":@"Folder",@"link":@"Link",@"file":@"File"} objectForKey:result[@"type"]];
 NSTextField *detail=[NSTextField labelWithString:emoji?@"Emoji · Return to copy":answer?[result[@"detail"] stringByAppendingString:@" · Return to copy"]:[result[@"type"] isEqual:@"settings"]?@"System Settings":[result[@"type"] isEqual:@"command"]?@"Command":[NSString stringWithFormat:@"%@ · %@",[path.stringByDeletingLastPathComponent stringByAbbreviatingWithTildeInPath],type]];detail.frame=NSMakeRect(54,6,550,17);detail.font=[NSFont systemFontOfSize:11];detail.textColor=NSColor.secondaryLabelColor;detail.lineBreakMode=NSLineBreakByTruncatingMiddle;[cell addSubview:detail];cell.accessibilityLabel=[NSString stringWithFormat:@"%@, %@",result[@"name"],detail.stringValue];
 if(!answer && !icon.image && ![_loadingIcons containsObject:path]){[_loadingIcons addObject:path];__weak typeof(self) weak=self;
  dispatch_async(_iconQueue,^{NSImage *image=[NSWorkspace.sharedWorkspace iconForFile:path];dispatch_async(dispatch_get_main_queue(),^{SHSearchPanelController *self=weak;if(!self)return;[self->_loadingIcons removeObject:path];if(image)[self->_icons setObject:image forKey:path];for(NSUInteger i=0;i<self->_results.count;i++)if([self->_results[i][@"path"] isEqual:path]){NSTableCellView *visible=[self->_table viewAtColumn:0 row:(NSInteger)i makeIfNecessary:NO];visible.imageView.image=image;}});});
 }
 return cell;
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {(void)notification;if(_reloading)return;_navigated=YES;NSInteger row=_table.selectedRow;_selectedID=row>=0?_results[(NSUInteger)row][@"id"]:nil;}
- (void)move:(NSInteger)delta {
 _navigated=YES;NSInteger row=_table.selectedRow;
 if(!_results.count)return;
 row=row<0?(delta>0?0:(NSInteger)_results.count-1):MAX(0,MIN((NSInteger)_results.count-1,row+delta));
 [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];[_table scrollRowToVisible:row];_selectedID=_results[(NSUInteger)row][@"id"];
}
- (void)openClicked:(id)sender {(void)sender;[self openSelected:NO];}
- (NSDictionary *)selected {NSInteger row=_table.selectedRow;return !_pending && row>=0 && row<(NSInteger)_results.count?_results[(NSUInteger)row]:nil;}
- (void)openSelected:(BOOL)reveal {NSDictionary *result=self.selected;if(result)[self perform:reveal?@"reveal":@"open" result:result application:nil];else NSBeep();}
// ⌘↩ reveal, ⌘K actions, ⌘Y Quick Look, ⇧⌘C copy path.
- (BOOL)shortcut:(NSEvent *)event {
 NSEventModifierFlags flags=event.modifierFlags&NSEventModifierFlagDeviceIndependentFlagsMask&~(NSEventModifierFlagCapsLock|NSEventModifierFlagNumericPad|NSEventModifierFlagFunction);NSString *key=event.charactersIgnoringModifiers.lowercaseString;
 if((event.keyCode==36 || event.keyCode==76) && (flags&NSEventModifierFlagCommand)){[self openSelected:YES];return YES;}
 NSString *action=flags==NSEventModifierFlagCommand?@{@"k":@"actions",@"y":@"quickLook"}[key]:flags==(NSEventModifierFlagCommand|NSEventModifierFlagShift) && [key isEqual:@"c"]?@"copyPath":nil;
 if(!action)return NO;
 NSDictionary *result=self.selected;if(!result){NSBeep();return YES;}
 if([action isEqual:@"actions"]){NSMenu *menu=NSMenu.new;[self addActionsFor:result to:menu];NSRect row=[_table rectOfRow:_table.selectedRow];[menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMinX(row)+54,NSMaxY(row)) inView:_table];return YES;}
 if([self action:action appliesTo:result])[self perform:action result:result application:nil];else NSBeep();
 return YES;
}
static BOOL Located(NSDictionary *result){return ![@[@"command",@"emoji",@"answer"] containsObject:result[@"type"]];}
- (BOOL)action:(NSString *)action appliesTo:(NSDictionary *)result {
 if([action isEqual:@"quickLook"])return Located(result) && ![result[@"type"] isEqual:@"settings"];
 if([action isEqual:@"copyPath"])return Located(result);
 return YES;
}
// Items for the ⌘K menu and the row's context menu. Each item carries its result, so a right-clicked row needs no selection.
- (void)addActionsFor:(NSDictionary *)result to:(NSMenu *)menu {
 NSMenuItem *(^add)(NSString *,NSString *,NSString *,NSEventModifierFlags)=^NSMenuItem *(NSString *title,NSString *action,NSString *key,NSEventModifierFlags flags){
  NSMenuItem *item=[menu addItemWithTitle:title action:@selector(chooseAction:) keyEquivalent:key];item.keyEquivalentModifierMask=flags;item.target=self;item.representedObject=@{@"result":result,@"action":action};return item;};
 NSString *type=result[@"type"];
 add(Located(result)?@"Open":[type isEqual:@"command"]?@"Run":@"Copy",@"open",@"\r",0);
 if(!Located(result))return;
 add(@"Reveal in Finder",@"reveal",@"\r",NSEventModifierFlagCommand);
 if([self action:@"quickLook" appliesTo:result])add(@"Quick Look",@"quickLook",@"y",NSEventModifierFlagCommand);
 NSURL *url=[NSURL fileURLWithPath:result[@"path"]];
 if([@[@"file",@"folder",@"link"] containsObject:type]){
  NSMenu *apps=NSMenu.new;NSURL *preferred=[NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:url];
  NSMutableArray *candidates=[[NSWorkspace.sharedWorkspace URLsForApplicationsToOpenURL:url] mutableCopy];if(preferred){[candidates removeObject:preferred];[candidates insertObject:preferred atIndex:0];}
  for(NSURL *app in candidates){NSString *name=[NSFileManager.defaultManager displayNameAtPath:app.path].stringByDeletingPathExtension;
   NSMenuItem *item=[apps addItemWithTitle:[app isEqual:preferred]?[name stringByAppendingString:@" (default)"]:name action:@selector(chooseAction:) keyEquivalent:@""];item.target=self;item.representedObject=@{@"result":result,@"action":@"openWith",@"application":app};
   NSImage *icon=[NSWorkspace.sharedWorkspace iconForFile:app.path];icon.size=NSMakeSize(16,16);item.image=icon;
   if([app isEqual:preferred] && candidates.count>1)[apps addItem:NSMenuItem.separatorItem];}
  if(apps.numberOfItems){NSMenuItem *openWith=[menu addItemWithTitle:@"Open With" action:nil keyEquivalent:@""];openWith.submenu=apps;}
 }
 add(@"Copy Path",@"copyPath",@"c",NSEventModifierFlagCommand|NSEventModifierFlagShift);
 if(![type isEqual:@"settings"] && [NSFileManager.defaultManager isDeletableFileAtPath:url.path]){[menu addItem:NSMenuItem.separatorItem];add(@"Move to Trash",@"trash",@"",0);}
}
- (void)menuNeedsUpdate:(NSMenu *)menu {[menu removeAllItems];NSInteger row=_table.clickedRow;if(!_pending && row>=0 && row<(NSInteger)_results.count)[self addActionsFor:_results[(NSUInteger)row] to:menu];}
- (void)chooseAction:(NSMenuItem *)item {NSDictionary *choice=item.representedObject;[self perform:choice[@"action"] result:choice[@"result"] application:choice[@"application"]];}
- (void)perform:(NSString *)action result:(NSDictionary *)result application:(NSURL *)application {
 if([action isEqual:@"quickLook"]){[self quickLook:result];return;}
 if([action isEqual:@"copyPath"]){[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:result[@"path"] forType:NSPasteboardTypeString];[self dismiss:YES];return;}
 // The row goes at once; the library removes the entry when FSEvents reports the change.
 if([action isEqual:@"trash"]){
  // A right-click can act on a row other than the selected one; the selection stays on its item.
  NSInteger removed=(NSInteger)[_results indexOfObjectIdenticalTo:result],row=_table.selectedRow;
  NSMutableArray *rows=[_results mutableCopy];[rows removeObjectIdenticalTo:result];_results=rows;row=row==removed?MIN(row,(NSInteger)rows.count-1):row>removed?row-1:row;
  _reloading=YES;[_table reloadData];if(row>=0)[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];else [_table deselectAll:nil];_reloading=NO;
  _selectedID=row>=0?rows[(NSUInteger)row][@"id"]:nil;[self updateStatus];if(self.openResult)self.openResult(result,action,nil);return;
 }
 if([result[@"type"] isEqual:@"emoji"])[_usage recordQuery:_field.stringValue result:result];
 if(result[@"copy"]){[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:result[@"copy"] forType:NSPasteboardTypeString];[self dismiss:YES];return;}
 [_usage recordQuery:_field.stringValue result:result];[self dismiss:[result[@"type"] isEqual:@"command"]];if(self.openResult)self.openResult(result,action,application);
}
- (void)quickLook:(NSDictionary *)result {
 QLPreviewPanel *panel=QLPreviewPanel.sharedPreviewPanel;
 if(panel.isVisible && [_preview isEqual:[NSURL fileURLWithPath:result[@"path"]]]){[panel orderOut:nil];return;}
 _preview=[NSURL fileURLWithPath:result[@"path"]];if(panel.isVisible)[panel reloadData];else [panel makeKeyAndOrderFront:nil];
}
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {(void)panel;return YES;}
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {panel.dataSource=self;panel.level=self.window.level+1;}
// The search panel takes the keyboard again, or closes when another app became active during the preview.
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {panel.dataSource=nil;dispatch_async(dispatch_get_main_queue(),^{if(!self.window.isVisible || self.window.isKeyWindow)return;if(NSApp.isActive)[self.window makeKeyWindow];else [self dismiss:NO];});}
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {(void)panel;return _preview?1:0;}
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {(void)panel;(void)index;return _preview;}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
 (void)control;if(textView.hasMarkedText)return NO;
 if(selector==@selector(moveDown:)){[self move:1];return YES;}
 if(selector==@selector(moveUp:)){[self move:-1];return YES;}
 if(selector==@selector(cancelOperation:)){[self dismiss:YES];return YES;}
 if(selector==@selector(insertNewline:) || selector==@selector(insertNewlineIgnoringFieldEditor:)){[self openSelected:(NSApp.currentEvent.modifierFlags&NSEventModifierFlagCommand)!=0];return YES;}
 return NO;
}
@end
