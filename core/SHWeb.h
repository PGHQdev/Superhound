#import <Foundation/Foundation.h>
// Web addresses and web searches from the search field. Superhound only builds the URL; the browser loads it.
@interface SHWeb : NSObject
// Returns nil unless the whole query is one web address: an http or https URL, localhost or an IPv4 address, or a host with a common web domain ending.
// Keys: type "url", id "url", name (the address as typed), url (the URL to open).
+ (NSDictionary *)addressForQuery:(NSString *)query;
// The search engines as id, name, and url (the text goes at its end), the default first. The defaults key searchEngine holds the chosen id.
+ (NSArray<NSDictionary *> *)engines;
// Returns nil for an empty query; an unknown engine id gives the default engine.
// Keys: type "web", id "web", name (the row text), url (the search to open).
+ (NSDictionary *)searchForQuery:(NSString *)query engine:(NSString *)engine;
@end
