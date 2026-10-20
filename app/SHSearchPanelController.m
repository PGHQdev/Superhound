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
// The panel keeps its top edge; its height follows the rows up to eight rows.
// Shared columns: a 16-point margin, a 28-point icon column, text from x 52, and the same right margin; the selection spans x 8 to Width-8.
static const CGFloat Width=600,Top=56,Band=26,Bottom=49,MaxRows=8*48,Text=Width-16-44-32;
static NSImage *Mask(CGFloat radius){NSImage *mask=[NSImage imageWithSize:NSMakeSize(2*radius+1,2*radius+1) flipped:NO drawingHandler:^BOOL(NSRect rect){[NSColor.blackColor set];[[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];return YES;}];mask.capInsets=NSEdgeInsetsMake(radius,radius,radius,radius);mask.resizingMode=NSImageResizingModeStretch;return mask;}
// The parent folder's last two names, or more until they differ from each other result with the same name.
static NSString *Context(NSDictionary *result,NSArray<NSDictionary *> *results){
 NSArray<NSString *> *parts=[result[@"path"] stringByDeletingLastPathComponent].stringByAbbreviatingWithTildeInPath.pathComponents;NSUInteger take=MIN((NSUInteger)2,parts.count);
 for(NSDictionary *other in results)if(other!=result && [other[@"name"] caseInsensitiveCompare:result[@"name"]]==NSOrderedSame){NSArray *o=[other[@"path"] stringByDeletingLastPathComponent].stringByAbbreviatingWithTildeInPath.pathComponents;
  while(take<parts.count && [[parts subarrayWithRange:NSMakeRange(parts.count-take,take)] isEqual:o.count>=take?[o subarrayWithRange:NSMakeRange(o.count-take,take)]:o])take++;}
 NSArray<NSString *> *shown=[parts subarrayWithRange:NSMakeRange(parts.count-take,take)];
 return [shown.firstObject isEqual:@"/"]?[@"/" stringByAppendingString:[[shown subarrayWithRange:NSMakeRange(1,shown.count-1)] componentsJoinedByString:@" / "]]:[shown componentsJoinedByString:@" / "];
}
// Each query word's first match in the name is semibold; the middle truncation keeps the extension.
static NSAttributedString *Marked(NSString *name,NSString *query){
 NSMutableParagraphStyle *style=NSMutableParagraphStyle.new;style.lineBreakMode=NSLineBreakByTruncatingMiddle;
 NSMutableAttributedString *text=[[NSMutableAttributedString alloc] initWithString:name attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:14],NSForegroundColorAttributeName:NSColor.labelColor,NSParagraphStyleAttributeName:style}];
 for(NSString *term in [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet])if(term.length){NSRange range=[name rangeOfString:term options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch];if(range.location!=NSNotFound)[text addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14 weight:NSFontWeightSemibold] range:range];}
 return text;
}
static NSString *Count(NSUInteger count){return [NSNumberFormatter localizedStringFromNumber:@(count) numberStyle:NSNumberFormatterDecimalStyle];}
// Key and name pairs: 5 points inside a pair, 18 between pairs.
static NSAttributedString *Hints(NSArray<NSString *> *parts){
 NSMutableAttributedString *text=NSMutableAttributedString.new;
 for(NSUInteger i=0;i<parts.count;i++){BOOL key=i%2==0;[text appendAttributedString:[[NSAttributedString alloc] initWithString:parts[i] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:key?NSFontWeightMedium:NSFontWeightRegular],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}]];
  if(i+1<parts.count)[text addAttribute:NSKernAttributeName value:key?@5:@18 range:[text.string rangeOfComposedCharacterSequenceAtIndex:text.length-1]];}
 return text;
}
// Footer items share one text baseline, whatever their control type.
static void Seat(NSView *view,CGFloat x,CGFloat width){NSSize size=view.fittingSize;view.frame=NSMakeRect(x,0,width,size.height);[view setFrameOrigin:NSMakePoint(x,15-(size.height-view.firstBaselineOffsetFromTop))];}
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
// Keyboard selection is a stronger fill with the Return glyph; the pointer only adds a faint fill.
@interface SHRowView : NSTableRowView
@end
@implementation SHRowView {NSTrackingArea *_area;BOOL _hovered;}
- (void)updateTrackingAreas {[super updateTrackingAreas];if(_area)[self removeTrackingArea:_area];_area=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:nil];[self addTrackingArea:_area];}
- (void)mouseEntered:(NSEvent *)event {(void)event;_hovered=YES;self.needsDisplay=YES;}
- (void)mouseExited:(NSEvent *)event {(void)event;_hovered=NO;self.needsDisplay=YES;}
- (NSBackgroundStyle)interiorBackgroundStyle {return NSBackgroundStyleNormal;}
- (void)drawBackgroundInRect:(NSRect)rect {(void)rect;if(!_hovered || self.selected)return;[[NSColor colorWithWhite:1 alpha:0.06] set];[[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8] fill];}
- (void)drawSelectionInRect:(NSRect)rect {
 (void)rect;[[NSColor colorWithWhite:1 alpha:0.16] set];[[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8] fill];
 NSDictionary *glyph=@{NSFontAttributeName:[NSFont systemFontOfSize:13],NSForegroundColorAttributeName:NSColor.secondaryLabelColor};NSSize size=[@"↩" sizeWithAttributes:glyph];[@"↩" drawAtPoint:NSMakePoint(NSWidth(self.bounds)-8-size.width,(NSHeight(self.bounds)-size.height)/2) withAttributes:glyph];
}
@end
@interface SHSearchPanelController () <NSTextFieldDelegate,NSTableViewDataSource,NSTableViewDelegate,NSWindowDelegate,NSMenuDelegate,QLPreviewPanelDataSource>
@end
@implementation SHSearchPanelController {
 SHQueryController *_queries;
 NSTextField *_field;
 NSTableView *_table;
 NSTextField *_help,*_section,*_note,*_brand;
 NSImageView *_logo;
 NSScrollView *_scroll;
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
 NSView *_tint;
 CGFloat _top,_floor;
}
- (instancetype)initWithQueries:(SHQueryController *)queries {
 SHPanel *panel=[[SHPanel alloc] initWithContentRect:NSMakeRect(0,0,Width,Top+MaxRows+Bottom) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
 if(!(self=[super initWithWindow:panel]))return nil;
 _queries=queries;_results=@[];_coverage=@"Preparing search";_icons=NSCache.new;_icons.countLimit=128;_loadingIcons=NSMutableSet.set;_iconQueue=dispatch_queue_create("com.superhound.icons",DISPATCH_QUEUE_SERIAL);
 panel.title=@"Superhound";panel.level=NSFloatingWindowLevel;panel.hidesOnDeactivate=NO;panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;panel.delegate=self;panel.releasedWhenClosed=NO;
 panel.opaque=NO;panel.backgroundColor=NSColor.clearColor;panel.hasShadow=YES;panel.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];panel.accessibilityIdentifier=@"superhound.search.panel";
 // A dark blur with a charcoal tint keeps strong wallpaper colors out; the tint carries the one border.
 NSVisualEffectView *view=[[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0,0,Width,Top+MaxRows+Bottom)];view.material=NSVisualEffectMaterialHUDWindow;view.blendingMode=NSVisualEffectBlendingModeBehindWindow;view.state=NSVisualEffectStateActive;view.maskImage=Mask(12);panel.contentView=view;
 _tint=[[NSView alloc] initWithFrame:view.bounds];_tint.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;_tint.wantsLayer=YES;_tint.layer.cornerRadius=12;_tint.layer.borderWidth=1;_tint.layer.borderColor=[NSColor colorWithWhite:1 alpha:0.12].CGColor;[view addSubview:_tint];[self applyTransparency];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(applyTransparency) name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification object:nil];
 // The system search bezel has a fixed height that clips 22-point text, so the field draws no bezel.
 NSImageView *glass=[NSImageView imageViewWithImage:[[NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightRegular]]];glass.frame=NSMakeRect(16,Bottom+MaxRows+12,28,32);glass.autoresizingMask=NSViewMinYMargin;glass.contentTintColor=NSColor.secondaryLabelColor;[view addSubview:glass];
 _field=[[NSTextField alloc] initWithFrame:NSMakeRect(52,Bottom+MaxRows+12,Width-68,32)];_field.autoresizingMask=NSViewMinYMargin;_field.bordered=NO;_field.drawsBackground=NO;_field.focusRingType=NSFocusRingTypeNone;_field.usesSingleLineMode=YES;_field.cell.scrollable=YES;_field.font=[NSFont systemFontOfSize:22];_field.delegate=self;_field.accessibilityIdentifier=@"superhound.search.input";_field.accessibilityLabel=@"Search apps and selected folders";[view addSubview:_field];
 _section=[NSTextField labelWithString:@""];_section.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];_section.textColor=NSColor.secondaryLabelColor;_section.lineBreakMode=NSLineBreakByTruncatingTail;_section.accessibilityIdentifier=@"superhound.search.status";[view addSubview:_section];
 _note=[NSTextField labelWithString:@""];_note.font=[NSFont systemFontOfSize:12];_note.textColor=NSColor.tertiaryLabelColor;_note.alignment=NSTextAlignmentRight;_note.lineBreakMode=NSLineBreakByTruncatingHead;[view addSubview:_note];
 NSScrollView *scroll=_scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(8,Bottom,Width-16,MaxRows)];scroll.hasVerticalScroller=NO;scroll.drawsBackground=NO;
 _table=[[SHResultsTable alloc] initWithFrame:scroll.bounds];
 __weak typeof(self) weak=self;
 panel.shortcut=^BOOL(NSEvent *event){return [weak shortcut:event];};
 ((SHResultsTable *)_table).command=^BOOL(NSEvent *event){if(event.keyCode==53){[weak dismiss:YES];return YES;}if(event.keyCode==36 || event.keyCode==76){[weak openSelected:(event.modifierFlags&NSEventModifierFlagCommand)!=0];return YES;}return NO;};_table.headerView=nil;_table.style=NSTableViewStylePlain;_table.intercellSpacing=NSMakeSize(0,0);_table.backgroundColor=NSColor.clearColor;_table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleRegular;_table.delegate=self;_table.dataSource=self;_table.allowsEmptySelection=YES;_table.target=self;_table.doubleAction=@selector(openClicked:);_table.menu=NSMenu.new;_table.menu.delegate=self;_table.accessibilityIdentifier=@"superhound.search.results";_table.accessibilityLabel=@"Search results";
 NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"result"];column.width=Width-16;[_table addTableColumn:column];scroll.documentView=_table;[view addSubview:scroll];
 NSView *rule=[[NSView alloc] initWithFrame:NSMakeRect(16,40,Width-32,1)];rule.wantsLayer=YES;rule.layer.backgroundColor=[NSColor colorWithWhite:1 alpha:0.1].CGColor;[view addSubview:rule];
 _help=[NSTextField labelWithString:@""];_help.lineBreakMode=NSLineBreakByClipping;[view addSubview:_help];
 _logo=[NSImageView imageViewWithImage:[NSBundle.mainBundle imageForResource:@"LogoTemplate"]?:NSImage.new];_logo.image.template=YES;_logo.imageScaling=NSImageScaleProportionallyUpOrDown;_logo.contentTintColor=NSColor.secondaryLabelColor;_logo.accessibilityElement=NO;[view addSubview:_logo];
 _brand=[NSTextField labelWithString:@"Superhound"];_brand.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];_brand.textColor=NSColor.secondaryLabelColor;_brand.accessibilityElement=NO;[view addSubview:_brand];
 NSButton *unlicensed=_unlicensed=[NSButton buttonWithTitle:@"" target:self action:@selector(enterLicense:)];unlicensed.bordered=NO;unlicensed.attributedTitle=[[NSAttributedString alloc] initWithString:@"Activate license" attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
 unlicensed.toolTip=@"Enter your license key, or buy a license.";unlicensed.accessibilityLabel=@"Activate license";[view addSubview:unlicensed];
 _updateLink=[NSButton buttonWithTitle:@"" target:self action:@selector(openUpdate:)];_updateLink.bordered=NO;_updateLink.hidden=YES;[view addSubview:_updateLink];
 [self layoutFooter];
 return self;
}
// Reduce Transparency gets an opaque charcoal panel.
- (void)applyTransparency {_tint.layer.backgroundColor=(NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency?[NSColor colorWithWhite:0.13 alpha:1]:[NSColor colorWithWhite:0 alpha:0.35]).CGColor;}
// Apps, settings panes, and commands take one line; files and the rest take two.
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {(void)tableView;return row<(NSInteger)_results.count && SHLaunchable(_results[(NSUInteger)row])?40:48;}
- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {(void)tableView;(void)row;return SHRowView.new;}
- (CGFloat)fittingHeight {CGFloat rows=0;for(NSInteger i=0;i<_table.numberOfRows;i++)rows+=[self tableView:_table heightOfRow:i];return MIN(Top+(_section.hidden?0:Band)+MIN(rows,MaxRows)+Bottom,_top-_floor);}
// The label band and the rows follow the current height at once, also while a shrink waits.
- (void)place {
 CGFloat height=NSHeight(self.window.frame),band=_section.hidden?0:Band,note=_note.stringValue.length?MIN(ceil(_note.fittingSize.width),(Width-32)/2):0;
 _note.frame=NSMakeRect(Width-16-note,height-Top-band+5,note,16);_section.frame=NSMakeRect(16,height-Top-band+5,Width-32-note-(note?12:0),16);_scroll.frame=NSMakeRect(8,Bottom,Width-16,MAX(0,height-Top-band-Bottom));}
