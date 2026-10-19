#import <Foundation/Foundation.h>
#import "SHClipboard.h"
#include <assert.h>
#include <sys/stat.h>
static NSArray *Texts(SHClipboard *c,NSString *q){return [[c search:q limit:500] valueForKey:@"copy"];}
int main(void){@autoreleasepool{
 NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 assert([NSFileManager.defaultManager createDirectoryAtURL:tmp withIntermediateDirectories:YES attributes:nil error:nil]);
 NSURL *file=[tmp URLByAppendingPathComponent:@"clipboard.plist"];
 SHClipboard *c=[[SHClipboard alloc] initWithURL:file];assert(c.count==0 && [c search:@"" limit:8].count==0);
 NSArray *text=@[@"public.utf8-plain-text"];
 assert([c addText:@"first copy" types:text application:@"com.apple.TextEdit" source:@"TextEdit"]);
 assert([c addText:@"  Café résumé\nsecond line" types:text application:nil source:nil]);
 assert([Texts(c,@"") isEqual:(@[@"  Café résumé\nsecond line",@"first copy"])]);
 // Search ignores case and accents; every word must be in the text.
 assert([Texts(c,@"CAFE") isEqual:@[@"  Café résumé\nsecond line"]]);assert([Texts(c,@"resume line") isEqual:@[@"  Café résumé\nsecond line"]]);
 assert([Texts(c,@"copy") isEqual:@[@"first copy"]]);assert(Texts(c,@"copy zzqq").count==0);
 NSDictionary *top=[c search:@"" limit:1].firstObject;
 assert([top[@"type"] isEqual:@"clipboard"] && [top[@"name"] isEqual:@"Café résumé"] && [top[@"path"] hasPrefix:@"clipboard:"] && [top[@"id"] isEqual:top[@"path"]] && [top[@"source"] isEqual:@""]);
 assert([[c search:@"first" limit:1].firstObject[@"source"] isEqual:@"TextEdit"]);
 // The same text copied again moves to the top, once.
 assert([c addText:@"first copy" types:text application:nil source:nil]);assert([Texts(c,@"") isEqual:(@[@"first copy",@"  Café résumé\nsecond line"])]);
 // Rejected copies.
 assert(![c addText:@"" types:text application:nil source:nil]);assert(![c addText:@" \n\t" types:text application:nil source:nil]);assert(![c addText:nil types:text application:nil source:nil]);
 assert((![c addText:@"hunter2" types:@[@"public.utf8-plain-text",@"org.nspasteboard.ConcealedType"] application:nil source:nil]));
 assert(![c addText:@"one-time" types:@[@"org.nspasteboard.TransientType"] application:nil source:nil]);
 assert(![c addText:@"secret" types:text application:@"com.apple.Passwords" source:@"Passwords"]);assert(![c addText:@"secret" types:text application:@"com.apple.keychainaccess" source:nil]);
 NSString *longest=[@"" stringByPaddingToLength:100000 withString:@"a" startingAtIndex:0];
 assert(![c addText:[longest stringByAppendingString:@"a"] types:text application:nil source:nil]);assert([c addText:longest types:text application:nil source:nil]);
 assert(c.count==3);
 // A long first line is cut at 200 characters, without splitting an emoji.
 NSString *wide=[[@"" stringByPaddingToLength:199 withString:@"b" startingAtIndex:0] stringByAppendingString:@"😀😀"];
 assert([c addText:wide types:text application:nil source:nil]);NSString *name=[c search:@"" limit:1].firstObject[@"name"];assert([name isEqual:[[@"" stringByPaddingToLength:199 withString:@"b" startingAtIndex:0] stringByAppendingString:@"😀"]]);
 // Removal and the 500-item limit.
 [c removeID:[c search:@"" limit:1].firstObject[@"id"]];assert(c.count==3 && ![Texts(c,@"") containsObject:wide]);
 for(int i=0;i<600;i++)assert(([c addText:[NSString stringWithFormat:@"item %d",i] types:text application:nil source:nil]));
 assert(c.count==500 && [Texts(c,@"").firstObject isEqual:@"item 599"] && [Texts(c,@"").lastObject isEqual:@"item 100"]);
 assert([c search:@"item" limit:8].count==8);
 // The history survives a new instance, and only the user can read the file.
 [c waitUntilSaved];struct stat st;assert(stat(file.fileSystemRepresentation,&st)==0 && (st.st_mode&0777)==0600);
 SHClipboard *reloaded=[[SHClipboard alloc] initWithURL:file];assert([Texts(reloaded,@"") isEqual:Texts(c,@"")]);
 assert([reloaded addText:@"after reload" types:text application:nil source:nil]);
 NSArray *ids=[[reloaded search:@"" limit:500] valueForKey:@"id"];assert([NSSet setWithArray:ids].count==ids.count);
 [reloaded clear];[reloaded waitUntilSaved];assert(reloaded.count==0 && [[SHClipboard alloc] initWithURL:file].count==0);
 // A damaged file gives an empty history.
 assert([[NSData dataWithBytes:"not a plist" length:11] writeToURL:file atomically:YES]);assert([[SHClipboard alloc] initWithURL:file].count==0);
 assert(([[NSPropertyListSerialization dataWithPropertyList:@{@"items":@[@{@"id":@"x",@"text":@1},@"junk",@{@"id":@4,@"text":@"kept"}]} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil] writeToURL:file atomically:YES]));
 SHClipboard *partial=[[SHClipboard alloc] initWithURL:file];assert([Texts(partial,@"") isEqual:@[@"kept"]]);
 assert([partial addText:@"new" types:text application:nil source:nil]);assert([[partial search:@"" limit:1].firstObject[@"id"] isEqual:@"clipboard:5"]);
 [partial waitUntilSaved];
 [NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
 puts("PASS clipboard: order, repeats, search folding, concealed and password copies, length limit, 500-item limit, removal, saved file, damaged file");
}return 0;}
