#import <Foundation/Foundation.h>
#import "SHSpotlight.h"
static void Check(BOOL ok,const char *what){if(!ok){fprintf(stderr,"failed: %s\n",what);abort();}}
int main(void){@autoreleasepool{
 NSDictionary *off=@{@"enabled":@NO,@"value":@{@"parameters":@[@32,@49,@1048576],@"type":@"standard"}},*other=@{@"enabled":@YES,@"value":@{@"parameters":@[@65535,@122,@8388608],@"type":@"standard"}};
 Check(SHSpotlightEnabled(nil) && SHSpotlightEnabled(@{}) && SHSpotlightEnabled(@{@"64":@"damaged"}) && SHSpotlightEnabled(@{@"64":@{}}),"a missing or damaged entry is on");
 Check(!SHSpotlightEnabled(@{@"64":off}) && SHSpotlightEnabled(@{@"64":@{@"enabled":@YES}}) && !SHSpotlightEnabled(@{@"64":@{@"enabled":@0}}),"the enabled flag decides");
 NSDictionary *on=SHSpotlightHotKeys(@{@"64":off,@"32":other},YES);
 Check(SHSpotlightEnabled(on) && [on[@"64"][@"value"] isEqual:off[@"value"]] && [on[@"32"] isEqual:other],"turning on keeps the keys and the other entries");
 NSDictionary *custom=@{@"enabled":@NO,@"value":@{@"parameters":@[@32,@49,@524288],@"type":@"standard"}};
 Check([SHSpotlightHotKeys(@{@"64":custom},YES)[@"64"][@"value"][@"parameters"] isEqual:@[@32,@49,@524288]],"turning on keeps keys that the user changed");
 for(id damaged in @[NSNull.null,@"damaged",@{@"enabled":@NO}]){NSDictionary *fixed=SHSpotlightHotKeys(@{@"64":damaged},NO);Check(!SHSpotlightEnabled(fixed) && [fixed[@"64"][@"value"][@"parameters"] isEqual:@[@32,@49,@1048576]],"a damaged entry gets ⌘Space");}
 Check(!SHSpotlightEnabled(SHSpotlightHotKeys(nil,NO)) && SHSpotlightHotKeys((NSDictionary *)@[],YES).count==1,"no hot keys gives one entry");
 Check(SHSpotlightTakenOver(@{@"64":off},49,256),"off with Superhound on ⌘Space is taken over");
 Check(!SHSpotlightTakenOver(@{@"64":off},49,2048) && !SHSpotlightTakenOver(@{@"64":off},11,256) && !SHSpotlightTakenOver(@{},49,256),"other keys or Spotlight on is not taken over");
 puts("PASS spotlight: enabled flag, kept keys and entries, damaged entries, takeover rule");
}return 0;}