// A taller panel grows at once; a shorter one waits for results to settle, so fast typing does not make it jump.
- (void)fit {
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resize) object:nil];
 CGFloat height=self.fittingHeight;if(height>=NSHeight(self.window.frame) || !self.window.isVisible)[self resize];else {[self place];[self performSelector:@selector(resize) withObject:nil afterDelay:0.15];}
}
- (void)resize {if(!_top)return;NSRect frame=self.window.frame;CGFloat height=self.fittingHeight;if(height!=NSHeight(frame) || NSMaxY(frame)!=_top){[self.window setFrame:NSMakeRect(NSMinX(frame),_top-height,Width,height) display:YES];[self.window invalidateShadow];}[self place];}
// Right to left: the logo and name, Activate license, and Update to; the key hints take the rest and drop Close when they do not fit.
- (void)layoutFooter {
 CGFloat width=ceil(_brand.fittingSize.width),left=Width-16-width;Seat(_brand,left,width);left-=6+14;_logo.frame=NSMakeRect(left,12,14,14);
 for(NSButton *link in @[_unlicensed,_updateLink])if(!link.hidden){width=ceil(link.fittingSize.width);left-=18+width;Seat(link,left,width);}
 NSString *action=_history?@"Paste":@"Open";_help.attributedStringValue=Hints(@[@"↩",action,@"⌘K",@"Actions",@"Esc",@"Close"]);
 if(_help.fittingSize.width>left-18-16)_help.attributedStringValue=Hints(@[@"↩",action,@"⌘K",@"Actions"]);
 Seat(_help,16,left-18-16);
}
- (void)setLicensed:(BOOL)licensed {_licensed=licensed;_unlicensed.hidden=licensed;[self layoutFooter];}
- (void)setUpdate:(NSString *)update {
 _update=[update copy];_updateLink.hidden=!update;
 if(update){_updateLink.attributedTitle=[[NSAttributedString alloc] initWithString:[@"Update to " stringByAppendingString:update] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12],NSForegroundColorAttributeName:NSColor.controlAccentColor}];_updateLink.toolTip=[NSString stringWithFormat:@"Superhound %@ is available. Click to install it.",update];_updateLink.accessibilityLabel=_updateLink.toolTip;}
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
 _field.placeholderAttributedString=[[NSAttributedString alloc] initWithString:history?@"Search clipboard history":@"Search apps and files" attributes:@{NSFontAttributeName:_field.font,NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];_field.accessibilityLabel=history?@"Search clipboard history":@"Search apps and selected folders";
 [self layoutFooter];
 NSScreen *screen=NSScreen.mainScreen?:NSScreen.screens.firstObject;
 NSPoint mouse=NSEvent.mouseLocation;for(NSScreen *candidate in NSScreen.screens)if(NSPointInRect(mouse,candidate.frame)){screen=candidate;break;}
 NSRect frame=screen.visibleFrame;_top=NSMaxY(frame)-MAX(0,MIN(100,NSHeight(frame)-(Top+MaxRows+Bottom)-10));_floor=NSMinY(frame);[self.window setFrameOrigin:NSMakePoint(NSMidX(frame)-Width/2,NSMinY(self.window.frame))];[self resize];
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
- (void)showError:(NSString *)error {_error=error;if(!self.window.isVisible)[self show:_history];[self updateStatus];NSAccessibilityPostNotification(_section,NSAccessibilityValueChangedNotification);}
// The band above the rows names the list for an empty query, and otherwise shows only an error or no matches; the indexing note sits at its right.
- (void)updateStatus {
 BOOL empty=!_field.stringValue.length,none=!_results.count && !_pending;
 NSString *label=_error?:_history && !_clipboard.count?@"The clipboard history is empty":empty?(_history?@"Clipboard":@"Suggested"):none?@"No matches":nil;
 _section.hidden=_note.hidden=!label;_section.stringValue=label?:@"";_section.textColor=_error?NSColor.labelColor:NSColor.secondaryLabelColor;
 _note.stringValue=_error?@"":_history?(!_clipboard.count?@"Text you copy in any app comes here":empty?[NSString stringWithFormat:@"%@ %@ · Kept on this Mac only",Count(_clipboard.count),_clipboard.count==1?@"item":@"items"]:@""):_coverage?:@"";
 [self fit];
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
 NSDictionary *result=_results[(NSUInteger)row];NSString *path=result[@"path"],*kind=result[@"type"];BOOL emoji=[kind isEqual:@"emoji"],clip=[kind isEqual:@"clipboard"],answer=emoji || clip || [kind isEqual:@"answer"],compact=SHLaunchable(result),located=!answer && !compact;
 CGFloat height=compact?40:48;NSTableCellView *cell=[[NSTableCellView alloc] initWithFrame:NSMakeRect(0,0,Width-16,height)];
 // Every row has the same 28-point icon box; file icons scale with their proportions and symbols keep one size.
 NSString *symbol=emoji?nil:clip?@"doc.on.clipboard":answer?@"equal.circle":result[@"symbol"];
 NSImageView *icon=[[NSImageView alloc] initWithFrame:NSMakeRect(8,(height-28)/2,28,28)];icon.imageScaling=symbol?NSImageScaleNone:NSImageScaleProportionallyUpOrDown;icon.image=symbol?[[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:17 weight:NSFontWeightRegular]]:emoji?nil:[_icons objectForKey:path];icon.contentTintColor=NSColor.secondaryLabelColor;cell.imageView=icon;[cell addSubview:icon];
 if(emoji){NSTextField *glyph=[NSTextField labelWithString:result[@"emoji"]];glyph.frame=NSMakeRect(4,(height-30)/2,36,30);glyph.font=[NSFont systemFontOfSize:22];glyph.alignment=NSTextAlignmentCenter;[cell addSubview:glyph];}
 // An app shows its folder only when another result has the same name.
 BOOL shared=NO;for(NSDictionary *other in _results)if(other!=result && [other[@"name"] caseInsensitiveCompare:result[@"name"]]==NSOrderedSame)shared=YES;
 NSString *detail=emoji?@"Emoji · Return to copy":clip?Copied(result):answer?[result[@"detail"] stringByAppendingString:@" · Return to copy"]:[kind isEqual:@"settings"]?@"System Settings":[kind isEqual:@"command"]?@"Command":[kind isEqual:@"app"] && !shared?@"":Context(result,_results);
 NSTextField *name=[NSTextField labelWithAttributedString:Marked(result[@"name"],_field.stringValue)];cell.textField=name;[cell addSubview:name];
 NSTextField *info=[NSTextField labelWithString:detail];info.font=[NSFont systemFontOfSize:12];info.textColor=NSColor.secondaryLabelColor;info.lineBreakMode=located || [kind isEqual:@"app"]?NSLineBreakByTruncatingHead:NSLineBreakByTruncatingTail;[cell addSubview:info];
 if(compact){CGFloat width=detail.length?MIN(ceil(info.intrinsicContentSize.width),Text/2):0;name.frame=NSMakeRect(44,(height-18)/2,Text-width-(width?8:0),18);info.frame=NSMakeRect(44+Text-width,(height-16)/2,width,16);info.alignment=NSTextAlignmentRight;}
 else {name.frame=NSMakeRect(44,24,Text,18);info.frame=NSMakeRect(44,7,Text,16);}
 // VoiceOver still hears the kind that the row no longer prints.
 NSString *spoken=@{@"app":@"app",@"folder":@"folder",@"link":@"link",@"file":@"file"}[kind];cell.accessibilityLabel=[[@[result[@"name"],spoken?:@"",detail] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@", "];
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
 if([action isEqual:@"actions"]){NSMenu *menu=NSMenu.new;[self addActionsFor:result to:menu];NSRect row=[_table rectOfRow:_table.selectedRow];[menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMinX(row)+44,NSMaxY(row)) inView:_table];return YES;}
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
