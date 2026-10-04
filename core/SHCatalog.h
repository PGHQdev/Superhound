#import <Foundation/Foundation.h>
@interface SHCatalog : NSObject
@property(nonatomic,readonly) BOOL rebuilt;
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (BOOL)replaceRoot:(NSString *)root entries:(NSArray<NSDictionary *> *)entries error:(NSError **)error;
- (NSArray<NSDictionary *> *)entriesForRoot:(NSString *)root;
- (void)removeRoot:(NSString *)root;
@end
