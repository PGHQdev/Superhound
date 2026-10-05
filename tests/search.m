#import <Foundation/Foundation.h>
#import "SHSearchSnapshot.h"
#import "SHQueryController.h"
#import "SHUsage.h"
#include "sh_match.h"
#include <assert.h>
static NSDictionary *E(NSInteger i, NSString *name, NSString *path, NSString *type) {
 return @{@"id":@(i), @"name":name, @"path":path, @"relative":path, @"alias":@"", @"type":type};
}
int main(void) { @autoreleasepool {
 NSArray *entries = @[E(1,@"Code",@"/apps/Code.app",@"app"),E(2,@"Code notes",@"/work/Code notes",@"file"),E(3,@"Visual Studio Code",@"/apps/vsc.app",@"app"),E(4,@"decode",@"/work/decode",@"file"),E(5,@"readme",@"/code/readme",@"file"),E(6,@"Café",@"/work/Café",@"file"),E(7,@"東京旅行",@"/日本/東京旅行",@"file")];
 SHSearchSnapshot *s = [[SHSearchSnapshot alloc] initWithEntries:entries generation:1];
 NSArray *r = [s search:@"code" cancelled:nil];
 assert(([[r valueForKey:@"id"] isEqual:@[@1,@3,@2,@4,@5]]));
 assert([r[0][@"id"] isEqual:@1]); assert([r[1][@"id"] isEqual:@3]);
 assert([[[s search:@"vsc" cancelled:nil] firstObject][@"id"] isEqual:@3]);
 assert([[[s search:@"CAFÉ" cancelled:nil] firstObject][@"id"] isEqual:@6]);
 assert([[[s search:@"日本 東京" cancelled:nil] firstObject][@"id"] isEqual:@7]);
 assert([s search:@"code missing" cancelled:nil].count == 0);
 NSURL *usageURL=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".plist"]]];
 SHUsage *usage=[[SHUsage alloc] initWithURL:usageURL];
 assert([usage preferredForQuery:@"code"].count==0);
 [usage recordQuery:@" DeCo " result:entries[3]];
 assert([[[s search:@"de" cancelled:nil] firstObject][@"id"] isEqual:@1]);
 assert([[[s search:@"de" preferred:[usage preferredForQuery:@"de"] cancelled:nil] firstObject][@"id"] isEqual:@4]);
 assert(([[[s search:@"code" preferred:[usage preferredForQuery:@"code"] cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@3,@2,@4,@5]]));
 [usage recordQuery:@"code" result:entries[4]];[usage recordQuery:@"cod" result:entries[1]];[usage recordQuery:@"cod" result:entries[1]];
 usage=[[SHUsage alloc] initWithURL:usageURL];
 assert(([[[s search:@"code" preferred:[usage preferredForQuery:@"code"] cancelled:nil] valueForKey:@"id"] isEqual:@[@5,@2,@1,@3,@4]]));
 assert(([[[s search:@"cod" preferred:[usage preferredForQuery:@"cod"] cancelled:nil] valueForKey:@"id"] isEqual:@[@2,@5,@1,@3,@4]]));
 assert([[[s search:@"vsc" preferred:[usage preferredForQuery:@"vsc"] cancelled:nil] firstObject][@"id"] isEqual:@3]);
 [NSFileManager.defaultManager removeItemAtURL:usageURL error:nil];
 assert([s search:[@"a" stringByPaddingToLength:100000 withString:@"a" startingAtIndex:0] cancelled:nil].count == 0);
 assert([s search:@"code" cancelled:^BOOL {return YES;}].count == 0);
 assert([s search:@"" cancelled:nil].count == 2);
 NSMutableArray *large = NSMutableArray.array;
 for (int i=0;i<11000;i++) [large addObject:E(i,@"noise",[NSString stringWithFormat:@"/noise/%d",i],@"file")];
 [large addObject:E(20000,@"needle",@"/needle",@"file")];
 s = [[SHSearchSnapshot alloc] initWithEntries:large generation:2];
 assert([[[s search:@"needle" cancelled:nil] firstObject][@"id"] isEqual:@20000]);
 SHQueryController *q = SHQueryController.new; q.snapshot = s;
 __block BOOL delivered = NO;
 [q submit:@"noise" preferred:nil completion:^(NSArray *results) {(void)results; assert(!"obsolete query delivered");}];
 [q submit:@"needle" preferred:nil completion:^(NSArray *results) {assert([results.firstObject[@"id"] isEqual:@20000]); delivered=YES;}];
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
 while (!delivered && deadline.timeIntervalSinceNow>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
 assert(delivered);
 NSDictionary *one=@{@"id":@1,@"root":@"removed",@"name":@"needle",@"path":@"/one/needle",@"relative":@"needle",@"type":@"file"};
 NSDictionary *two=@{@"id":@2,@"root":@"kept",@"name":@"needle",@"path":@"/two/needle",@"relative":@"needle",@"type":@"file"};
 SHSearchSnapshot *original=[[SHSearchSnapshot alloc] initWithEntries:@[one,two] generation:3];
 SHSearchSnapshot *masked=[original snapshotByExcludingRoots:[NSSet setWithObject:@"removed"]];
 original=nil;assert(masked.count==1);assert([masked search:@"needle" cancelled:nil].count==1);
 assert([[[masked search:@"needle" cancelled:nil] firstObject][@"id"] isEqual:@2]);

 for (int k=0;k<20000;k++) {
  uint32_t a[64],b[64]; uint8_t boundaries[64]; size_t n=arc4random_uniform(64),m=arc4random_uniform(64);
  for(size_t i=0;i<64;i++){a[i]=arc4random_uniform(0x110000);b[i]=arc4random_uniform(0x110000);boundaries[i]=i%3==0;}
  sh_match((SHText){a,boundaries,n},(SHText){b,boundaries,m});
 }
 puts("PASS search: ranking, Unicode, paths, cancellation, exhaustive scan, latest query, 20000 random inputs");
} return 0; }
