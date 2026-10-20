#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import "SHLicense.h"
#include <assert.h>
#include <sys/stat.h>
static NSString *B64URL(NSData *d){return [[[[d base64EncodedStringWithOptions:0] stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"=" withString:@""];}
// Signs like the Worker: ECDSA P-256 over SHA-256 of the first part, r and s concatenated.
static NSString *Token(SecKeyRef key,id payload){
 NSString *body=B64URL([NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]);NSData *data=[body dataUsingEncoding:NSASCIIStringEncoding];NSMutableData *digest=[NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest.mutableBytes);
 NSData *signature=CFBridgingRelease(SecKeyCreateSignature(key,kSecKeyAlgorithmECDSASignatureDigestRFC4754,(__bridge CFDataRef)digest,NULL));assert(signature.length==64);
 return [NSString stringWithFormat:@"%@.%@",body,B64URL(signature)];
}
int main(void){@autoreleasepool{
 // The device ID is SHA-256 of "superhound:" and the hardware UUID.
 assert([SHLicenseDevice(@"ABC") isEqual:@"ec0c982239afabc0159df3af51b13c03418a65c0a7aa46a70f41711ce01f77a7"]);assert(![SHLicenseDevice(@"ABD") isEqual:SHLicenseDevice(@"ABC")]);
 NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];NSURL *file=[tmp URLByAppendingPathComponent:@"license.plist"];
 // A token signed by WebCrypto in Node with a throwaway key, as the Worker signs.
 NSString *dev=[@"" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0];
 NSData *webPublic=[[NSData alloc] initWithBase64EncodedString:@"BMbFX6KB5LZhapuTVkeIlXMEUEN1YfsFE0Ve0q6gBkSSplZQKi+sSVTPfswfi3OkcFTM+Di5TJMfEk5MVTdCu/I=" options:0];
 NSString *webToken=@"eyJ2IjoxLCJsaWQiOiJsa190ZXN0IiwiZGV2IjoiYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYSIsImlhdCI6MTc2MDAwMDAwMH0.dlj4LkmD0rxBnrbGDMOaFKhTz70Olg1jJ3PPPUK7LPXFErJnjXinjnN7hLIgUs4-EPF3RqhJZlYC1FIIRv_UNw";
 SHLicense *web=[[SHLicense alloc] initWithURL:file publicKey:webPublic device:dev];assert(!web.licensed && !web.key);
 NSDictionary *payload=[web verify:webToken];assert([payload[@"lid"] isEqual:@"lk_test"] && [payload[@"iat"] isEqual:@1760000000]);
 assert(![[[SHLicense alloc] initWithURL:file publicKey:webPublic device:SHLicenseDevice(@"other")] verify:webToken]);
 // Damaged tokens.
 NSArray *parts=[webToken componentsSeparatedByString:@"."];NSString *flipped=[parts[1] hasPrefix:@"A"]?[@"B" stringByAppendingString:[parts[1] substringFromIndex:1]]:[@"A" stringByAppendingString:[parts[1] substringFromIndex:1]];
 for(NSString *bad in @[@"",@".",parts[0],[NSString stringWithFormat:@"%@.%@",parts[0],flipped],[NSString stringWithFormat:@"%@.%@.x",parts[0],parts[1]],[NSString stringWithFormat:@"%@x.%@",parts[0],parts[1]],[NSString stringWithFormat:@"%@.%@",parts[0],[parts[1] substringToIndex:40]],[NSString stringWithFormat:@"%@=.%@",parts[0],parts[1]],[webToken stringByAppendingString:@"="]])assert(![web verify:bad]);
 // A wrong public key never verifies.
 assert(![[[SHLicense alloc] initWithURL:file publicKey:[NSData dataWithBytes:"short" length:5] device:dev] verify:webToken]);
 // Payload rules, with a key made here.
 SecKeyRef private=SecKeyCreateRandomKey((__bridge CFDictionaryRef)@{(id)kSecAttrKeyType:(id)kSecAttrKeyTypeECSECPrimeRandom,(id)kSecAttrKeySizeInBits:@256},NULL);assert(private);
 SecKeyRef public=SecKeyCopyPublicKey(private);NSData *publicData=CFBridgingRelease(SecKeyCopyExternalRepresentation(public,NULL));CFRelease(public);assert(publicData.length==65);
 SHLicense *license=[[SHLicense alloc] initWithURL:file publicKey:publicData device:dev];
 assert([license verify:Token(private,@{@"v":@1,@"lid":@"lk_1",@"dev":dev,@"iat":@1})]);
 assert(![license verify:Token(private,@{@"v":@2,@"lid":@"lk_1",@"dev":dev})]);assert(![license verify:Token(private,@{@"v":@YES,@"lid":@"lk_1",@"dev":dev})]);assert(![license verify:Token(private,@{@"v":@"1",@"lid":@"lk_1",@"dev":dev})]);assert(![license verify:Token(private,@{@"v":@1,@"dev":dev})]);assert(![license verify:Token(private,@{@"v":@1,@"lid":@"",@"dev":dev})]);
 assert(![license verify:Token(private,@{@"v":@1,@"lid":@1,@"dev":dev})]);assert(![license verify:Token(private,@{@"v":@1,@"lid":@"lk_1",@"dev":@"b"})]);assert(![license verify:Token(private,@[@1])]);
 assert(![web verify:Token(private,@{@"v":@1,@"lid":@"lk_1",@"dev":dev})]);
 // Saving: a bad token saves nothing; a good one survives a new instance, readable only by the user.
 assert(![license saveKey:@"SUPERHOUND-KEY" token:webToken] && !license.licensed);assert(![NSFileManager.defaultManager fileExistsAtPath:file.path]);
 NSString *token=Token(private,@{@"v":@1,@"lid":@"lk_1",@"dev":dev,@"iat":@1});assert(![license saveKey:@"" token:token]);
 assert([license saveKey:@"SUPERHOUND-KEY" token:token] && license.licensed && [license.key isEqual:@"SUPERHOUND-KEY"]);
 struct stat st;assert(stat(file.fileSystemRepresentation,&st)==0 && (st.st_mode&0777)==0600);
 assert([[[SHLicense alloc] initWithURL:file publicKey:publicData device:dev].key isEqual:@"SUPERHOUND-KEY"]);
 // The same file on another Mac, or checked with another public key, is unlicensed.
 assert(![[SHLicense alloc] initWithURL:file publicKey:publicData device:SHLicenseDevice(@"other")].licensed);assert(![[SHLicense alloc] initWithURL:file publicKey:webPublic device:dev].licensed);
 assert([[NSFileManager.defaultManager contentsOfDirectoryAtPath:tmp.path error:nil] isEqual:@[@"license.plist"]]);
 // A damaged file is unlicensed; removal deletes the file.
 [license remove];assert(!license.licensed && !license.key && ![NSFileManager.defaultManager fileExistsAtPath:file.path]);
 assert([[NSData dataWithBytes:"not a plist" length:11] writeToURL:file atomically:YES]);assert(![[SHLicense alloc] initWithURL:file publicKey:publicData device:dev].licensed);
 assert(([[NSPropertyListSerialization dataWithPropertyList:@{@"key":@1,@"token":token} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil] writeToURL:file atomically:YES]));assert(![[SHLicense alloc] initWithURL:file publicKey:publicData device:dev].licensed);
 CFRelease(private);[NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
 puts("PASS license: device ID, WebCrypto token, damaged tokens, payload rules, other device and key, saved file, removal");
}return 0;}
