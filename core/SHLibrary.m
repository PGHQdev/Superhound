#import "SHLibrary.h"
#import "SHCatalog.h"
#import "SHScanner.h"
#import "SHChangeMonitor.h"
#import "SHFolderAccess.h"
#import "SHMetrics.h"
#import <sys/stat.h>
#import <errno.h>
@interface SHRoot : NSObject
@property NSString *identifier;
@property NSString *path;
@property NSData *bookmark;
@property NSURL *url;
@property BOOL scoped;
@property BOOL apps;
@property NSString *state;
@property NSUInteger count;
@property SHChangeMonitor *monitor;
@property NSArray *entries;
@end
@implementation SHRoot
- (void)dealloc {[_monitor stop];if(_scoped)[_url stopAccessingSecurityScopedResource];}
@end
@implementation SHLibrary {
 dispatch_queue_t _worker;
 SHCatalog *_catalog;
 NSMutableArray<SHRoot *> *_roots;
 NSLock *_scheduleLock;
 NSMutableSet *_scheduled,*_again,*_cancelled,*_hiddenRoots;
 SHSearchSnapshot *_publicSnapshot;
 NSArray *_publicRoots;
 NSString *_publicMessage;
 BOOL _exclude;
 uint64_t _generation;
 SHSearchSnapshot *_snapshot;
 NSString *_message;
}
- (instancetype)initWithStateURL:(NSURL *)url {
 if((self=[super init])){_stateURL=url;_worker=dispatch_queue_create("com.superhound.catalog",dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_UTILITY,0));_roots=NSMutableArray.array;_exclude=YES;_scheduleLock=NSLock.new;_scheduled=NSMutableSet.set;_again=NSMutableSet.set;_cancelled=NSMutableSet.set;_hiddenRoots=NSMutableSet.set;_message=@"Preparing search…";}return self;
}
- (NSURL *)settingsURL {return [_stateURL URLByAppendingPathComponent:@"folders.plist"];}
- (void)save {
 NSMutableArray *roots=NSMutableArray.array;for(SHRoot *r in _roots)if(!r.apps && r.bookmark)[roots addObject:@{@"id":r.identifier,@"path":r.path,@"bookmark":r.bookmark}];
 NSError *error=nil;NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"roots":roots,@"excludeGenerated":@(_exclude)} format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
 if(![data writeToURL:self.settingsURL options:NSDataWritingAtomic error:&error])_message=@"Folder settings could not be saved. Check available disk space.";
}
- (SHRoot *)root:(NSString *)identifier {for(SHRoot *r in _roots)if([r.identifier isEqual:identifier])return r;return nil;}
- (void)publish:(BOOL)rebuild {
 if(rebuild){NSMutableArray *entries=NSMutableArray.array;NSMutableSet *seen=NSMutableSet.set;
  for(SHRoot *r in _roots)for(NSDictionary *e in r.entries){NSString *path=e[@"path"];if(![seen containsObject:path]){[entries addObject:e];[seen addObject:path];}}
  SHSearchSnapshot *s=[[SHSearchSnapshot alloc] initWithEntries:entries generation:++_generation];
  if(s)_snapshot=s;else {_snapshot=nil;_message=@"Not enough memory to prepare search. Remove a large search location and refresh.";}
 }
 NSMutableArray *states=NSMutableArray.array;
 for(SHRoot *r in _roots)[states addObject:@{@"id":r.identifier,@"path":r.path?:@"",@"state":r.state?:@"Waiting",@"count":@(r.count),@"apps":@(r.apps)}];
 SHSearchSnapshot *snapshot=_snapshot;NSString *message=[_message copy];
 dispatch_async(dispatch_get_main_queue(),^{self->_publicSnapshot=snapshot;self->_publicRoots=states;self->_publicMessage=message;[self deliver];});
}
- (void)deliver {
 NSAssert(NSThread.isMainThread,@"main thread");
 SHSearchSnapshot *visible=_hiddenRoots.count?[_publicSnapshot snapshotByExcludingRoots:_hiddenRoots]:_publicSnapshot;
 if(self.updated)self.updated(visible,_publicRoots?:@[],_publicMessage?:@"Updating search locations…");
}
- (void)invalidateRoot:(NSString *)identifier {
 [_scheduleLock lock];[_cancelled addObject:identifier];[_scheduleLock unlock];
 void (^hide)(void)=^{[self->_hiddenRoots addObject:identifier];[self deliver];};
 if(NSThread.isMainThread)hide();else dispatch_async(dispatch_get_main_queue(),hide);
}
- (BOOL)cancelled:(NSString *)identifier {[_scheduleLock lock];BOOL value=[_cancelled containsObject:identifier];[_scheduleLock unlock];return value;}
- (void)clearCancellation:(NSString *)identifier {[_scheduleLock lock];[_cancelled removeObject:identifier];[_scheduleLock unlock];}
- (void)reconcileCoverage {
 for(SHRoot *child in _roots){if(child.apps)continue;
  SHRoot *cover=nil;for(SHRoot *candidate in _roots)if([self root:child coveredBy:candidate]){cover=candidate;break;}
  if(cover && ![child.state hasPrefix:@"Covered by"]){child.entries=nil;child.count=0;child.state=[@"Covered by " stringByAppendingString:cover.path];[child.monitor stop];child.monitor=nil;}
  else if(!cover && [child.state hasPrefix:@"Covered by"]){child.state=@"Waiting";[self request:child.identifier];}
 }
}
- (void)start {dispatch_async(_worker,^{@autoreleasepool{
 double began=SHTime();NSError *error=nil;
 if(![NSFileManager.defaultManager createDirectoryAtURL:self->_stateURL withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]){self->_message=@"Cannot create Superhound’s local data directory.";[self publish:NO];return;}
 chmod(self->_stateURL.fileSystemRepresentation,0700);
 self->_catalog=[[SHCatalog alloc] initWithURL:[self->_stateURL URLByAppendingPathComponent:@"catalog.sqlite"] error:&error];
 if(!self->_catalog){self->_message=@"Cannot open the local catalog. Check available disk space and restart.";[self publish:NO];return;}
 self->_message=self->_catalog.rebuilt?@"Rebuilding a damaged or older catalog. Your selected folders are preserved.":@"Only selected folders are searched. Add a folder in Search Locations.";
 NSDictionary *settings=[NSDictionary dictionaryWithContentsOfURL:self.settingsURL];
 if(settings[@"excludeGenerated"])self->_exclude=[settings[@"excludeGenerated"] boolValue];
 // Safari lives in the Cryptex folder; its link in /Applications is hidden from directory listings.
 for(NSString *path in @[@"/Applications",@"/System/Applications",@"/System/Cryptexes/App/System/Applications",[@"~/Applications" stringByExpandingTildeInPath]]){
  SHRoot *r=SHRoot.new;r.identifier=[@"apps:" stringByAppendingString:path];r.path=path;r.apps=YES;[self->_roots addObject:r];
 }
 for(NSDictionary *saved in settings[@"roots"]){if(![saved[@"id"] isKindOfClass:NSString.class]||![saved[@"bookmark"] isKindOfClass:NSData.class])continue;SHRoot *r=SHRoot.new;r.identifier=saved[@"id"];r.path=saved[@"path"]?:@"Selected folder";r.bookmark=saved[@"bookmark"];[self->_roots addObject:r];}
 for(SHRoot *r in self->_roots){[self validate:r];if(r.url)r.entries=[self->_catalog entriesForRoot:r.identifier];r.count=r.entries.count;}
 [self publish:YES];SHMeasure(@"cached_catalog_ready",began);for(SHRoot *r in self->_roots)[self request:r.identifier];
 }});}
