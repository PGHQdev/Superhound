#import <Foundation/Foundation.h>
#import "SHLibrary.h"
#include <assert.h>
#include <sys/stat.h>
static BOOL Until(BOOL (^check)(void),double seconds){NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!check() && deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];return check();}
static void Write(NSURL *root,NSString *path){NSURL *u=[root URLByAppendingPathComponent:path];[NSFileManager.defaultManager createDirectoryAtURL:u.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];assert([NSData.data writeToURL:u atomically:YES]);}
int main(void){@autoreleasepool{
 NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 NSURL *tree=[tmp URLByAppendingPathComponent:@"tree"],*state=[tmp URLByAppendingPathComponent:@"state"];
 Write(tree,@"normal/superhoundfixture.txt");Write(tree,@"node_modules/superhoundexcluded.txt");
 SHLibrary *library=[[SHLibrary alloc] initWithStateURL:state];
 __block SHSearchSnapshot *snapshot;__block NSArray *roots;
 library.updated=^(SHSearchSnapshot *s,NSArray *r,NSString *m){(void)m;snapshot=s;roots=r;};
 [library start];[library addURLs:@[tree] replacingRoot:nil];
 assert(Until(^BOOL{return [snapshot search:@"superhoundfixture" cancelled:nil].count==1;},30));
 __block NSString *rootID;for(NSDictionary *r in roots)if(![r[@"apps"] boolValue])rootID=r[@"id"];
 [library addURLs:@[[tree URLByAppendingPathComponent:@"node_modules"]] replacingRoot:nil];
 // Explicitly selected excluded descendants must be independently searchable.
 assert(Until(^BOOL{return [snapshot search:@"superhoundexcluded" cancelled:nil].count==1;},15));
 Write(tree,@"normal/superhoundfresh.txt");
 assert(Until(^BOOL{return [snapshot search:@"superhoundfresh" cancelled:nil].count==1;},15));
 [NSFileManager.defaultManager moveItemAtURL:[tree URLByAppendingPathComponent:@"normal/superhoundfresh.txt"] toURL:[tree URLByAppendingPathComponent:@"normal/superhoundrenamed.txt"] error:nil];
 assert(Until(^BOOL{return [snapshot search:@"superhoundrenamed" cancelled:nil].count==1 && ![snapshot search:@"superhoundfresh" cancelled:nil].count;},15));
 [library addURLs:@[[tree URLByAppendingPathComponent:@"normal"]] replacingRoot:nil];
 assert(Until(^BOOL{for(NSDictionary *r in roots)if([r[@"state"] hasPrefix:@"Covered by"] && [r[@"path"] hasSuffix:@"/normal"])return YES;return NO;},15));
 assert(chmod(tree.fileSystemRepresentation,0100)==0);
 assert(Until(^BOOL{for(NSDictionary *r in roots)if([r[@"path"] hasSuffix:@"/normal"] && [r[@"state"] isEqual:@"Ready"])return YES;return NO;},15));
 assert([snapshot search:@"superhoundfixture" cancelled:nil].count==1);
 assert(chmod(tree.fileSystemRepresentation,0700)==0);
 // Remove the separately selected child before testing root identity replacement.
 for(NSDictionary *r in roots)if([r[@"path"] hasSuffix:@"/normal"])[library removeRoot:r[@"id"]];
 [library refresh];
 assert(Until(^BOOL{for(NSDictionary *r in roots)if([r[@"id"] isEqual:rootID] && [r[@"state"] isEqual:@"Ready"])return YES;return NO;},15));
 id oldID=[snapshot search:@"superhoundfixture" cancelled:nil].firstObject[@"id"];
 NSURL *other=[tmp URLByAppendingPathComponent:@"other"];Write(other,@"normal/superhoundfixture.txt");
 [library addURLs:@[other] replacingRoot:rootID];
 assert(Until(^BOOL{return [[snapshot search:@"superhoundfixture" cancelled:nil].firstObject[@"path"] containsString:@"/other/"];},15));
 assert(![[snapshot search:@"superhoundfixture" cancelled:nil].firstObject[@"id"] isEqual:oldID]);
 [library removeRoot:rootID];
 assert(![snapshot search:@"superhoundfixture" cancelled:nil].count); // revocation is immediate, before queued work
 assert(Until(^BOOL{return ![snapshot search:@"superhoundfixture" cancelled:nil].count;},15));
 assert([NSFileManager.defaultManager fileExistsAtPath:[other URLByAppendingPathComponent:@"normal/superhoundfixture.txt"].path]);
 [library addURLs:@[other] replacingRoot:nil];
 assert(Until(^BOOL{return [snapshot search:@"superhoundfixture" cancelled:nil].count==1;},15));
 library.updated=nil;library=nil;snapshot=nil;
 library=[[SHLibrary alloc] initWithStateURL:state];
 library.updated=^(SHSearchSnapshot *s,NSArray *r,NSString *m){(void)m;snapshot=s;roots=r;};[library start];
 assert(Until(^BOOL{return [snapshot search:@"superhoundfixture" cancelled:nil].count==1;},15));
 library.updated=nil;library=nil;
 [NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
 puts("PASS library: selected exclusions, FSEvents create/rename, replacement identity, root removal preserves files");
}return 0;}
