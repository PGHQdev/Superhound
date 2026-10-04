#import "SHFolderAccess.h"
@implementation SHFolderAccess
+ (NSData *)bookmarkForURL:(NSURL *)url error:(NSError **)error {
 return [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:error];
}
+ (NSURL *)resolveBookmark:(NSData *)data stale:(BOOL *)stale error:(NSError **)error {
 if(!data.length)return nil;
 return [NSURL URLByResolvingBookmarkData:data options:NSURLBookmarkResolutionWithoutUI|NSURLBookmarkResolutionWithoutMounting|NSURLBookmarkResolutionWithoutImplicitStartAccessing relativeToURL:nil bookmarkDataIsStale:stale error:error];
}
@end
