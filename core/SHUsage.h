#import <Foundation/Foundation.h>
// Remembers which result was opened for which query. Main thread only.
@interface SHUsage : NSObject
- (instancetype)initWithURL:(NSURL *)url;
- (void)recordQuery:(NSString *)query result:(NSDictionary *)result;
// Results opened before for this query or a related one, best first, at most 8.
- (NSArray<NSDictionary *> *)preferredForQuery:(NSString *)query;
@end