- (BOOL)validate:(SHRoot *)r {
 [r.monitor stop];r.monitor=nil;if(r.scoped)[r.url stopAccessingSecurityScopedResource];r.scoped=NO;r.url=nil;
 NSError *error=nil;BOOL stale=NO;
 NSURL *url=r.apps?[NSURL fileURLWithPath:r.path]:[SHFolderAccess resolveBookmark:r.bookmark stale:&stale error:&error];
 if(!url){r.state=@"Access needed — select this folder again";r.entries=nil;return NO;}
 BOOL scoped=[url startAccessingSecurityScopedResource];NSNumber *dir=nil;
 if(![url getResourceValue:&dir forKey:NSURLIsDirectoryKey error:&error] || !dir.boolValue || ![NSFileManager.defaultManager isReadableFileAtPath:url.path]){if(scoped)[url stopAccessingSecurityScopedResource];r.state=error.code==NSFileReadNoSuchFileError?@"Unavailable":@"Access needed — select this folder again";r.entries=nil;return NO;}
 r.url=url;r.scoped=scoped;r.path=url.URLByResolvingSymlinksInPath.path;r.state=@"Waiting";
 if(stale && !r.apps){NSData *fresh=[SHFolderAccess bookmarkForURL:url error:nil];if(fresh){r.bookmark=fresh;[self save];}}
 NSString *identifier=r.identifier;__weak typeof(self) weak=self;
 r.monitor=[[SHChangeMonitor alloc] initWithURL:url excludingURLs:@[_stateURL] changed:^(BOOL invalidated,NSSet *listed,NSSet *walked){
  SHLibrary *self=weak;if(!self)return;
  if(invalidated){[self invalidateRoot:identifier];dispatch_async(self->_worker,^{SHRoot *root=[self root:identifier];if(root){root.entries=nil;root.state=@"Rechecking changed location";[self clearCancellation:identifier];[self reconcileCoverage];[self publish:YES];}});}
  if(listed)[self update:identifier listed:listed walked:walked];else [self request:identifier];
 }];
 return YES;
}
// Resolves links in the longest existing ancestor; a removed path keeps its unresolved tail.
static NSString *Resolve(NSString *path){
 NSMutableArray *tail=NSMutableArray.array;NSString *cursor=path;
 while(cursor.length>1 && ![NSFileManager.defaultManager fileExistsAtPath:cursor]){[tail insertObject:cursor.lastPathComponent atIndex:0];cursor=cursor.stringByDeletingLastPathComponent;}
 NSString *resolved=[NSURL fileURLWithPath:cursor].URLByResolvingSymlinksInPath.path;for(NSString *part in tail)resolved=[resolved stringByAppendingPathComponent:part];return resolved;
}
// Rescans only the changed directories of a ready root; anything unexpected falls back to a full rescan.
- (void)update:(NSString *)identifier listed:(NSSet<NSString *> *)listed walked:(NSSet<NSString *> *)walked {dispatch_async(_worker,^{@autoreleasepool{
 SHRoot *r=[self root:identifier];if(!r || !r.url || ![r.state isEqual:@"Ready"] || [self cancelled:identifier])return;
 if(r.apps){[self request:identifier];return;}
 NSTimeInterval started=NSProcessInfo.processInfo.systemUptime;NSMutableArray *directories=NSMutableArray.array;NSString *prefix=[r.path stringByAppendingString:@"/"];
 for(NSString *changed in [walked setByAddingObjectsFromSet:listed]){
  BOOL deep=[walked containsObject:changed];NSString *path=Resolve(changed),*relative;
  if([path isEqual:r.path] || [r.path hasPrefix:[path stringByAppendingString:@"/"]])relative=@"";
  else if([path hasPrefix:prefix])relative=[path substringFromIndex:prefix.length];
  else {[self request:identifier];return;}
  if(deep && !relative.length){[self request:identifier];return;}
  if(relative.length && ![self root:r reaches:relative])continue;
  NSError *error=nil;NSURL *url=relative.length?[r.url URLByAppendingPathComponent:relative]:r.url;
  NSArray *found=[SHScanner scanURL:url applicationsOnly:NO excludeGenerated:self->_exclude excludingURLs:@[self->_stateURL] shallow:!deep cancelled:^BOOL{return [self cancelled:identifier];} progress:nil error:&error];
  if([self cancelled:identifier])return;
  if(!found){BOOL gone=([error.domain isEqual:NSCocoaErrorDomain] && error.code==NSFileReadNoSuchFileError) || ([error.domain isEqual:NSPOSIXErrorDomain] && error.code==ENOENT);if(gone)found=@[];else {[self request:identifier];return;}}
  NSMutableArray *entries=[NSMutableArray arrayWithCapacity:found.count];
  for(NSDictionary *e in found){NSMutableDictionary *m=[e mutableCopy];if(relative.length)m[@"relative"]=[relative stringByAppendingPathComponent:e[@"relative"]];[entries addObject:m];}
  [directories addObject:@{@"relative":relative,@"deep":@(deep),@"entries":entries}];
 }
 if(!directories.count)return;
 NSUInteger changed=0;NSError *error=nil;
 if(![self->_catalog updateRoot:identifier directories:directories changed:&changed error:&error]){[self request:identifier];return;}
 NSLog(@"Catalog update: %lu directories, %lu changed rows, %.3f seconds",(unsigned long)directories.count,(unsigned long)changed,NSProcessInfo.processInfo.systemUptime-started);
 if(!changed)return;
 r.entries=[self->_catalog entriesForRoot:identifier];r.count=r.entries.count;[self reconcileCoverage];[self publish:YES];
}});}
- (void)request:(NSString *)identifier {
 [_scheduleLock lock];if([_scheduled containsObject:identifier]){[_again addObject:identifier];[_scheduleLock unlock];return;}[_scheduled addObject:identifier];[_scheduleLock unlock];
 dispatch_async(_worker,^{@autoreleasepool{
  SHRoot *r=[self root:identifier];if(r)[self scan:r];
  [self->_scheduleLock lock];[self->_scheduled removeObject:identifier];BOOL again=[self->_again containsObject:identifier];[self->_again removeObject:identifier];[self->_scheduleLock unlock];
  if(again && [self root:identifier])[self request:identifier];
 }});
}
static BOOL Covered(NSString *path,NSString *parent){return [path isEqual:parent] || [path hasPrefix:[parent stringByAppendingString:@"/"]];}
- (BOOL)root:(SHRoot *)r coveredBy:(SHRoot *)other {
 if(other==r || other.apps || ![other.state isEqual:@"Ready"] || !other.entries || !Covered(r.path,other.path))return NO;
 if([r.path isEqual:other.path])return [_roots indexOfObject:other]<[_roots indexOfObject:r];
 return [self root:other reaches:[r.path substringFromIndex:other.path.length+1]];
}
// YES when a scan of root would descend to relative: no hidden, generated, package, or linked component on the way.
- (BOOL)root:(SHRoot *)root reaches:(NSString *)relative {
 NSSet *excluded=[NSSet setWithArray:@[@".git",@"node_modules",@"vendor",@"build",@"dist",@"DerivedData"]];
 NSURL *cursor=root.url;
 for(NSString *part in relative.pathComponents){
  if([part hasPrefix:@"."] || (_exclude && [excluded containsObject:part]))return NO;
  cursor=[cursor URLByAppendingPathComponent:part];NSNumber *package=nil,*hidden=nil,*link=nil;
  [cursor getResourceValue:&package forKey:NSURLIsPackageKey error:nil];[cursor getResourceValue:&hidden forKey:NSURLIsHiddenKey error:nil];[cursor getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
  if(package.boolValue || hidden.boolValue || link.boolValue)return NO;
 }
 return YES;
}
- (void)scan:(SHRoot *)r {
 if([self cancelled:r.identifier])return;
 if(![self validate:r]){r.count=0;[self reconcileCoverage];[self publish:YES];return;}
 // Selected file roots can subsume each other; app-only roots cannot cover files.
 if(!r.apps)for(SHRoot *other in _roots)if([self root:r coveredBy:other]){r.entries=nil;r.count=0;r.state=[@"Covered by " stringByAppendingString:other.path];[r.monitor stop];r.monitor=nil;[self publish:YES];return;}
 r.state=@"Indexing";r.count=0;[self publish:NO];
 NSTimeInterval started=NSProcessInfo.processInfo.systemUptime;NSError *error=nil;
 NSArray *entries=[SHScanner scanURL:r.url applicationsOnly:r.apps excludeGenerated:_exclude excludingURLs:@[_stateURL] cancelled:^BOOL{return [self cancelled:r.identifier];} progress:^(NSUInteger count){r.count=count;[self publish:NO];} error:&error];
 if([self cancelled:r.identifier])return;
 if(entries && [_catalog replaceRoot:r.identifier entries:entries error:&error]){r.entries=[_catalog entriesForRoot:r.identifier];r.count=r.entries.count;dispatch_async(dispatch_get_main_queue(),^{[self->_hiddenRoots removeObject:r.identifier];});r.state=r.monitor?@"Ready":@"Partially indexed — refresh manually; watching unavailable";
  NSLog(@"Catalog scan: %lu entries, %.3f seconds",(unsigned long)r.count,NSProcessInfo.processInfo.systemUptime-started);
 }else{r.entries=nil;r.count=0;r.state=@"Partially indexed — access needed; previous catalog preserved";}
 [self reconcileCoverage];[self publish:YES];
}
- (void)addURLs:(NSArray<NSURL *> *)urls replacingRoot:(NSString *)rootID {if(rootID)[self invalidateRoot:rootID];dispatch_async(_worker,^{@autoreleasepool{
 for(NSURL *url in urls){NSError *error=nil;NSData *bookmark=[SHFolderAccess bookmarkForURL:url error:&error];if(!bookmark){self->_message=@"Could not save access to that folder. Select it again.";continue;}
  SHRoot *r=rootID?[self root:rootID]:nil;
  if(!r)for(SHRoot *existing in self->_roots)if(!existing.apps && [existing.path isEqual:url.path]){r=existing;break;}
  if(!r){r=SHRoot.new;r.identifier=NSUUID.UUID.UUIDString;[self->_roots addObject:r];}
  if(rootID){[r.monitor stop];r.monitor=nil;r.entries=nil;r.count=0;[self->_catalog removeRoot:r.identifier];}
  r.path=url.path;r.bookmark=bookmark;r.state=@"Waiting";[self clearCancellation:r.identifier];[self request:r.identifier];
 }
 [self save];[self publish:rootID!=nil];
 }});}
- (void)removeRoot:(NSString *)rootID {[self invalidateRoot:rootID];dispatch_async(_worker,^{SHRoot *r=[self root:rootID];if(!r || r.apps)return;[r.monitor stop];r.monitor=nil;[self->_roots removeObject:r];[self->_catalog removeRoot:rootID];[self save];[self publish:YES];for(SHRoot *other in self->_roots)if(!other.apps)[self request:other.identifier];});}
- (void)refresh {dispatch_async(_worker,^{for(SHRoot *r in self->_roots)[self request:r.identifier];});}
- (void)setExcludeGenerated:(BOOL)exclude {dispatch_async(_worker,^{self->_exclude=exclude;[self save];for(SHRoot *r in self->_roots)[self request:r.identifier];});}
@end
