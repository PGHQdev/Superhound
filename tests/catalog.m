#import <Foundation/Foundation.h>
#import "SHCatalog.h"
#import "SHScanner.h"
#import "SHFolderAccess.h"
#import <sqlite3.h>
#include <assert.h>
#include <sys/wait.h>
static void Write(NSURL *root, NSString *path) {
 NSURL *u=[root URLByAppendingPathComponent:path];
 [NSFileManager.defaultManager createDirectoryAtURL:u.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
 assert([[@"fixture" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:u atomically:YES]);
}
int main(void){@autoreleasepool{
 NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtURL:tmp withIntermediateDirectories:YES attributes:nil error:nil];
 NSURL *root=[tmp URLByAppendingPathComponent:@"tree"];
 Write(root,@"normal/東京.txt");Write(root,@"node_modules/ignored.txt");Write(root,@"node_modules-ok/visible.txt");Write(root,@".hidden/no.txt");Write(root,@"Demo.app/Contents/no.txt");
 assert([fm createSymbolicLinkAtPath:[[root URLByAppendingPathComponent:@"loop"] path] withDestinationPath:root.path error:nil]);
 assert([fm createSymbolicLinkAtPath:[[root URLByAppendingPathComponent:@"Linked.app"] path] withDestinationPath:[[root URLByAppendingPathComponent:@"Demo.app"] path] error:nil]);
 NSError *error=nil;
 NSArray *scan=[SHScanner scanURL:root applicationsOnly:NO excludeGenerated:YES progress:nil error:&error];
 assert(scan && !error);NSArray *paths=[scan valueForKey:@"relative"];
 assert([paths containsObject:@"normal/東京.txt"]);assert([paths containsObject:@"node_modules-ok/visible.txt"]);
 assert(![paths containsObject:@"node_modules/ignored.txt"]);assert(![paths containsObject:@".hidden/no.txt"]);
 assert(![paths containsObject:@"Demo.app/Contents/no.txt"]);assert([paths containsObject:@"loop"]);
 NSArray *linked=[SHScanner scanURL:root applicationsOnly:YES excludeGenerated:YES progress:nil error:&error];
 assert(([[NSSet setWithArray:[linked valueForKey:@"relative"]] isEqual:[NSSet setWithArray:@[@"Demo.app",@"Linked.app"]]]));assert(([[NSSet setWithArray:[linked valueForKey:@"type"]] isEqual:[NSSet setWithObject:@"app"]]));
 NSArray *all=[SHScanner scanURL:root applicationsOnly:NO excludeGenerated:NO progress:nil error:&error];
 assert([[all valueForKey:@"relative"] containsObject:@"node_modules/ignored.txt"]);
 assert(![SHScanner scanURL:[tmp URLByAppendingPathComponent:@"missing"] applicationsOnly:NO excludeGenerated:YES progress:nil error:&error]);
 NSArray *filtered=[SHScanner scanURL:root applicationsOnly:NO excludeGenerated:YES excludingURLs:@[[root URLByAppendingPathComponent:@"normal"]] cancelled:nil progress:nil error:&error];
 assert(![[filtered valueForKey:@"relative"] containsObject:@"normal/東京.txt"]);
 NSUInteger __block visits=0;
 error=nil;
 assert(![SHScanner scanURL:root applicationsOnly:NO excludeGenerated:YES cancelled:^BOOL{return ++visits>2;} progress:nil error:&error]);
 assert(error.code==NSUserCancelledError);
 NSURL *db=[tmp URLByAppendingPathComponent:@"catalog.sqlite"];
 SHCatalog *c=[[SHCatalog alloc] initWithURL:db error:&error];assert(c);
 assert([c replaceRoot:@"r" entries:scan error:&error]);NSArray *before=[c entriesForRoot:@"r"];
 assert(before.count==scan.count);assert([c replaceRoot:@"r" entries:scan error:&error]);
 assert([[before valueForKey:@"id"] isEqual:[[c entriesForRoot:@"r"] valueForKey:@"id"]]);
 // Duplicate rows fail atomically; the previous generation survives.
 assert((![c replaceRoot:@"r" entries:@[scan[0],scan[0]] error:&error]));
 assert([[before valueForKey:@"id"] isEqual:[[c entriesForRoot:@"r"] valueForKey:@"id"]]);
 // Directory updates: identical rows count as no change, shallow keeps deeper rows, deep removes them, other directories stay.
 NSDictionary *(^E)(NSString *)=^(NSString *rel){return @{@"relative":rel,@"name":rel.lastPathComponent,@"path":[root.URLByResolvingSymlinksInPath.path stringByAppendingPathComponent:rel],@"type":@"file",@"alias":@""};};
 NSUInteger changed=1;NSArray *top=[scan filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT relative CONTAINS '/'"]],*normal=[scan filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"relative BEGINSWITH 'normal/'"]];
 assert(([c updateRoot:@"r" directories:@[@{@"relative":@"",@"deep":@NO,@"entries":top},@{@"relative":@"normal",@"deep":@NO,@"entries":normal}] changed:&changed error:&error] && changed==0));
 assert([[before valueForKey:@"id"] isEqual:[[c entriesForRoot:@"r"] valueForKey:@"id"]]);
 assert(([c updateRoot:@"r" directories:@[@{@"relative":@"normal",@"deep":@YES,@"entries":@[E(@"normal/sub"),E(@"normal/sub/deep.txt")]}] changed:&changed error:&error] && changed==3));
 assert(([c updateRoot:@"r" directories:@[@{@"relative":@"normal",@"deep":@NO,@"entries":@[E(@"normal/sub")]}] changed:&changed error:&error] && changed==0));
 assert([[[c entriesForRoot:@"r"] valueForKey:@"relative"] containsObject:@"normal/sub/deep.txt"]);
 assert(([c updateRoot:@"r" directories:@[@{@"relative":@"normal",@"deep":@YES,@"entries":@[]}] changed:&changed error:&error] && changed==2));
 assert([c entriesForRoot:@"r"].count==before.count-1 && ![[[c entriesForRoot:@"r"] valueForKey:@"relative"] containsObject:@"normal/東京.txt"]);
 assert([c replaceRoot:@"r" entries:scan error:&error] && [c entriesForRoot:@"r"].count==before.count);
 // A process interrupted inside a transaction leaves the committed root intact.
 c=nil;const char *dbPath=db.fileSystemRepresentation;pid_t child=fork();assert(child>=0);
 if(child==0){sqlite3 *crashDB=NULL;if(sqlite3_open(dbPath,&crashDB)!=SQLITE_OK)_exit(2);if(sqlite3_exec(crashDB,"BEGIN IMMEDIATE; DELETE FROM entries",NULL,NULL,NULL)!=SQLITE_OK)_exit(3);_exit(0);}
 int childStatus=0;waitpid(child,&childStatus,0);assert(WIFEXITED(childStatus) && WEXITSTATUS(childStatus)==0);
 c=[[SHCatalog alloc] initWithURL:db error:&error];assert(c);assert([c entriesForRoot:@"r"].count==before.count);
 [c removeRoot:@"r"];assert([c entriesForRoot:@"r"].count==0);
 c=nil;assert([[@"invalid sqlite" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:db atomically:YES]);
 c=[[SHCatalog alloc] initWithURL:db error:&error];assert(c && c.rebuilt);assert([c entriesForRoot:@"r"].count==0);
 assert([[fm contentsOfDirectoryAtPath:tmp.path error:nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'catalog.sqlite.diagnostic-'"]].count>0);
 c=nil;sqlite3 *future=NULL;assert(sqlite3_open(db.fileSystemRepresentation,&future)==SQLITE_OK);assert(sqlite3_exec(future,"PRAGMA user_version=99",NULL,NULL,NULL)==SQLITE_OK);sqlite3_close(future);
 c=[[SHCatalog alloc] initWithURL:db error:&error];assert(c && c.rebuilt);
 assert(![SHFolderAccess resolveBookmark:[NSData dataWithBytes:"bad" length:3] stale:NULL error:&error]);
 NSData *bookmark=[SHFolderAccess bookmarkForURL:root error:&error];assert(bookmark);
 NSURL *resolved=[SHFolderAccess resolveBookmark:bookmark stale:NULL error:&error];assert([resolved.URLByResolvingSymlinksInPath.path isEqual:root.URLByResolvingSymlinksInPath.path]);
 [fm removeItemAtURL:tmp error:nil];
 puts("PASS catalog: exclusions, symlinks, missing root, stable IDs, directory updates, atomic rollback, corrupt cache, bookmarks");
}return 0;}
