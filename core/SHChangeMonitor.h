#import <Foundation/Foundation.h>
@interface SHChangeMonitor : NSObject
- (instancetype)initWithURL:(NSURL *)url excludingURLs:(NSArray<NSURL *> *)ignored changed:(void (^)(BOOL invalidated))changed;
- (void)stop;
@end
