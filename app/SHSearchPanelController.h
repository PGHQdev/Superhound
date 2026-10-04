#import <AppKit/AppKit.h>
#import "SHQueryController.h"
@interface SHSearchPanelController : NSWindowController
@property(nonatomic,copy) void (^openResult)(NSDictionary *,BOOL reveal);
- (instancetype)initWithQueries:(SHQueryController *)queries;
- (void)toggle;
- (void)updateSnapshot:(SHSearchSnapshot *)snapshot status:(NSString *)status;
- (void)showError:(NSString *)error;
@end
