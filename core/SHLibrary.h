#import <Foundation/Foundation.h>
#import "SHSearchSnapshot.h"
@interface SHLibrary : NSObject
@property(nonatomic,copy) void (^updated)(SHSearchSnapshot *snapshot,NSArray<NSDictionary *> *roots,NSString *message);
@property(nonatomic,readonly) NSURL *stateURL;
- (instancetype)initWithStateURL:(NSURL *)url;
- (void)start;
- (void)addURLs:(NSArray<NSURL *> *)urls replacingRoot:(NSString *)rootID;
- (void)removeRoot:(NSString *)rootID;
- (void)refresh;
- (void)setExcludeGenerated:(BOOL)exclude;
@end
