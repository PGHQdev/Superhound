#import <Foundation/Foundation.h>
#import "SHUpdate.h"
#include <assert.h>
#include <sys/stat.h>
static int Run(NSString *tool,NSArray *arguments){NSTask *t=NSTask.new;t.executableURL=[NSURL fileURLWithPath:tool];t.arguments=arguments;t.standardError=NSFileHandle.fileHandleWithNullDevice;t.standardOutput=NSFileHandle.fileHandleWithNullDevice;assert([t launchAndReturnError:nil]);[t waitUntilExit];return t.terminationStatus;}
// A signed bundle named Superhound.app with identifier com.superhound.test and the given build, zipped the way scripts/release.sh does.
static NSURL *Zip(NSURL *dir,NSString *name,NSInteger build,BOOL tamper){
 NSURL *stage=[dir URLByAppendingPathComponent:[name stringByAppendingString:@"-stage"]],*app=[stage URLByAppendingPathComponent:@"Superhound.app"],*zip=[dir URLByAppendingPathComponent:[name stringByAppendingString:@".zip"]];
 assert([NSFileManager.defaultManager createDirectoryAtURL:[app URLByAppendingPathComponent:@"Contents/MacOS"] withIntermediateDirectories:YES attributes:nil error:nil]);
 assert(([@{@"CFBundleIdentifier":@"com.superhound.test",@"CFBundleExecutable":@"Superhound",@"CFBundleVersion":[NSString stringWithFormat:@"%ld",(long)build],@"CFBundlePackageType":@"APPL"} writeToURL:[app URLByAppendingPathComponent:@"Contents/Info.plist"] error:nil]));
 assert([NSFileManager.defaultManager copyItemAtURL:[NSURL fileURLWithPath:@"/usr/bin/true"] toURL:[app URLByAppendingPathComponent:@"Contents/MacOS/Superhound"] error:nil]);
 assert(Run(@"/usr/bin/codesign",@[@"--force",@"--sign",@"-",@"--timestamp=none",app.path])==0);
 if(tamper)assert([@"changed" writeToURL:[app URLByAppendingPathComponent:@"Contents/Resources.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil]);
 assert(Run(@"/usr/bin/ditto",@[@"-c",@"-k",@"--keepParent",app.path,zip.path])==0);return zip;
}
static SHRelease *Release(NSURL *zip,NSInteger build){
 NSTask *t=NSTask.new;t.executableURL=[NSURL fileURLWithPath:@"/usr/bin/shasum"];t.arguments=@[@"-a",@"256",zip.path];NSPipe *p=NSPipe.pipe;t.standardOutput=p;assert([t launchAndReturnError:nil]);NSData *out=[p.fileHandleForReading readDataToEndOfFile];[t waitUntilExit];
 NSString *sha=[[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];sha=[sha substringToIndex:64];
 return [SHRelease releaseWithJSON:[NSJSONSerialization dataWithJSONObject:@{@"version":@"9.9",@"build":@(build),@"url":@"https://example.com/Superhound.zip",@"sha256":sha,@"notes":@"https://example.com/notes"} options:0 error:nil]];
}
static NSArray *Names(NSURL *dir){return [[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir.path error:nil] sortedArrayUsingSelector:@selector(compare:)];}
static NSString *Build(NSURL *app){return [NSDictionary dictionaryWithContentsOfURL:[app URLByAppendingPathComponent:@"Contents/Info.plist"]][@"CFBundleVersion"];}
int main(void){@autoreleasepool{
 // The release file.
 NSData *(^json)(NSDictionary *)=^(NSDictionary *d){return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];};
 NSDictionary *good=@{@"version":@"0.2.0",@"build":@35,@"url":@"https://github.com/PGHQdev/Superhound/releases/download/v0.2.0/Superhound.zip",@"sha256":[@"" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0],@"notes":@"https://github.com/PGHQdev/Superhound/releases/tag/v0.2.0"};
 SHRelease *r=[SHRelease releaseWithJSON:json(good)];assert(r && r.build==35 && [r.version isEqual:@"0.2.0"] && [r.url.host isEqual:@"github.com"] && [r.notes.path hasSuffix:@"v0.2.0"]);
 for(NSDictionary *change in @[@{@"build":@0},@{@"build":@"35"},@{@"build":@YES},@{@"build":@35.5},@{@"version":@""},@{@"version":@3},@{@"url":@"http://x/y.zip"},@{@"url":@"http://127.0.0.1.example.com/y.zip"},@{@"url":@"http://localhost/y.zip"},@{@"url":@"http://127.0.0.1:1@evil.example/y.zip"},@{@"url":@"https://user@example.com/y.zip"},@{@"url":@"https:///y.zip"},@{@"notes":@"ftp://x"},@{@"sha256":@"ABC"},@{@"sha256":[@"" stringByPaddingToLength:64 withString:@"A" startingAtIndex:0]}]){
  NSMutableDictionary *bad=good.mutableCopy;[bad addEntriesFromDictionary:change];assert(![SHRelease releaseWithJSON:json(bad)]);
 }
 NSMutableDictionary *local=good.mutableCopy;local[@"url"]=@"http://127.0.0.1:8797/Superhound.zip";assert([SHRelease releaseWithJSON:json(local)]);
 NSMutableDictionary *missing=good.mutableCopy;[missing removeObjectForKey:@"notes"];assert(![SHRelease releaseWithJSON:json(missing)]);
 assert(![SHRelease releaseWithJSON:nil] && ![SHRelease releaseWithJSON:[NSData dataWithBytes:"[1]" length:3]] && ![SHRelease releaseWithJSON:[NSData dataWithBytes:"x" length:1]]);
 // Once a day; a clock set back also allows a check.
 NSDate *now=NSDate.date;assert(SHUpdateDue(nil,now) && !SHUpdateDue([now dateByAddingTimeInterval:-3600],now) && SHUpdateDue([now dateByAddingTimeInterval:-86400],now) && SHUpdateDue([now dateByAddingTimeInterval:3600],now));
 // Installing.
 NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]],*apps=[tmp URLByAppendingPathComponent:@"Applications"],*installed=[apps URLByAppendingPathComponent:@"Superhound.app"];
 assert([NSFileManager.defaultManager createDirectoryAtURL:apps withIntermediateDirectories:YES attributes:nil error:nil]);
 NSURL *old=Zip(tmp,@"old",1,NO);assert(Run(@"/usr/bin/ditto",@[@"-x",@"-k",old.path,apps.path])==0);assert([Build(installed) isEqual:@"1"]);
 SecRequirementRef ours=NULL,other=NULL;assert(SecRequirementCreateWithString(CFSTR("identifier \"com.superhound.test\""),kSecCSDefaultFlags,&ours)==errSecSuccess);assert(SecRequirementCreateWithString(CFSTR("identifier \"com.superhound.other\""),kSecCSDefaultFlags,&other)==errSecSuccess);
 NSURL *next=Zip(tmp,@"next",2,NO),*tampered=Zip(tmp,@"tampered",2,YES);SHRelease *nextRelease=Release(next,2);
 // Each failure leaves the installed app and the folder as they were.
 assert([SHUpdateInstall(next,Release(old,2),installed,ours) containsString:@"checksum"]);
 assert([SHUpdateInstall(next,Release(next,3),installed,ours) containsString:@"expected version"]);
 assert([SHUpdateInstall(next,nextRelease,installed,other) containsString:@"signature"]);
 assert([SHUpdateInstall(tampered,Release(tampered,2),installed,ours) containsString:@"signature"]);
 assert([SHUpdateInstall(old,Release(old,1),installed,ours) containsString:@"not newer"]);
 NSURL *elsewhere=[tmp URLByAppendingPathComponent:@"Elsewhere.app"],*linked=[tmp URLByAppendingPathComponent:@"Linked.app"];assert([NSFileManager.defaultManager copyItemAtURL:installed toURL:elsewhere error:nil]);
 assert([NSFileManager.defaultManager createSymbolicLinkAtURL:linked withDestinationURL:elsewhere error:nil]);assert([SHUpdateInstall(next,nextRelease,linked,ours) containsString:@"is a link"]);assert([Build(elsewhere) isEqual:@"1"]);
 NSURL *junk=[tmp URLByAppendingPathComponent:@"junk.zip"];assert([@"not a zip" writeToURL:junk atomically:YES encoding:NSUTF8StringEncoding error:nil]);assert([SHUpdateInstall(junk,Release(junk,2),installed,ours) containsString:@"unpacked"]);
 assert([Build(installed) isEqual:@"1"]);assert([Names(apps) isEqual:@[@"Superhound.app"]]);
 // Success: the new app is in place and the previous one is kept, with no work folder left.
 assert(SHUpdateInstall(next,nextRelease,installed,ours)==nil);assert([Build(installed) isEqual:@"2"]);
 NSArray *names=Names(apps);assert(names.count==2 && [names[0] hasPrefix:@".superhound-backup."] && [names[1] isEqual:@"Superhound.app"]);
 assert([Build([[apps URLByAppendingPathComponent:names[0]] URLByAppendingPathComponent:@"previous.app"]) isEqual:@"1"]);
 // A folder Superhound cannot write to.
 assert(chmod(apps.fileSystemRepresentation,0555)==0);assert([SHUpdateInstall(next,Release(next,3),installed,ours) containsString:@"cannot write"]);assert(chmod(apps.fileSystemRepresentation,0755)==0);
 CFRelease(ours);CFRelease(other);[NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
 puts("PASS update: release file, daily check, checksum, version, signature, and the swap with a kept previous app");
}}
