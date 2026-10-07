#import <Foundation/Foundation.h>
@interface SHCatalog : NSObject
@property(nonatomic,readonly) BOOL rebuilt;
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (BOOL)replaceRoot:(NSString *)root entries:(NSArray<NSDictionary *> *)entries error:(NSError **)error;
// Each directory: relative (empty for the root), deep, entries. A shallow directory replaces its direct children; a deep one replaces everything beneath it. changed counts rows inserted, updated, or deleted.
- (BOOL)updateRoot:(NSString *)root directories:(NSArray<NSDictionary *> *)directories changed:(NSUInteger *)changed error:(NSError **)error;
- (NSArray<NSDictionary *> *)entriesForRoot:(NSString *)root;
- (void)removeRoot:(NSString *)root;
@end
