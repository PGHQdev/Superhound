#import <AppKit/AppKit.h>
#import "SHLibrary.h"
#import "SHHotKey.h"
@interface SHSettingsController : NSWindowController
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey historyKey:(SHHotKey *)historyKey;
- (void)updateRoots:(NSArray<NSDictionary *> *)roots message:(NSString *)message;
- (void)show;
@end
