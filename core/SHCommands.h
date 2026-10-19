#import <Foundation/Foundation.h>
// System commands, searched with applications. app/SHResultActions.m runs them.
@interface SHCommands : NSObject
// Keys: type "command", id and path "command:<key>", name, alias (other words that find it), relative "", symbol (an SF Symbol name).
+ (NSArray<NSDictionary *> *)entries;
@end
