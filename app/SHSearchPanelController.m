#import "SHSearchPanelController.h"
#import "SHMetrics.h"
#import "SHAnswer.h"
#import <Quartz/Quartz.h>
NSString *const SHOwnCopyType=@"com.superhound.copy";
static NSString *Copied(NSDictionary *result){
 static NSRelativeDateTimeFormatter *format;if(!format){format=NSRelativeDateTimeFormatter.new;format.unitsStyle=NSRelativeDateTimeFormatterUnitsStyleShort;}
 NSString *when=[format localizedStringForDate:[NSDate dateWithTimeIntervalSince1970:[result[@"date"] doubleValue]] relativeToDate:NSDate.date];
 return [NSString stringWithFormat:@"%@%@ · Return to paste",[result[@"source"] length]?[result[@"source"] stringByAppendingString:@" · "]:@"",when];
}
static void Copy(NSString *text){NSPasteboard *board=NSPasteboard.generalPasteboard;[board clearContents];[board setString:text forType:NSPasteboardTypeString];[board setString:@"" forType:SHOwnCopyType];}
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
 NSTextField *_status,*_help;
 NSArray<NSDictionary *> *_results;
 NSRunningApplication *_previous;
 BOOL _navigated,_reloading,_pending,_history;
 id _selectedID;
 NSString *_coverage,*_error;
 NSCache *_icons;
 NSMutableSet *_loadingIcons;
 dispatch_queue_t _iconQueue;
 NSURL *_preview;
 NSButton *_unlicensed,*_updateLink;
 CGFloat _markLeft;
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
 _help=[NSTextField labelWithString:@""];_help.frame=NSMakeRect(22,14,456,18);_help.font=[NSFont systemFontOfSize:11];_help.textColor=NSColor.secondaryLabelColor;[view addSubview:_help];
 NSMutableParagraphStyle *right=NSMutableParagraphStyle.new;right.alignment=NSTextAlignmentRight;
 NSTextField *mark=[NSTextField labelWithAttributedString:[[NSAttributedString alloc] initWithString:@"SUPERHOUND" attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],NSKernAttributeName:@2,NSForegroundColorAttributeName:NSColor.tertiaryLabelColor,NSParagraphStyleAttributeName:right}]];mark.frame=NSMakeRect(478,14,140,18);mark.accessibilityElement=NO;[view addSubview:mark];
 NSButton *unlicensed=_unlicensed=[NSButton buttonWithTitle:@"" target:self action:@selector(enterLicense:)];unlicensed.bordered=NO;unlicensed.attributedTitle=[[NSAttributedString alloc] initWithString:@"Activate license" attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
 _markLeft=618-ceil(mark.attributedStringValue.size.width);unlicensed.toolTip=@"Enter your license key, or buy a license.";unlicensed.accessibilityLabel=@"Activate license";[view addSubview:unlicensed];
 _updateLink=[NSButton buttonWithTitle:@"" target:self action:@selector(openUpdate:)];_updateLink.bordered=NO;_updateLink.hidden=YES;[view addSubview:_updateLink];
 [self layoutFooter];
 return self;
}
// The links sit right to left from the wordmark; the key help takes the rest of the line, without ⌘↩ when both links show.
- (void)layoutFooter {
 CGFloat left=_markLeft;for(NSButton *link in @[_unlicensed,_updateLink])if(!link.hidden){CGFloat width=ceil(link.attributedTitle.size.width);left-=14+width;link.frame=NSMakeRect(left,14,width,18);}
 _help.frame=NSMakeRect(22,14,left-30,18);
 NSString *full=_history?@"↑ ↓ Move    ↩ Paste    ⌘↩ Copy    ⌘K Actions    Esc Close":@"↑ ↓ Move    ↩ Open    ⌘↩ Reveal in Finder    ⌘K Actions    Esc Close";
 _help.stringValue=[full sizeWithAttributes:@{NSFontAttributeName:_help.font}].width<=NSWidth(_help.frame)?full:_history?@"↑ ↓ Move    ↩ Paste    ⌘K Actions    Esc Close":@"↑ ↓ Move    ↩ Open    ⌘K Actions    Esc Close";
}
- (void)setLicensed:(BOOL)licensed {_licensed=licensed;_unlicensed.hidden=licensed;[self layoutFooter];}
- (void)setUpdate:(NSString *)update {
 _update=[update copy];_updateLink.hidden=!update;
 if(update){_updateLink.attributedTitle=[[NSAttributedString alloc] initWithString:[@"UPDATE TO " stringByAppendingString:update] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],NSKernAttributeName:@2,NSForegroundColorAttributeName:NSColor.controlAccentColor}];_updateLink.toolTip=[NSString stringWithFormat:@"Superhound %@ is available. Click to install it.",update];_updateLink.accessibilityLabel=_updateLink.toolTip;}
 [self layoutFooter];
}
- (void)openUpdate:(id)sender {(void)sender;[self dismiss:NO];if(self.installUpdate)self.installUpdate();}
- (void)buy:(id)sender {(void)sender;[self dismiss:NO];[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://superhound.app/buy"]];}
- (void)enterLicense:(id)sender {(void)sender;[self dismiss:NO];if(self.enterLicense)self.enterLicense();}
- (void)toggle {[self show:NO];}
- (void)toggleHistory {[self show:YES];}
// The other shortcut switches the open panel to its mode and keeps the app to return to.
- (void)show:(BOOL)history {
 double activated=SHTime();BOOL open=self.window.isVisible && (self.window.isKeyWindow || self.window.attachedSheet);
 if(open && _history==history){[self dismiss:YES];return;}
 if(!open)_previous=NSWorkspace.sharedWorkspace.frontmostApplication;
 if(_history!=history){_history=history;_field.stringValue=@"";_error=nil;[_queries cancel];}
 _field.placeholderString=history?@"Search clipboard history":@"Search apps and files";_field.accessibilityLabel=history?@"Search clipboard history":@"Search apps and selected folders";
 [self layoutFooter];
 NSScreen *screen=NSScreen.mainScreen?:NSScreen.screens.firstObject;
 NSPoint mouse=NSEvent.mouseLocation;for(NSScreen *candidate in NSScreen.screens)if(NSPointInRect(mouse,candidate.frame)){screen=candidate;break;}
 NSRect frame=screen.visibleFrame;[self.window setFrameOrigin:NSMakePoint(NSMidX(frame)-320,NSMaxY(frame)-MIN(frame.size.height-20,100+516))];
 [NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self.window makeFirstResponder:_field];
 [_field selectText:nil];[self search:YES];SHMeasure(@"panel_activation",activated);
 if(!open && !_licensed)[self remind];
}
// Every tenth opening asks for a license. Return does nothing, so a fast Return press cannot open the purchase page.
- (void)remind {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;NSInteger opens=[d integerForKey:@"unlicensedOpens"]+1;[d setInteger:opens forKey:@"unlicensedOpens"];if(opens%10)return;
 NSAlert *alert=NSAlert.new;alert.messageText=@"Superhound is unlicensed";alert.informativeText=@"All features keep working. A license is a one-time payment and covers 3 Macs.";
 NSButton *buy=[alert addButtonWithTitle:@"Buy License"];buy.keyEquivalent=@"";NSButton *later=[alert addButtonWithTitle:@"Not Now"];later.keyEquivalent=@"\e";
 [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){if(response==NSAlertFirstButtonReturn)[self buy:nil];else [self.window makeFirstResponder:self->_field];}];
}
- (void)dismiss:(BOOL)restore {
 [_queries cancel];if(self.window.attachedSheet)[self.window endSheet:self.window.attachedSheet];[self.window orderOut:nil];_error=nil;
 if(QLPreviewPanel.sharedPreviewPanelExists && QLPreviewPanel.sharedPreviewPanel.isVisible)[QLPreviewPanel.sharedPreviewPanel orderOut:nil];
 if(restore && _previous && _previous.processIdentifier!=NSProcessInfo.processInfo.processIdentifier)[_previous activateWithOptions:0];
}
- (void)windowDidResignKey:(NSNotification *)notification {(void)notification;if(self.window.isVisible && !(QLPreviewPanel.sharedPreviewPanelExists && QLPreviewPanel.sharedPreviewPanel.isVisible))[self dismiss:NO];}
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status {
 _coverage=status;BOOL changed=_queries.snapshot!=snapshot;
 if(changed)_queries.snapshot=snapshot;
 if(self.window.isVisible){if(changed && !_history)[self search:NO];else [self updateStatus];}
}
// The error stays in the status line until the query changes; a search that is still in progress does not replace it.
- (void)showError:(NSString *)error {_error=error;if(!self.window.isVisible)[self show:_history];_status.stringValue=error;NSAccessibilityPostNotification(_status,NSAccessibilityValueChangedNotification);}
- (void)updateStatus {
 if(_error){_status.stringValue=_error;return;}
 if(_history){_status.stringValue=!_clipboard.count?@"The clipboard history is empty. Text you copy in any app comes here.":_results.count?[NSString stringWithFormat:@"%lu copied items · Kept on this Mac only",(unsigned long)_clipboard.count]:@"No matches in the clipboard history.";return;}
 NSString *prompt=_field.stringValue.length?(_results.count?@"":@"No matches. "):@"Type to search files. ";
 _status.stringValue=[prompt stringByAppendingString:_coverage?:@""];
}
- (void)controlTextDidChange:(NSNotification *)notification {(void)notification;_error=nil;[self search:YES];}
- (void)search:(BOOL)changedQuery {
 double requested=SHTime();
 _pending=YES;
 if(changedQuery){_navigated=NO;_selectedID=nil;}
 if(_history){_pending=NO;[self present:[_clipboard search:_field.stringValue limit:100]];return;}
 // The previous rows stay visible until the new results arrive; _pending stops Return opening them.
 __weak typeof(self) weak=self;NSDictionary *answer=[SHAnswer answerForQuery:_field.stringValue];
 NSArray<NSDictionary *> *preferred=[_usage preferredForQuery:_field.stringValue],*emoji=[_emoji search:_field.stringValue limit:8];
 // Shorter queries would match too much copied text.
 NSArray<NSDictionary *> *clips=[_field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length>=3?[_clipboard search:_field.stringValue limit:2]:@[];
 [_queries submit:_field.stringValue preferred:preferred completion:^(NSArray<NSDictionary *> *results){
  SHSearchPanelController *self=weak;if(!self || !self.window.isVisible || self->_history)return;
  // A calculation or conversion takes the first of the eight rows.
  // Order: answer, results the user chose before, applications, settings panes, and commands, up to 3 emoji, up to 2 clipboard items, then files and folders.
  NSMutableArray *rows=NSMutableArray.array,*otherEmoji=[emoji mutableCopy];if(answer)[rows addObject:answer];
  NSSet *chosen=[NSSet setWithArray:[preferred valueForKey:@"path"]];
  for(NSDictionary *p in preferred)for(NSDictionary *e in emoji)if([e[@"path"] isEqual:p[@"path"]]){[rows addObject:e];[otherEmoji removeObjectIdenticalTo:e];}
  NSUInteger lead=0;while(lead<results.count && (SHLaunchable(results[lead]) || [chosen containsObject:results[lead][@"path"]]))lead++;
  NSUInteger shown=MIN((NSUInteger)3,otherEmoji.count);
  for(NSUInteger i=0;i<lead && rows.count+shown+clips.count<8;i++)[rows addObject:results[i]];
  for(NSUInteger i=0;i<shown;i++)[rows addObject:otherEmoji[i]];
  for(NSDictionary *clip in clips)if(rows.count<8)[rows addObject:clip];
  for(NSUInteger i=lead;i<results.count && rows.count<8;i++)[rows addObject:results[i]];
  // With few other results, more emoji fill the free rows.
  for(NSUInteger i=shown;i<otherEmoji.count && rows.count<8;i++)[rows addObject:otherEmoji[i]];
  self->_pending=NO;[self present:rows];
  if([NSUserDefaults.standardUserDefaults boolForKey:@"measurePerformance"])[self.window displayIfNeeded];
  SHMeasure(@"query_to_text_presentation",requested);
 }];
}
// Shows the rows and keeps the selection on the same item after the user moved it.
- (void)present:(NSArray<NSDictionary *> *)results {
 _results=results;NSInteger selection=-1;
 if(_navigated){for(NSUInteger i=0;i<results.count;i++)if([results[i][@"id"] isEqual:_selectedID]){selection=(NSInteger)i;break;}}
 else if(results.count)selection=0;
 _reloading=YES;[_table reloadData];
 if(selection>=0){[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selection] byExtendingSelection:NO];[_table scrollRowToVisible:selection];}else [_table deselectAll:nil];
 _reloading=NO;_selectedID=selection>=0?results[(NSUInteger)selection][@"id"]:nil;
 [self updateStatus];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return (NSInteger)_results.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
 (void)tableView;(void)column;
 NSDictionary *result=_results[(NSUInteger)row];NSString *path=result[@"path"];BOOL emoji=[result[@"type"] isEqual:@"emoji"],clip=[result[@"type"] isEqual:@"clipboard"],answer=emoji || clip || [result[@"type"] isEqual:@"answer"];
 NSTableCellView *cell=[[NSTableCellView alloc] initWithFrame:NSMakeRect(0,0,616,48)];
 NSImageView *icon=[[NSImageView alloc] initWithFrame:NSMakeRect(10,8,32,32)];icon.image=emoji?nil:clip?[NSImage imageWithSystemSymbolName:@"doc.on.clipboard" accessibilityDescription:nil]:answer?[NSImage imageWithSystemSymbolName:@"equal.circle" accessibilityDescription:nil]:result[@"symbol"]?[NSImage imageWithSystemSymbolName:result[@"symbol"] accessibilityDescription:nil]:[_icons objectForKey:path];icon.contentTintColor=NSColor.secondaryLabelColor;cell.imageView=icon;[cell addSubview:icon];
 if(emoji){NSTextField *glyph=[NSTextField labelWithString:result[@"emoji"]];glyph.frame=NSMakeRect(8,6,38,36);glyph.font=[NSFont systemFontOfSize:26];glyph.alignment=NSTextAlignmentCenter;[cell addSubview:glyph];}
 NSTextField *name=[NSTextField labelWithString:result[@"name"]];name.frame=NSMakeRect(54,24,550,21);name.font=[NSFont systemFontOfSize:15 weight:NSFontWeightMedium];name.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.textField=name;[cell addSubview:name];
 NSString *type=[@{@"app":@"Application",@"folder":@"Folder",@"link":@"Link",@"file":@"File"} objectForKey:result[@"type"]];
 NSTextField *detail=[NSTextField labelWithString:emoji?@"Emoji · Return to copy":clip?Copied(result):answer?[result[@"detail"] stringByAppendingString:@" · Return to copy"]:[result[@"type"] isEqual:@"settings"]?@"System Settings":[result[@"type"] isEqual:@"command"]?@"Command":[NSString stringWithFormat:@"%@ · %@",[path.stringByDeletingLastPathComponent stringByAbbreviatingWithTildeInPath],type]];detail.frame=NSMakeRect(54,6,550,17);detail.font=[NSFont systemFontOfSize:11];detail.textColor=NSColor.secondaryLabelColor;detail.lineBreakMode=NSLineBreakByTruncatingMiddle;[cell addSubview:detail];cell.accessibilityLabel=[NSString stringWithFormat:@"%@, %@",result[@"name"],detail.stringValue];
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
static BOOL Located(NSDictionary *result){return ![@[@"command",@"emoji",@"answer",@"clipboard"] containsObject:result[@"type"]];}
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
 add(Located(result)?@"Open":[type isEqual:@"command"]?@"Run":[type isEqual:@"clipboard"]?@"Paste":@"Copy",@"open",@"\r",0);
 if([type isEqual:@"clipboard"]){add(@"Copy",@"reveal",@"\r",NSEventModifierFlagCommand);[menu addItem:NSMenuItem.separatorItem];add(@"Delete from History",@"forget",@"",0);return;}
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
 // A clipboard item is copied again; Return also pastes it, and Command-Return only copies.
 if([result[@"type"] isEqual:@"clipboard"]){
  if([action isEqual:@"forget"]){NSUInteger i=[_results indexOfObjectIdenticalTo:result];NSDictionary *next=i==NSNotFound?nil:i+1<_results.count?_results[i+1]:i>0?_results[i-1]:nil;
   [_clipboard removeID:result[@"id"]];_navigated=next!=nil;_selectedID=next[@"id"];[self search:NO];return;}
  Copy(result[@"copy"]);[self dismiss:YES];if([action isEqual:@"open"] && self.openResult)self.openResult(result,@"paste",nil);return;
 }
 if([action isEqual:@"quickLook"]){[self quickLook:result];return;}
 if([action isEqual:@"copyPath"]){Copy(result[@"path"]);[self dismiss:YES];return;}
 // The row goes at once; the library removes the entry when FSEvents reports the change.
 if([action isEqual:@"trash"]){
  // A right-click can act on a row other than the selected one; the selection stays on its item.
  NSInteger removed=(NSInteger)[_results indexOfObjectIdenticalTo:result],row=_table.selectedRow;
  NSMutableArray *rows=[_results mutableCopy];[rows removeObjectIdenticalTo:result];_results=rows;row=row==removed?MIN(row,(NSInteger)rows.count-1):row>removed?row-1:row;
  _reloading=YES;[_table reloadData];if(row>=0)[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];else [_table deselectAll:nil];_reloading=NO;
  _selectedID=row>=0?rows[(NSUInteger)row][@"id"]:nil;[self updateStatus];if(self.openResult)self.openResult(result,action,nil);return;
 }
 if([result[@"type"] isEqual:@"emoji"])[_usage recordQuery:_field.stringValue result:result];
 if(result[@"copy"]){Copy(result[@"copy"]);[self dismiss:YES];return;}
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
