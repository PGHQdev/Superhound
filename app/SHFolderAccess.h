#import <Foundation/Foundation.h>
@interface SHFolderAccess : NSObject
+ (NSData *)bookmarkForURL:(NSURL *)url error:(NSError **)error;
+ (NSURL *)resolveBookmark:(NSData *)data stale:(BOOL *)stale error:(NSError **)error;
@end
