#import <Foundation/Foundation.h>
// Web addresses typed in the search field. Superhound only builds the URL; the browser loads it.
@interface SHWeb : NSObject
// Returns nil unless the whole query is one web address: an http or https URL, localhost or an IPv4 address, or a host with a common web domain ending.
// Keys: type "url", id "url", name (the address as typed), url (the URL to open).
+ (NSDictionary *)addressForQuery:(NSString *)query;
@end
