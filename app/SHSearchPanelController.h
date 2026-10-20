#import <AppKit/AppKit.h>
#import "SHQueryController.h"
#import "SHUsage.h"
#import "SHEmoji.h"
#import "SHClipboard.h"
// A pasteboard type on each copy Superhound makes, so the clipboard history can name Superhound as the source.
extern NSString *const SHOwnCopyType;
@interface SHSearchPanelController : NSWindowController
// action: open, reveal, openWith, or trash; see SHResultActions.
@property(nonatomic,copy) void (^openResult)(NSDictionary *result,NSString *action,NSURL *application);
@property(nonatomic,strong) SHUsage *usage;
@property(nonatomic,strong) SHEmoji *emoji;
@property(nonatomic,strong) SHClipboard *clipboard;
// NO shows the UNLICENSED link and the reminder on every tenth opening.
@property(nonatomic) BOOL licensed;
// A newer version shows an UPDATE TO link in the footer; installUpdate runs when the user clicks it.
@property(nonatomic,copy) NSString *update;
@property(nonatomic,copy) void (^installUpdate)(void);
- (instancetype)initWithQueries:(SHQueryController *)queries;
- (void)toggle;
// Shows the panel with the clipboard history only; Return pastes into the app that was in front.
- (void)toggleHistory;
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status;
- (void)showError:(NSString *)error;
@end
