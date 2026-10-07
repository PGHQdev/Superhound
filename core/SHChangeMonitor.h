#import <Foundation/Foundation.h>
@interface SHChangeMonitor : NSObject
// listed: directories whose direct children changed. walked: directories that were created, removed, or renamed, so their contents need a full walk. Both nil when the whole location needs a rescan.
- (instancetype)initWithURL:(NSURL *)url excludingURLs:(NSArray<NSURL *> *)ignored changed:(void (^)(BOOL invalidated,NSSet<NSString *> *listed,NSSet<NSString *> *walked))changed;
- (void)stop;
@end
