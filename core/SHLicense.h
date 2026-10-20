#import <Foundation/Foundation.h>
// The license of this Mac: the license key and a token that superhound.app signed for this device. Main thread only.
// Token: base64url(payload JSON) "." base64url(ECDSA P-256 SHA-256 signature of the first part, r and s concatenated).
// Payload: v (1), lid (the license key id), dev (the device ID), iat (the issue time).
@interface SHLicense : NSObject
// publicKey: an uncompressed P-256 point (65 bytes). device: SHLicenseDevice of this Mac.
- (instancetype)initWithURL:(NSURL *)url publicKey:(NSData *)publicKey device:(NSString *)device;
@property(nonatomic,readonly) NSString *device;
// YES when the saved token verifies for this device.
@property(nonatomic,readonly) BOOL licensed;
// The saved license key, or nil when unlicensed.
@property(nonatomic,readonly) NSString *key;
// The payload when the public key signed the token and the token names this device; nil otherwise.
- (NSDictionary *)verify:(NSString *)token;
// Saves the key and the token when the token verifies; NO, and nothing saved, otherwise.
- (BOOL)saveKey:(NSString *)key token:(NSString *)token;
- (void)remove;
@end
// The device ID: SHA-256 of "superhound:" and the hardware UUID, as 64 lowercase hex digits. The UUID never leaves the Mac.
NSString *SHLicenseDevice(NSString *hardwareUUID);
