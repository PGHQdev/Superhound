#import <AppKit/AppKit.h>
#import "SHQueryController.h"
#import "SHUsage.h"
#import "SHEmoji.h"
@interface SHSearchPanelController : NSWindowController
@property(nonatomic,copy) void (^openResult)(NSDictionary *,BOOL reveal);
@property(nonatomic,strong) SHUsage *usage;
@property(nonatomic,strong) SHEmoji *emoji;
- (instancetype)initWithQueries:(SHQueryController *)queries;
- (void)toggle;
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status;
- (void)showError:(NSString *)error;
@end
