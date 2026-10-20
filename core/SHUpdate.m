#import "SHUpdate.h"
#import <CommonCrypto/CommonDigest.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
// https, or http on this Mac for a local test server.
static BOOL Safe(id text){
 NSURLComponents *url=[text isKindOfClass:NSString.class]?[NSURLComponents componentsWithString:text]:nil;if(!url.host.length || url.user || url.password)return NO;
 return [url.scheme isEqual:@"https"] || ([url.scheme isEqual:@"http"] && url.port && [@[@"127.0.0.1",@"localhost"] containsObject:url.host]);
}
@implementation SHRelease
+ (instancetype)releaseWithJSON:(NSData *)data {
 NSDictionary *d=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;if(![d isKindOfClass:NSDictionary.class])return nil;
 id version=d[@"version"],build=d[@"build"],url=d[@"url"],sha=d[@"sha256"],notes=d[@"notes"];
 if(![version isKindOfClass:NSString.class] || ![version length] || [version length]>32 || ![build isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)build)==CFBooleanGetTypeID() || [build doubleValue]!=[build integerValue] || [build integerValue]<1)return nil;
 if(!Safe(url) || !Safe(notes) || ![sha isKindOfClass:NSString.class] || [sha length]!=64 || [sha rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location!=NSNotFound)return nil;
 SHRelease *r=self.new;r->_version=version;r->_build=[build integerValue];r->_url=[NSURL URLWithString:url];r->_notes=[NSURL URLWithString:notes];r->_sha256=sha;return r.url && r.notes?r:nil;
}
@end
BOOL SHUpdateDue(NSDate *last,NSDate *now){return !last || [now timeIntervalSinceDate:last]>=86400 || [now timeIntervalSinceDate:last]<0;}
static NSString *SHA256Hex(NSURL *file){
 NSData *data=[NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:nil];if(!data)return nil;
 uint8_t digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
 NSMutableString *hex=NSMutableString.string;for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",digest[i]];return hex;
}
// A new directory next to the installed app, so the moves stay on one volume.
static NSURL *NextTo(NSURL *installed,NSString *prefix){
 char *path=strdup([installed.URLByDeletingLastPathComponent URLByAppendingPathComponent:[prefix stringByAppendingString:@".XXXXXX"]].fileSystemRepresentation);
 NSURL *url=mkdtemp(path)?[NSURL fileURLWithFileSystemRepresentation:path isDirectory:YES relativeToURL:nil]:nil;free(path);return url;
}
NSString *SHUpdateInstall(NSURL *zip,SHRelease *release,NSURL *installed,SecRequirementRef requirement){
 NSNumber *linked=nil;[installed getResourceValue:&linked forKey:NSURLIsSymbolicLinkKey error:nil];
 if(linked.boolValue)return [NSString stringWithFormat:@"%@ is a link, so Superhound cannot replace it. Run the install command from superhound.app instead.",installed.path];
 if(release.build<=[[NSDictionary dictionaryWithContentsOfURL:[installed URLByAppendingPathComponent:@"Contents/Info.plist"]][@"CFBundleVersion"] integerValue])return @"This version is not newer than the installed one.";
 if(![SHA256Hex(zip) isEqual:release.sha256])return @"The download does not match the published checksum.";
 NSURL *work=NextTo(installed,@".superhound-update");if(!work)return [NSString stringWithFormat:@"Superhound cannot write to %@. Run the install command from superhound.app instead.",installed.URLByDeletingLastPathComponent.path];
 NSString *message=nil;NSURL *fresh=[work URLByAppendingPathComponent:@"Superhound.app"];
 NSTask *ditto=NSTask.new;ditto.executableURL=[NSURL fileURLWithPath:@"/usr/bin/ditto"];ditto.arguments=@[@"-x",@"-k",zip.path,work.path];ditto.standardError=NSFileHandle.fileHandleWithNullDevice;
 if(![ditto launchAndReturnError:nil])message=@"The download could not be unpacked.";else{[ditto waitUntilExit];if(ditto.terminationStatus!=0)message=@"The download could not be unpacked.";}
 NSDictionary *info=message?nil:[NSDictionary dictionaryWithContentsOfURL:[fresh URLByAppendingPathComponent:@"Contents/Info.plist"]],*current=[NSDictionary dictionaryWithContentsOfURL:[installed URLByAppendingPathComponent:@"Contents/Info.plist"]];
 NSNumber *link=nil;[fresh getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];if(!message && link.boolValue)message=@"The download is not the expected version of Superhound.";
 if(!message && (![info[@"CFBundleIdentifier"] isEqual:current[@"CFBundleIdentifier"]] || [info[@"CFBundleVersion"] integerValue]!=release.build))message=@"The download is not the expected version of Superhound.";
 if(!message){
  SecStaticCodeRef code=NULL;OSStatus status=SecStaticCodeCreateWithPath((__bridge CFURLRef)fresh,kSecCSDefaultFlags,&code);
  if(status==errSecSuccess)status=SecStaticCodeCheckValidity(code,kSecCSStrictValidate|kSecCSCheckAllArchitectures|kSecCSCheckNestedCode,requirement);
  if(code)CFRelease(code);if(status!=errSecSuccess)message=@"The download does not have the Superhound signature.";
 }
 NSURL *backup=message?nil:NextTo(installed,@".superhound-backup");if(!message && !backup)message=@"Superhound cannot keep a copy of the current version.";
 if(!message){
  NSURL *previous=[backup URLByAppendingPathComponent:@"previous.app"];
  if(rename(installed.fileSystemRepresentation,previous.fileSystemRepresentation)!=0)message=@"Superhound cannot move the current version.";
  else if(rename(fresh.fileSystemRepresentation,installed.fileSystemRepresentation)!=0){rename(previous.fileSystemRepresentation,installed.fileSystemRepresentation);message=@"Superhound cannot put the new version in place.";}
  if(message)[NSFileManager.defaultManager removeItemAtURL:backup error:nil];
 }
 [NSFileManager.defaultManager removeItemAtURL:work error:nil];return message;
}
