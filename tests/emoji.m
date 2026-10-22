#import <Foundation/Foundation.h>
#import "SHEmoji.h"
#include <assert.h>
static NSArray *Find(SHEmoji *e,NSString *q){return [[e search:q limit:8] valueForKey:@"emoji"];}
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);SHEmoji *e=[[SHEmoji alloc] initWithURL:[NSURL fileURLWithPath:@(argv[1])]];
 assert([e search:@"fire" limit:8].count==0 && e.list.count==0);
 [e waitUntilLoaded];
 assert([Find(e,@"fire").firstObject isEqual:@"🔥"]);assert([Find(e,@"FIRE").firstObject isEqual:@"🔥"]);
 assert([Find(e,@"red heart").firstObject isEqual:@"❤️"]);assert([Find(e,@"thumbs up").firstObject isEqual:@"👍"]);
 assert([Find(e,@"happy") containsObject:@"😀"]);assert(Find(e,@"lol").count>0);assert([Find(e,@"japan") containsObject:@"🇯🇵"]);
 assert([Find(e,@"gri").firstObject isEqual:@"😀"]);
 NSDictionary *fire=[e search:@"fire" limit:1].firstObject;
 assert([fire[@"type"] isEqual:@"emoji"] && [fire[@"copy"] isEqual:@"🔥"] && [fire[@"path"] isEqual:@"emoji:🔥"] && [fire[@"name"] isEqual:@"fire"]);
 assert([e search:@"fire" limit:3].count==3);
 // The list holds every emoji once, in file order, with the keys of a search result.
 NSArray *list=e.list;assert(list.count>1000 && [NSSet setWithArray:[list valueForKey:@"path"]].count==list.count && [list containsObject:fire] && [[list.firstObject objectForKey:@"emoji"] isEqual:@"😀"]);
 for(NSString *q in @[@"",@"f",@"zzqq",@"fire zzqq",@"main.c"])assert([e search:q limit:8].count==0);
 puts("PASS emoji: names, keywords, flags, limits, rejected input, full list");
}return 0;}
