#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
NSString *SHFold(NSString *text);
// Applications, settings panes, and commands: results that rank above files and lead the panel rows.
BOOL SHLaunchable(NSDictionary *entry);
// The rest of name after typed when typed starts name, ignoring case, accents, and width; "" when they are equal; nil otherwise.
NSString *_Nullable SHCompletion(NSString *name,NSString *typed);
@interface SHSearchSnapshot : NSObject
@property(nonatomic,readonly) uint64_t generation;
@property(nonatomic,readonly) NSUInteger count;
- (nullable instancetype)initWithEntries:(NSArray<NSDictionary *> *)entries generation:(uint64_t)generation;
- (SHSearchSnapshot *)snapshotByExcludingRoots:(NSSet<NSString *> *)roots;
- (NSArray<NSDictionary *> *)search:(NSString *)query cancelled:(BOOL (^_Nullable)(void))cancelled;
// preferred lists results the user opened before (name, path, and "same" for the exact query), best first; matching ones lead the results.
- (NSArray<NSDictionary *> *)search:(NSString *)query preferred:(nullable NSArray<NSDictionary *> *)preferred cancelled:(BOOL (^_Nullable)(void))cancelled;
@end
NS_ASSUME_NONNULL_END
