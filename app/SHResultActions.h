#import <AppKit/AppKit.h>
@interface SHResultActions : NSObject
+ (void)open:(NSDictionary *)result reveal:(BOOL)reveal completion:(void (^)(NSString *error))completion;
@end
