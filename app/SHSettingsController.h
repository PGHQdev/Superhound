#import <AppKit/AppKit.h>
#import "SHLibrary.h"
#import "SHHotKey.h"
// The label, button, search location row, and folder selection that Settings shares with the Welcome window.
NSTextField *SHLabel(NSView *view,NSString *text,NSRect frame,CGFloat size,BOOL secondary);
NSButton *SHButton(NSView *view,NSString *title,NSRect frame,id target,SEL action);
// A search location's path, and its state with the item count, in a row 49 points high.
NSView *SHRootCell(NSDictionary *root,CGFloat width);
// The folder selection window as a sheet; the chosen folders become search locations, or one folder replaces the location with the identifier replacing.
void SHChooseFolders(NSWindow *window,SHLibrary *library,NSString *replacing);
// A button that shows a shortcut and records new keys after a click. Both app shortcuts stop while it records, so their keys reach it too.
// Esc cancels; a click or another window ends the recording. changed runs after each recording.
@interface SHShortcutButton : NSButton
- (instancetype)initWithFrame:(NSRect)frame hotKey:(SHHotKey *)hotKey;
@property(nonatomic,copy) void (^changed)(void);
// Shows the saved keys, unless a recording runs.
- (void)showKeys;
@end
@interface SHSettingsController : NSWindowController
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey historyKey:(SHHotKey *)historyKey;
- (void)updateRoots:(NSArray<NSDictionary *> *)roots message:(NSString *)message;
- (void)show;
@end
