#import "SHScanner.h"
#import <sys/stat.h>
static NSString *BundleName(NSBundle *bundle){id label=[bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]?:[bundle objectForInfoDictionaryKey:@"CFBundleName"];return [label isKindOfClass:NSString.class] && [label length]?label:nil;}
// Names people still type for a built-in app: its name in an older macOS, or the Windows app that does the same job.
// The bundle identifier picks the app, so the names also work when macOS shows the app in another language.
static NSString *OtherNames(NSBundle *bundle){
 static NSDictionary<NSString *,NSString *> *names;static dispatch_once_t once;
 dispatch_once(&once,^{names=@{@"com.apple.systempreferences":@"System Preferences / Control Panel",@"com.apple.AddressBook":@"Address Book",@"com.apple.iCal":@"iCal",@"com.apple.Music":@"iTunes",@"com.apple.Photos":@"iPhoto",@"com.apple.iBooksX":@"iBooks",
  @"com.apple.findmy":@"Find My iPhone",@"com.apple.MobileSMS":@"iMessage / SMS",@"com.apple.ActivityMonitor":@"Task Manager",@"com.apple.TextEdit":@"Notepad",@"com.apple.finder":@"File Explorer",@"com.apple.Terminal":@"Command Prompt",
  @"com.apple.screenshot.launcher":@"Snipping Tool",@"com.apple.DiskUtility":@"Disk Management"};});
 NSString *identifier=bundle.bundleIdentifier;return identifier?names[identifier]:nil;
}
// An application's shown name and alias. The alias holds the file name when the bundle shows another name, then the other names.
static NSArray<NSString *> *ApplicationNames(NSURL *url,NSString *file){
 NSBundle *bundle=[NSBundle bundleWithURL:url];NSString *label=BundleName(bundle),*other=OtherNames(bundle);NSMutableArray *alias=NSMutableArray.array;
 if(label && ![label isEqual:file])[alias addObject:file];if(other)[alias addObject:other];
 return @[label?:file,[alias componentsJoinedByString:@" / "]];
}
// A System Settings pane is an extension bundle; returns its name and alias, or nil for any other bundle.
// Some panes have no name of their own: sidebar variants chosen by the hardware, such as Energy and Battery, name them.
// The headphone pane takes the name of each connected headphone at run time, so it has no name to search.
static NSArray<NSString *> *SettingsPane(NSURL *url){
 NSBundle *bundle=[NSBundle bundleWithURL:url];NSDictionary *attributes=bundle.infoDictionary[@"EXAppExtensionAttributes"];
 if(![attributes isKindOfClass:NSDictionary.class] || ![attributes[@"EXExtensionPointIdentifier"] isEqual:@"com.apple.Settings.extension.ui"] || [bundle.bundleIdentifier isEqual:@"com.apple.HeadphoneSettings"])return nil;
 NSDictionary *settings=attributes[@"SettingsExtensionAttributes"];NSArray *representations=[settings isKindOfClass:NSDictionary.class]?settings[@"representations"]:nil;NSMutableArray *variants=NSMutableArray.array;
 if([representations isKindOfClass:NSArray.class])for(NSDictionary *r in representations){NSString *key=[r isKindOfClass:NSDictionary.class]?r[@"sidebar-name"]:nil;if(![key isKindOfClass:NSString.class])continue;NSString *label=[bundle localizedStringForKey:key value:nil table:nil];if(label.length && ![variants containsObject:label])[variants addObject:label];}
 NSString *file=url.lastPathComponent.stringByDeletingPathExtension,*name=BundleName(bundle)?:file,*joined=[variants componentsJoinedByString:@" / "];
 if([name isEqual:file] && variants.count && ![variants containsObject:name])return @[joined,file];
 NSString *alias=variants.count && ![joined isEqual:name]?joined:[file isEqual:name]?@"":file;return @[name,alias];
}
@implementation SHScanner
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 return [self scanURL:url applicationsOnly:apps excludeGenerated:exclude cancelled:nil progress:progress error:error];
}
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 return [self scanURL:url applicationsOnly:apps excludeGenerated:exclude excludingURLs:@[] cancelled:cancelled progress:progress error:error];
}
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude excludingURLs:(NSArray<NSURL *> *)ignored cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 return [self scanURL:url applicationsOnly:apps excludeGenerated:exclude excludingURLs:ignored shallow:NO cancelled:cancelled progress:progress error:error];
}
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude excludingURLs:(NSArray<NSURL *> *)ignored shallow:(BOOL)shallow cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 if(error)*error=nil;
 url=url.URLByResolvingSymlinksInPath;
 NSFileManager *fm=NSFileManager.defaultManager;
 NSNumber *directory=nil;
 if(![url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:error] || !directory.boolValue || ![fm isReadableFileAtPath:url.path]){if(error && !*error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:EACCES userInfo:nil];return nil;}
 // A root can be one application, such as Finder, which lives among system helpers in CoreServices.
 if([url.pathExtension.lowercaseString isEqual:@"app"]){NSArray *names=ApplicationNames(url,url.lastPathComponent.stringByDeletingPathExtension);
  if(progress)progress(1);return @[@{@"relative":url.lastPathComponent,@"name":names[0],@"path":url.path,@"type":@"app",@"alias":names[1]}];}
 NSArray *keys=@[NSURLIsDirectoryKey,NSURLIsSymbolicLinkKey,NSURLIsPackageKey,NSURLIsHiddenKey,NSURLIsUbiquitousItemKey,NSURLUbiquitousItemDownloadingStatusKey];
 __block NSError *failure=nil;
 NSDirectoryEnumerator *enumerator=[fm enumeratorAtURL:url includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants|(shallow?NSDirectoryEnumerationSkipsSubdirectoryDescendants:0) errorHandler:^BOOL(NSURL *bad,NSError *e){(void)bad;failure=e;return NO;}];
 if(!enumerator){if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];return nil;}
 NSMutableSet *ignoredPaths=NSMutableSet.set;for(NSURL *ignoredURL in ignored)[ignoredPaths addObject:ignoredURL.URLByResolvingSymlinksInPath.path];
 if([ignoredPaths containsObject:url.path])return @[];
 NSSet *excluded=[NSSet setWithArray:@[@".git",@"node_modules",@"vendor",@"build",@"dist",@"DerivedData"]];
 NSMutableArray *entries=NSMutableArray.array;
 NSUInteger visited=0;
 // nextObject runs inside the pool; fast enumeration would keep every visited URL and its resource values until the scan ends.
 for(;;){@autoreleasepool{NSURL *entry=[enumerator nextObject];if(!entry)break;
  if(cancelled && cancelled()){failure=[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];break;}
  NSDictionary *values=[entry resourceValuesForKeys:keys error:&failure];if(!values)break;
  NSString *name=entry.lastPathComponent;BOOL dir=[values[NSURLIsDirectoryKey] boolValue],link=[values[NSURLIsSymbolicLinkKey] boolValue];
  if(dir && !link && [ignoredPaths containsObject:entry.URLByResolvingSymlinksInPath.path]){[enumerator skipDescendants];continue;}
  struct stat st;BOOL dataless=lstat(entry.fileSystemRepresentation,&st)==0 && (st.st_flags&SF_DATALESS);
  if(dataless || ([values[NSURLIsUbiquitousItemKey] boolValue] && [values[NSURLUbiquitousItemDownloadingStatusKey] isEqual:NSURLUbiquitousItemDownloadingStatusNotDownloaded])){if(dir)[enumerator skipDescendants];continue;}
  if(link && dir)[enumerator skipDescendants];
  if(dir && exclude && [excluded containsObject:name]){[enumerator skipDescendants];continue;}
  BOOL application=dir && !link && [name.pathExtension.lowercaseString isEqual:@"app"];
  // macOS installs Safari as a symbolic link to its bundle; a linked application is still an application.
  if(link && [name.pathExtension.lowercaseString isEqual:@"app"]){NSNumber *target=nil;[entry.URLByResolvingSymlinksInPath getResourceValue:&target forKey:NSURLIsDirectoryKey error:nil];application=target.boolValue;}
  NSArray *pane=dir && !link && [name.pathExtension.lowercaseString isEqual:@"appex"]?SettingsPane(entry):nil;
  if(dir && (application || [values[NSURLIsPackageKey] boolValue]))[enumerator skipDescendants];
  if(!apps || application || pane){
   NSString *alias=@"",*display=application?name.stringByDeletingPathExtension:name;
   if(application){NSArray *names=ApplicationNames(entry.URLByResolvingSymlinksInPath,display);display=names[0];alias=names[1];}
   if(pane){display=pane[0];alias=pane[1];}
   NSArray *components=entry.path.pathComponents;
   NSString *relative=[NSString pathWithComponents:[components subarrayWithRange:NSMakeRange(components.count-enumerator.level,enumerator.level)]];
   [entries addObject:@{@"relative":relative,@"name":display,@"path":entry.path,@"type":application?@"app":pane?@"settings":link?@"link":dir?@"folder":@"file",@"alias":alias}];
  }
  visited++;if(progress && visited%256==0)progress(entries.count);
 }}
 if(failure){if(error)*error=failure;return nil;}
 // Finder keeps All My Files as an older bundle that also shows as Recents; an application whose file has the shown name wins.
 if(apps){BOOL (^shown)(NSDictionary *)=^BOOL(NSDictionary *e){return [[e[@"relative"] lastPathComponent].stringByDeletingPathExtension isEqual:e[@"name"]];};
  NSMutableSet *exact=NSMutableSet.set;for(NSDictionary *e in entries)if([e[@"type"] isEqual:@"app"] && shown(e))[exact addObject:[[e[@"relative"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:e[@"name"]]];
  [entries filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e,NSDictionary *bindings){(void)bindings;return ![e[@"type"] isEqual:@"app"] || shown(e) || ![exact containsObject:[[e[@"relative"] stringByDeletingLastPathComponent] stringByAppendingPathComponent:e[@"name"]]];}]];}
 if(progress)progress(entries.count);return entries;
}
@end
