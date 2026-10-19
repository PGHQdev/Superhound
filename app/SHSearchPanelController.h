#import <AppKit/AppKit.h>
#import "SHQueryController.h"
#import "SHUsage.h"
#import "SHEmoji.h"
@interface SHSearchPanelController : NSWindowController
// action: open, reveal, openWith, or trash; see SHResultActions.
@property(nonatomic,copy) void (^openResult)(NSDictionary *result,NSString *action,NSURL *application);
@property(nonatomic,strong) SHUsage *usage;
@property(nonatomic,strong) SHEmoji *emoji;
- (instancetype)initWithQueries:(SHQueryController *)queries;
- (void)toggle;
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status;
- (void)showError:(NSString *)error;
@end
