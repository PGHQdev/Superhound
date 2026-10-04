#import "SHSearchPanelController.h"
#import "SHMetrics.h"
@interface SHPanel : NSPanel
@property(copy) void (^revealSelected)(void);
@end
@implementation SHPanel
- (BOOL)canBecomeKeyWindow{return YES;}
- (BOOL)canBecomeMainWindow{return NO;}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
 if((event.keyCode==36 || event.keyCode==76) && (event.modifierFlags&NSEventModifierFlagCommand)){
  if([self.firstResponder isKindOfClass:NSTextView.class] && [(NSTextView *)self.firstResponder hasMarkedText])return NO;
  if(self.revealSelected)self.revealSelected();return YES;
 }
 return [super performKeyEquivalent:event];
}
@end
@interface SHResultsTable : NSTableView
@property(copy) BOOL (^command)(NSEvent *);
@end
@implementation SHResultsTable
- (void)keyDown:(NSEvent *)event {if(!self.command || !self.command(event))[super keyDown:event];}
@end
@interface SHSearchPanelController () <NSSearchFieldDelegate,NSTableViewDataSource,NSTableViewDelegate,NSWindowDelegate>
@end
@implementation SHSearchPanelController {
 SHQueryController *_queries;
 NSSearchField *_field;
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
}
- (instancetype)initWithQueries:(SHQueryController *)queries {
 SHPanel *panel=[[SHPanel alloc] initWithContentRect:NSMakeRect(0,0,640,516) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:panel]))return nil;
 _queries=queries;_results=@[];_coverage=@"Preparing search…";_icons=NSCache.new;_icons.countLimit=128;_loadingIcons=NSMutableSet.set;_iconQueue=dispatch_queue_create("com.superhound.icons",DISPATCH_QUEUE_SERIAL);
 panel.title=@"Superhound";panel.titleVisibility=NSWindowTitleHidden;panel.titlebarAppearsTransparent=YES;panel.level=NSFloatingWindowLevel;panel.hidesOnDeactivate=NO;panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;panel.delegate=self;panel.releasedWhenClosed=NO;
 panel.backgroundColor=NSColor.windowBackgroundColor;panel.accessibilityIdentifier=@"superhound.search.panel";
 NSView *view=panel.contentView;
 _field=[[NSSearchField alloc] initWithFrame:NSMakeRect(20,452,600,40)];_field.font=[NSFont systemFontOfSize:24];_field.placeholderString=@"Search apps and files";_field.delegate=self;_field.sendsSearchStringImmediately=YES;_field.accessibilityIdentifier=@"superhound.search.input";_field.accessibilityLabel=@"Search apps and selected folders";[view addSubview:_field];
 NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(12,62,616,384)];scroll.hasVerticalScroller=NO;scroll.drawsBackground=NO;
 _table=[[SHResultsTable alloc] initWithFrame:scroll.bounds];
 __weak typeof(self) weak=self;
 panel.revealSelected=^{[weak openSelected:YES];};
 ((SHResultsTable *)_table).command=^BOOL(NSEvent *event){if(event.keyCode==53){[weak dismiss:YES];return YES;}if(event.keyCode==36 || event.keyCode==76){[weak openSelected:(event.modifierFlags&NSEventModifierFlagCommand)!=0];return YES;}return NO;};_table.headerView=nil;_table.rowHeight=48;_table.intercellSpacing=NSMakeSize(0,0);_table.backgroundColor=NSColor.clearColor;_table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleRegular;_table.delegate=self;_table.dataSource=self;_table.allowsEmptySelection=YES;_table.target=self;_table.doubleAction=@selector(openClicked:);_table.accessibilityIdentifier=@"superhound.search.results";_table.accessibilityLabel=@"Search results";
 NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"result"];column.width=616;[_table addTableColumn:column];scroll.documentView=_table;[view addSubview:scroll];
 _status=[NSTextField labelWithString:_coverage];_status.frame=NSMakeRect(22,37,596,20);_status.font=[NSFont systemFontOfSize:11];_status.textColor=NSColor.secondaryLabelColor;_status.lineBreakMode=NSLineBreakByTruncatingTail;_status.accessibilityIdentifier=@"superhound.search.status";[view addSubview:_status];
 NSTextField *help=[NSTextField labelWithString:@"↑ ↓ Move     ↩ Open     ⌘↩ Reveal in Finder     Esc Close"];help.frame=NSMakeRect(22,14,596,18);help.font=[NSFont systemFontOfSize:11];help.textColor=NSColor.secondaryLabelColor;[view addSubview:help];
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
 if(restore && _previous && _previous.processIdentifier!=NSProcessInfo.processInfo.processIdentifier)[_previous activateWithOptions:0];
}
- (void)windowDidResignKey:(NSNotification *)notification {(void)notification;if(self.window.isVisible)[self dismiss:NO];}
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
 // Clear obsolete query results immediately so Return cannot open the previous query.
 if(changedQuery){_results=@[];_reloading=YES;[_table reloadData];[_table deselectAll:nil];_reloading=NO;}
 __weak typeof(self) weak=self;
 [_queries submit:_field.stringValue completion:^(NSArray<NSDictionary *> *results){
  SHSearchPanelController *self=weak;if(!self || !self.window.isVisible)return;
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
 NSDictionary *result=_results[(NSUInteger)row];NSString *path=result[@"path"];
 NSTableCellView *cell=[[NSTableCellView alloc] initWithFrame:NSMakeRect(0,0,616,48)];
 NSImageView *icon=[[NSImageView alloc] initWithFrame:NSMakeRect(10,8,32,32)];icon.image=[_icons objectForKey:path];cell.imageView=icon;[cell addSubview:icon];
 NSTextField *name=[NSTextField labelWithString:result[@"name"]];name.frame=NSMakeRect(54,24,550,21);name.font=[NSFont systemFontOfSize:15 weight:NSFontWeightMedium];name.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.textField=name;[cell addSubview:name];
 NSString *type=[@{@"app":@"Application",@"folder":@"Folder",@"link":@"Link",@"file":@"File"} objectForKey:result[@"type"]];
 NSTextField *detail=[NSTextField labelWithString:[NSString stringWithFormat:@"%@ · %@",[path.stringByDeletingLastPathComponent stringByAbbreviatingWithTildeInPath],type]];detail.frame=NSMakeRect(54,6,550,17);detail.font=[NSFont systemFontOfSize:11];detail.textColor=NSColor.secondaryLabelColor;detail.lineBreakMode=NSLineBreakByTruncatingMiddle;[cell addSubview:detail];cell.accessibilityLabel=[NSString stringWithFormat:@"%@, %@",result[@"name"],detail.stringValue];
 if(!icon.image && ![_loadingIcons containsObject:path]){[_loadingIcons addObject:path];__weak typeof(self) weak=self;
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
- (void)openSelected:(BOOL)reveal {
 if(_pending){NSBeep();return;}
 NSInteger row=_table.selectedRow;if(row<0 || row>=(NSInteger)_results.count){NSBeep();return;}
 NSDictionary *result=_results[(NSUInteger)row];[self dismiss:NO];if(self.openResult)self.openResult(result,reveal);
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
 (void)control;if(textView.hasMarkedText)return NO;
 if(selector==@selector(moveDown:)){[self move:1];return YES;}
 if(selector==@selector(moveUp:)){[self move:-1];return YES;}
 if(selector==@selector(cancelOperation:)){[self dismiss:YES];return YES;}
 if(selector==@selector(insertNewline:) || selector==@selector(insertNewlineIgnoringFieldEditor:)){[self openSelected:(NSApp.currentEvent.modifierFlags&NSEventModifierFlagCommand)!=0];return YES;}
 return NO;
}
@end
