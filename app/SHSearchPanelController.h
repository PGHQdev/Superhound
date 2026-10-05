#import <AppKit/AppKit.h>
#import "SHQueryController.h"
#import "SHUsage.h"
@interface SHSearchPanelController : NSWindowController
@property(nonatomic,copy) void (^openResult)(NSDictionary *,BOOL reveal);
@property(nonatomic,strong) SHUsage *usage;
- (instancetype)initWithQueries:(SHQueryController *)queries;
- (void)toggle;
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status;
- (void)showError:(NSString *)error;
@end
