#import "SHCommands.h"
@implementation SHCommands
+ (NSArray<NSDictionary *> *)entries {
 static NSArray *entries;static dispatch_once_t once;
 dispatch_once(&once,^{
  NSMutableArray *list=NSMutableArray.array;
  for(NSArray *c in @[@[@"lock",@"Lock Screen",@"lock computer",@"lock.fill"],@[@"sleep",@"Sleep",@"suspend computer",@"moon.fill"],@[@"display",@"Sleep Display",@"screen monitor off",@"display"],
   @[@"restart",@"Restart",@"reboot computer",@"arrow.clockwise"],@[@"shutdown",@"Shut Down",@"shutdown power off turn off computer",@"power"],@[@"logout",@"Log Out",@"logout sign out",@"rectangle.portrait.and.arrow.right"],
   @[@"screensaver",@"Start Screen Saver",@"screensaver",@"sparkles"],@[@"mute",@"Toggle Mute",@"mute unmute sound volume audio",@"speaker.slash.fill"],@[@"dark",@"Toggle Dark Mode",@"dark light mode appearance theme",@"circle.lefthalf.filled"],
   @[@"trash",@"Empty Trash",@"bin delete",@"trash.fill"],@[@"eject",@"Eject All Disks",@"unmount drives volumes",@"eject.fill"]]){
   NSString *path=[@"command:" stringByAppendingString:c[0]];
   [list addObject:@{@"type":@"command",@"id":path,@"path":path,@"relative":@"",@"name":c[1],@"alias":c[2],@"symbol":c[3]}];
  }
  entries=[list copy];
 });
 return entries;
}
@end
