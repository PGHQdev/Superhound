#import <AppKit/AppKit.h>
#import "SHLibrary.h"
#import "SHHotKey.h"
// The first-use window: the shortcuts, the search locations with the folder permissions, and a first search.
@interface SHWelcomeController : NSWindowController
@property(nonatomic,copy) void (^openSearch)(void);
- (instancetype)initWithLibrary:(SHLibrary *)library hotKey:(SHHotKey *)hotKey historyKey:(SHHotKey *)historyKey;
// count: the searchable items; indexing: YES while a search location is still indexing.
- (void)updateRoots:(NSArray<NSDictionary *> *)roots count:(NSUInteger)count indexing:(BOOL)indexing;
// A result opened from the search panel. The first one after the window shows marks the first search as done.
- (void)resultOpened;
- (void)show;
@end
