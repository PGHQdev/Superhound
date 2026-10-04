#import <Foundation/Foundation.h>
#import "SHSearchSnapshot.h"
// Expected IDs were captured from commit 6d7ec7d before the storage change.
// This guards observable ranking and shared-storage lifetime, not internal layout.
int main(void){@autoreleasepool{
 NSMutableArray *entries=NSMutableArray.array;
 NSArray *names=@[@"Code",@"Café",@"Café",@"東京旅行",@"🧑🏽‍💻 notes",@"report-final",@"𠮷野",@"Visual Studio Code",@"a.b_c",@"Résumé"];
 NSArray *parents=@[@"/shared/team",@"/日本/資料",@"/Café/code",@"/café/Code",@"/𠮷野/🧑🏽‍💻",@"/one/a/b"];
 for(NSUInteger i=0;i<1800;i++){@autoreleasepool{
  NSString *name=[names[i%names.count] stringByAppendingFormat:@" %lu",(unsigned long)(i%23)];
  NSString *path=[NSString stringWithFormat:@"%@/%@%@",parents[i%parents.count],name,i%3?@"":@".app"];
  [entries addObject:@{@"id":@(1800-i),@"root":i%2?@"keep":@"remove",@"name":name,@"path":path,@"relative":path,@"type":i%3?@"file":@"app",@"alias":i%4?@"":@"Shared Alias"}];
 }}
 NSArray *queries=@[@"",@"code",@"CAFE",@"東京",@"旅行",@"𠮷",@"🧑🏽‍💻",@"resume",@"vsc",@"shared alias",@"team final",@"日本 7",@"22 code",@"missing",@"a/b",@"a.b",@"app",@"資料 東京",@"cafe code",@"one a b"];
 SHSearchSnapshot *original=[[SHSearchSnapshot alloc] initWithEntries:entries generation:1];
 SHSearchSnapshot *masked=[original snapshotByExcludingRoots:[NSSet setWithObject:@"remove"]];
 SHSearchSnapshot *replacement=[[SHSearchSnapshot alloc] initWithEntries:entries generation:2];
 original=nil;
 for(SHSearchSnapshot *snapshot in @[replacement,masked])for(NSString *query in queries){
  NSArray *ids=[[snapshot search:query cancelled:nil] valueForKey:@"id"];
  printf("%s\n",[[ids componentsJoinedByString:@","] UTF8String]);
 }
}return 0;}
