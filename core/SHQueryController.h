#import "SHSearchSnapshot.h"
@interface SHQueryController : NSObject
@property(nonatomic,strong) SHSearchSnapshot *snapshot; // Set on main thread; built on catalog queue.
- (void)submit:(NSString *)query preferred:(NSArray<NSDictionary *> *)preferred completion:(void (^)(NSArray<NSDictionary *> *))completion;
- (void)cancel;
@end
