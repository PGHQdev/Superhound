#import <Foundation/Foundation.h>
#import "SHSearchSnapshot.h"
#import "SHQueryController.h"
#import "SHUsage.h"
#import "SHCommands.h"
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
 // Results are equal to their entries: fields kept as UTF-8, a relative path inside or outside the full path, absent keys, and entries with other keys or values.
 NSArray *stored=@[@{@"id":@1,@"root":@"r",@"name":@"roundtrip Café",@"path":@"/日本/roundtrip Café",@"relative":@"roundtrip Café",@"alias":@"東京 alias",@"type":@"file"},
  @{@"id":@2,@"root":@"r",@"name":@"roundtrip app",@"path":@"/apps/roundtrip.app",@"relative":@"other/roundtrip.app",@"alias":@"roundtrip helper",@"type":@"app"},
  @{@"name":@"roundtrip bare",@"path":@"/bare",@"type":@"folder"},
  @{@"id":@"command:roundtrip",@"name":@"roundtrip command",@"path":@"command:roundtrip",@"relative":@"",@"alias":@"",@"type":@"command",@"symbol":@"lock"},
  @{@"id":@(1.5),@"name":@"roundtrip fraction",@"path":@"/fraction",@"type":@"file"}];
 NSArray *returned=[[[SHSearchSnapshot alloc] initWithEntries:stored generation:1] search:@"roundtrip" cancelled:nil];
 assert(returned.count==stored.count);for(NSDictionary *e in stored)assert([returned containsObject:e]);
 // A settings pane ranks with applications, above a file with a better match and below an application with an equal one.
 SHSearchSnapshot *panes=[[SHSearchSnapshot alloc] initWithEntries:@[E(1,@"storage",@"/work/storage",@"file"),E(2,@"Storage",@"/settings/Storage.appex",@"settings"),E(3,@"Storage Tool",@"/apps/Storage Tool.app",@"app")] generation:1];
 assert(([[[panes search:@"storage" cancelled:nil] valueForKey:@"id"] isEqual:@[@2,@3,@1]]));
 assert(([[[panes search:@"" cancelled:nil] valueForKey:@"id"] isEqual:@[@3]]));
 // A term that starts a later word precedes a term inside a word: System Settings leads panes whose file names end in Settings.
 SHSearchSnapshot *words=[[SHSearchSnapshot alloc] initWithEntries:@[@{@"id":@1,@"name":@"Family",@"path":@"/x/FamilySettings.appex",@"relative":@"FamilySettings.appex",@"alias":@"FamilySettings",@"type":@"settings"},E(2,@"System Settings",@"/apps/System Settings.app",@"app")] generation:1];
 for(NSString *q in @[@"settings",@"sett"])assert(([[[words search:q cancelled:nil] valueForKey:@"id"] isEqual:@[@2,@1]]));
 // Commands are found by name and by other words, rank with applications, and stay out of the empty-query list.
 NSArray *commands=SHCommands.entries;assert([NSSet setWithArray:[commands valueForKey:@"path"]].count==commands.count);
 for(NSDictionary *c in commands)assert([c[@"type"] isEqual:@"command"] && [c[@"path"] hasPrefix:@"command:"] && [c[@"symbol"] length] && SHLaunchable(c));
 SHSearchSnapshot *system=[[SHSearchSnapshot alloc] initWithEntries:[commands arrayByAddingObjectsFromArray:@[E(1,@"lock notes",@"/work/lock notes",@"file"),E(2,@"Sleep Tracker",@"/apps/Sleep Tracker.app",@"app")]] generation:1];
 NSDictionary *expected=@{@"lock":@"command:lock",@"reboot":@"command:restart",@"shut":@"command:shutdown",@"power off":@"command:shutdown",@"unmute":@"command:mute",@"dark":@"command:dark",@"empty trash":@"command:trash",@"eject":@"command:eject",@"logout":@"command:logout",@"sleep":@"command:sleep",@"display off":@"command:display",@"screen saver":@"command:screensaver"};
 for(NSString *q in expected)assert([[[system search:q cancelled:nil] firstObject][@"path"] isEqual:expected[q]]);
 assert(([[[system search:@"lock" cancelled:nil] valueForKey:@"path"] isEqual:@[@"command:lock",@"/work/lock notes"]]));
 assert(([[[system search:@"sleep" cancelled:nil] valueForKey:@"path"] isEqual:@[@"command:sleep",@"command:display",@"/apps/Sleep Tracker.app"]]));
 assert(([[[system search:@"" cancelled:nil] valueForKey:@"path"] isEqual:@[@"/apps/Sleep Tracker.app"]]));
 NSArray *typos=@[E(1,@"Claude",@"/apps/Claude.app",@"app"),E(2,@"claude.js",@"/work/claude.js",@"file"),E(3,@"Visual Studio Code",@"/apps/vsc.app",@"app"),E(4,@"mail",@"/work/mail",@"file"),E(5,@"main.c",@"/work/main.c",@"file"),E(6,@"Maps",@"/apps/Maps.app",@"app"),E(7,@"documentation",@"/work/documentation",@"file")];
 SHSearchSnapshot *t=[[SHSearchSnapshot alloc] initWithEntries:typos generation:1];
 for(NSString *q in @[@"calude",@"cluade",@"claide",@"clude",@"claudee",@"lcaude"])assert(([[[t search:q cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@2]]));
 assert(([[[t search:@"studoi" cancelled:nil] valueForKey:@"id"] isEqual:@[@3]]));
 assert(([[[t search:@"documantaton" cancelled:nil] valueForKey:@"id"] isEqual:@[@7]]));
 assert([t search:@"cxyude" cancelled:nil].count==0);assert([t search:@"mpa" cancelled:nil].count==0);
 // An exact file match stays above an application reached only through a typing error.
 assert(([[[t search:@"main" cancelled:nil] valueForKey:@"id"] isEqual:@[@5,@4]]));
 NSURL *usageURL=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".plist"]]];
 SHUsage *usage=[[SHUsage alloc] initWithURL:usageURL];
 assert([usage preferredForQuery:@"code"].count==0);
 [usage recordQuery:@" DeCo " result:entries[3]];
 assert([[[s search:@"de" cancelled:nil] firstObject][@"id"] isEqual:@1]);
 assert([[[s search:@"de" preferred:[usage preferredForQuery:@"de"] cancelled:nil] firstObject][@"id"] isEqual:@4]);
 assert(([[[s search:@"code" preferred:[usage preferredForQuery:@"code"] cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@3,@2,@4,@5]]));
 [usage recordQuery:@"code" result:entries[4]];[usage recordQuery:@"cod" result:entries[1]];[usage recordQuery:@"cod" result:entries[1]];
 usage=[[SHUsage alloc] initWithURL:usageURL];
 // readme was opened for "code" itself and leads; the app named Code comes next, above Code notes, which was opened for "cod".
 assert(([[[s search:@"code" preferred:[usage preferredForQuery:@"code"] cancelled:nil] valueForKey:@"id"] isEqual:@[@5,@1,@2,@3,@4]]));
 assert(([[[s search:@"cod" preferred:[usage preferredForQuery:@"cod"] cancelled:nil] valueForKey:@"id"] isEqual:@[@2,@5,@1,@3,@4]]));
 assert([[[s search:@"vsc" preferred:[usage preferredForQuery:@"vsc"] cancelled:nil] firstObject][@"id"] isEqual:@3]);
 // A learned result reached only through a typing error stays below an exact match.
 [usage recordQuery:@"main" result:typos[3]];
 assert(([[[t search:@"main" preferred:[usage preferredForQuery:@"main"] cancelled:nil] valueForKey:@"id"] isEqual:@[@5,@4]]));
 assert(([[[s search:@"" preferred:[usage preferredForQuery:@""] cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@3]]));
 [usage recordQuery:@"" result:entries[2]];
 assert(([[[s search:@"" preferred:[usage preferredForQuery:@""] cancelled:nil] valueForKey:@"id"] isEqual:@[@3,@1]]));
 assert(([[[s search:@"code" preferred:[usage preferredForQuery:@"code"] cancelled:nil] valueForKey:@"id"] isEqual:@[@5,@1,@2,@3,@4]]));
 // A name typed in full leads a choice made for a shorter query, until the user opens another result for the full query; a file with that name gets no such place.
 NSArray *mails=@[E(1,@"Mail",@"/apps/Mail.app",@"app"),E(2,@"Mailspring",@"/apps/Mailspring.app",@"app"),E(3,@"mail",@"/work/mail",@"file"),E(4,@"Activity Monitor",@"/apps/Activity Monitor.app",@"app"),E(5,@"Activity Monitor Helper",@"/apps/Activity Monitor Helper.app",@"app")];
 SHSearchSnapshot *mail=[[SHSearchSnapshot alloc] initWithEntries:mails generation:1];
 [NSFileManager.defaultManager removeItemAtURL:usageURL error:nil];usage=[[SHUsage alloc] initWithURL:usageURL];
 [usage recordQuery:@"ma" result:mails[1]];[usage recordQuery:@"act" result:mails[4]];
 assert(([[[mail search:@"ma" preferred:[usage preferredForQuery:@"ma"] cancelled:nil] valueForKey:@"id"] isEqual:@[@2,@1,@3,@4,@5]]));
 assert(([[[mail search:@"mail" preferred:[usage preferredForQuery:@"mail"] cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@2,@3]]));
 assert(([[[mail search:@"Activity  MONITOR" preferred:[usage preferredForQuery:@"activity monitor"] cancelled:nil] valueForKey:@"id"] isEqual:@[@4,@5]]));
 [usage recordQuery:@"mail" result:mails[1]];
 assert(([[[mail search:@"mail" preferred:[usage preferredForQuery:@"mail"] cancelled:nil] valueForKey:@"id"] isEqual:@[@2,@1,@3]]));
 [usage recordQuery:@"mail" result:mails[0]];[usage recordQuery:@"mail" result:mails[0]];
 assert(([[[mail search:@"mail" preferred:[usage preferredForQuery:@"mail"] cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@2,@3]]));
 // The same holds for a settings pane named by its alias and for a command, against choices made for shorter and longer queries; a choice reached only through a typing error stays below an exact match.
 NSArray *others=@[@{@"id":@1,@"name":@"Displays",@"path":@"/s/Displays.appex",@"relative":@"Displays.appex",@"alias":@"monitor",@"type":@"settings"},E(2,@"Monitor Pro",@"/apps/Monitor Pro.app",@"app"),@{@"id":@3,@"name":@"Sleep",@"path":@"command:sleep",@"relative":@"",@"alias":@"",@"type":@"command"},E(4,@"Sleep Tracker",@"/apps/Sleep Tracker.app",@"app"),E(5,@"Notes",@"/apps/Notes.app",@"app"),E(6,@"notse draft",@"/work/notse draft",@"file")];
 SHSearchSnapshot *other=[[SHSearchSnapshot alloc] initWithEntries:others generation:1];
 [usage recordQuery:@"mon" result:others[1]];[usage recordQuery:@"sleep tracker" result:others[3]];[usage recordQuery:@"notse" result:others[4]];
 assert(([[[other search:@"monitor" preferred:[usage preferredForQuery:@"monitor"] cancelled:nil] valueForKey:@"id"] isEqual:@[@1,@2]]));
 assert(([[[other search:@"sleep" preferred:[usage preferredForQuery:@"sleep"] cancelled:nil] valueForKey:@"id"] isEqual:@[@3,@4]]));
 assert(([[[other search:@"notse" preferred:[usage preferredForQuery:@"notse"] cancelled:nil] valueForKey:@"id"] isEqual:@[@6,@5]]));
 [NSFileManager.defaultManager removeItemAtURL:usageURL error:nil];
 assert([s search:[@"a" stringByPaddingToLength:100000 withString:@"a" startingAtIndex:0] cancelled:nil].count == 0);
 assert([s search:@"code" cancelled:^BOOL {return YES;}].count == 0);
 assert([s search:@"" cancelled:nil].count == 2);
 // Completion: the typed start of a name, folded like search; nothing for a middle match, a longer text, or an empty one.
 assert([SHCompletion(@"Safari",@"saf") isEqual:@"ari"] && [SHCompletion(@"Café Notes",@"CAFE") isEqual:@" Notes"] && [SHCompletion(@"Safari",@"ｓａｆ") isEqual:@"ari"] && [SHCompletion(@"Safari",@"safari") isEqual:@""]);
 assert(!SHCompletion(@"Safari",@"fari") && !SHCompletion(@"Safari",@"safarix") && !SHCompletion(@"Safari",@""));
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
  for(size_t i=0;i<64;i++){a[i]=97+arc4random_uniform(3);b[i]=97+arc4random_uniform(3);}
  sh_match_typo((SHText){a,boundaries,n},(SHText){b,boundaries,m});
 }
 puts("PASS search: ranking, Unicode, paths, cancellation, exhaustive scan, latest query, 20000 random inputs");
} return 0; }
