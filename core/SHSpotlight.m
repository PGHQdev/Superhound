#import "SHSpotlight.h"
NSString *const SHSpotlightEntry=@"64";
// Space is key code 49 and ⌘ is 1048576 in the entry; Carbon's cmdKey is 256.
static NSDictionary *Default(BOOL enabled){return @{@"enabled":@(enabled),@"value":@{@"parameters":@[@32,@49,@1048576],@"type":@"standard"}};}
BOOL SHSpotlightEnabled(NSDictionary *hotKeys){
 id entry=[hotKeys isKindOfClass:NSDictionary.class]?hotKeys[SHSpotlightEntry]:nil;
 return ![entry isKindOfClass:NSDictionary.class] || ![entry[@"enabled"] respondsToSelector:@selector(boolValue)] || [entry[@"enabled"] boolValue];
}
NSDictionary *SHSpotlightHotKeys(NSDictionary *hotKeys,BOOL enabled){
 NSMutableDictionary *keys=[hotKeys isKindOfClass:NSDictionary.class]?hotKeys.mutableCopy:NSMutableDictionary.dictionary;id entry=keys[SHSpotlightEntry];
 if([entry isKindOfClass:NSDictionary.class] && [entry[@"value"] isKindOfClass:NSDictionary.class]){NSMutableDictionary *changed=[entry mutableCopy];changed[@"enabled"]=@(enabled);keys[SHSpotlightEntry]=changed;}else keys[SHSpotlightEntry]=Default(enabled);
 return keys;
}
BOOL SHSpotlightTakenOver(NSDictionary *hotKeys,NSInteger code,NSInteger modifiers){return !SHSpotlightEnabled(hotKeys) && code==49 && modifiers==256;}
