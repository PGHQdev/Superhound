#import "SHLicense.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#include <fcntl.h>
#include <unistd.h>
static NSData *SHA256(NSData *data){NSMutableData *digest=[NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest.mutableBytes);return digest;}
static NSData *Base64URL(NSString *text){
 if(!text.length || [text rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"].invertedSet].location!=NSNotFound)return nil;
 NSMutableString *t=[[[text stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"] mutableCopy];while(t.length%4)[t appendString:@"="];
 return [[NSData alloc] initWithBase64EncodedString:t options:0];
}
NSString *SHLicenseDevice(NSString *hardwareUUID){
 NSData *digest=SHA256([[@"superhound:" stringByAppendingString:hardwareUUID?:@""] dataUsingEncoding:NSUTF8StringEncoding]);const uint8_t *b=digest.bytes;
 NSMutableString *hex=NSMutableString.string;for(NSUInteger i=0;i<digest.length;i++)[hex appendFormat:@"%02x",b[i]];return hex;
}
@implementation SHLicense {NSURL *_url;SecKeyRef _public;NSString *_key;}
- (instancetype)initWithURL:(NSURL *)url publicKey:(NSData *)publicKey device:(NSString *)device {
 if((self=[super init])){
  _url=url;_device=[device copy];
  _public=publicKey.length==65?SecKeyCreateWithData((__bridge CFDataRef)publicKey,(__bridge CFDictionaryRef)@{(id)kSecAttrKeyType:(id)kSecAttrKeyTypeECSECPrimeRandom,(id)kSecAttrKeyClass:(id)kSecAttrKeyClassPublic,(id)kSecAttrKeySizeInBits:@256},NULL):NULL;
  NSData *data=[NSData dataWithContentsOfURL:url];NSDictionary *saved=data?[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil]:nil;
  if([saved isKindOfClass:NSDictionary.class] && [saved[@"key"] isKindOfClass:NSString.class] && [saved[@"token"] isKindOfClass:NSString.class] && [self verify:saved[@"token"]])_key=saved[@"key"];
 }
 return self;
}
- (void)dealloc {if(_public)CFRelease(_public);}
- (BOOL)licensed {return _key!=nil;}
- (NSString *)key {return _key;}
- (NSDictionary *)verify:(NSString *)token {
 NSArray<NSString *> *parts=[token componentsSeparatedByString:@"."];if(!_public || parts.count!=2)return nil;
 NSData *body=Base64URL(parts[0]),*signature=Base64URL(parts[1]);if(!body || signature.length!=64)return nil;
 if(!SecKeyVerifySignature(_public,kSecKeyAlgorithmECDSASignatureDigestRFC4754,(__bridge CFDataRef)SHA256([parts[0] dataUsingEncoding:NSASCIIStringEncoding]),(__bridge CFDataRef)signature,NULL))return nil;
 NSDictionary *payload=[NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
 if(![payload isKindOfClass:NSDictionary.class] || ![payload[@"v"] isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)payload[@"v"])==CFBooleanGetTypeID() || ![payload[@"v"] isEqual:@1] || ![payload[@"lid"] isKindOfClass:NSString.class] || ![payload[@"lid"] length] || ![payload[@"dev"] isKindOfClass:NSString.class] || ![payload[@"dev"] isEqual:_device])return nil;
 return payload;
}
// The key is private, so the file is created readable only by the user, then renamed over the previous one.
- (BOOL)saveKey:(NSString *)key token:(NSString *)token {
 if(!key.length || ![self verify:token])return NO;
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"key":key,@"token":token} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];if(!data)return NO;
 [NSFileManager.defaultManager createDirectoryAtURL:_url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
 NSString *temp=[_url.path stringByAppendingFormat:@".%@",NSUUID.UUID.UUIDString];int fd=open(temp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL,0600);if(fd<0)return NO;
 BOOL written=write(fd,data.bytes,data.length)==(ssize_t)data.length;if(fsync(fd)!=0)written=NO;if(close(fd)!=0)written=NO;
 if(!written || rename(temp.fileSystemRepresentation,_url.fileSystemRepresentation)!=0){unlink(temp.fileSystemRepresentation);return NO;}
 _key=[key copy];return YES;
}
- (void)remove {unlink(_url.fileSystemRepresentation);_key=nil;}
@end
