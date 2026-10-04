#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
NSString *SHFold(NSString *text);
@interface SHSearchSnapshot : NSObject
@property(nonatomic,readonly) uint64_t generation;
@property(nonatomic,readonly) NSUInteger count;
- (nullable instancetype)initWithEntries:(NSArray<NSDictionary *> *)entries generation:(uint64_t)generation;
- (SHSearchSnapshot *)snapshotByExcludingRoots:(NSSet<NSString *> *)roots;
- (NSArray<NSDictionary *> *)search:(NSString *)query cancelled:(BOOL (^_Nullable)(void))cancelled;
@end
NS_ASSUME_NONNULL_END
