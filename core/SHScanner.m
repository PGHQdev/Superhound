#import "SHScanner.h"
#import <sys/stat.h>
@implementation SHScanner
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 return [self scanURL:url applicationsOnly:apps excludeGenerated:exclude cancelled:nil progress:progress error:error];
}
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 return [self scanURL:url applicationsOnly:apps excludeGenerated:exclude excludingURLs:@[] cancelled:cancelled progress:progress error:error];
}
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude excludingURLs:(NSArray<NSURL *> *)ignored cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error {
 if(error)*error=nil;
 url=url.URLByResolvingSymlinksInPath;
 NSFileManager *fm=NSFileManager.defaultManager;
 NSNumber *directory=nil;
 if(![url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:error] || !directory.boolValue || ![fm isReadableFileAtPath:url.path]){if(error && !*error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:EACCES userInfo:nil];return nil;}
 NSArray *keys=@[NSURLIsDirectoryKey,NSURLIsSymbolicLinkKey,NSURLIsPackageKey,NSURLIsHiddenKey,NSURLIsUbiquitousItemKey,NSURLUbiquitousItemDownloadingStatusKey];
 __block NSError *failure=nil;
 NSDirectoryEnumerator *enumerator=[fm enumeratorAtURL:url includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants errorHandler:^BOOL(NSURL *bad,NSError *e){(void)bad;failure=e;return NO;}];
 if(!enumerator){if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];return nil;}
 NSMutableSet *ignoredPaths=NSMutableSet.set;for(NSURL *ignoredURL in ignored)[ignoredPaths addObject:ignoredURL.URLByResolvingSymlinksInPath.path];
 if([ignoredPaths containsObject:url.path])return @[];
 NSSet *excluded=[NSSet setWithArray:@[@".git",@"node_modules",@"vendor",@"build",@"dist",@"DerivedData"]];
 NSMutableArray *entries=NSMutableArray.array;
 NSUInteger visited=0;
 for(NSURL *entry in enumerator){@autoreleasepool{
  if(cancelled && cancelled()){failure=[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];break;}
  NSDictionary *values=[entry resourceValuesForKeys:keys error:&failure];if(!values)break;
  NSString *name=entry.lastPathComponent;BOOL dir=[values[NSURLIsDirectoryKey] boolValue],link=[values[NSURLIsSymbolicLinkKey] boolValue];
  if(dir && !link && [ignoredPaths containsObject:entry.URLByResolvingSymlinksInPath.path]){[enumerator skipDescendants];continue;}
  struct stat st;BOOL dataless=lstat(entry.fileSystemRepresentation,&st)==0 && (st.st_flags&SF_DATALESS);
  if(dataless || ([values[NSURLIsUbiquitousItemKey] boolValue] && [values[NSURLUbiquitousItemDownloadingStatusKey] isEqual:NSURLUbiquitousItemDownloadingStatusNotDownloaded])){if(dir)[enumerator skipDescendants];continue;}
  if(link && dir)[enumerator skipDescendants];
  if(dir && exclude && [excluded containsObject:name]){[enumerator skipDescendants];continue;}
  BOOL application=dir && !link && [name.pathExtension.lowercaseString isEqual:@"app"];
  if(application || [values[NSURLIsPackageKey] boolValue])[enumerator skipDescendants];
  if(!apps || application){
   NSString *alias=@"",*display=application?name.stringByDeletingPathExtension:name;
   if(application){NSBundle *bundle=[NSBundle bundleWithURL:entry];id label=[bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]?:[bundle objectForInfoDictionaryKey:@"CFBundleName"];if([label isKindOfClass:NSString.class] && [label length]){alias=display;display=label;}}
   NSArray *components=entry.path.pathComponents;
   NSString *relative=[NSString pathWithComponents:[components subarrayWithRange:NSMakeRange(components.count-enumerator.level,enumerator.level)]];
   [entries addObject:@{@"relative":relative,@"name":display,@"path":entry.path,@"type":application?@"app":link?@"link":dir?@"folder":@"file",@"alias":alias}];
  }
  visited++;if(progress && visited%256==0)progress(entries.count);
 }}
 if(failure){if(error)*error=failure;return nil;}
 if(progress)progress(entries.count);return entries;
}
@end
