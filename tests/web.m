#import <Foundation/Foundation.h>
#import "SHWeb.h"
#include <assert.h>
static void Opens(NSString *query,NSString *url) {
 NSDictionary *a=[SHWeb addressForQuery:query];
 if(![a[@"url"] isEqual:url]){fprintf(stderr,"'%s' gave '%s'\n",query.UTF8String,[a[@"url"] UTF8String]?:"nil");abort();}
}
int main(void){@autoreleasepool{
 Opens(@"github.com",@"https://github.com");Opens(@" superhound.app/docs ",@"https://superhound.app/docs");Opens(@"GitHub.com/PGHQdev/Superhound",@"https://GitHub.com/PGHQdev/Superhound");
 Opens(@"https://example.org/a?b=1#c",@"https://example.org/a?b=1#c");Opens(@"HTTP://Example.org",@"HTTP://Example.org");Opens(@"news.ycombinator.com",@"https://news.ycombinator.com");
 Opens(@"www.example.museum",@"https://www.example.museum");Opens(@"localhost:3000",@"http://localhost:3000");Opens(@"localhost:8080/api",@"http://localhost:8080/api");
 Opens(@"192.168.1.1",@"http://192.168.1.1");Opens(@"10.0.0.2:8443/admin",@"http://10.0.0.2:8443/admin");Opens(@"bbc.co.uk",@"https://bbc.co.uk");
 NSDictionary *row=[SHWeb addressForQuery:@"github.com"];assert(([row[@"type"] isEqual:@"url"] && [row[@"id"] isEqual:@"url"] && [row[@"name"] isEqual:@"github.com"]));
 // File names, version numbers, math, sentences, and other text give no address.
 for(NSString *q in @[@"",@" ",@"notes.md",@"main.c",@"report.pdf",@"script.sh",@"lib.rs",@"setup.py",@"photo.jpeg",@"archive.zip",@"1.5",@"10.15.7",@"256.1.1.1",@"3.14*2",@"github",@"localhost",@"github .com",@"go to github.com",
  @"-bad.com",@"bad-.com",@"a..com",@".com",@"github.com:99999",@"github.com:port",@"user@example.com",@"https://",@"http:///path",@"www.example.123",@"ftp://example.com",@"café.com"])
  if([SHWeb addressForQuery:q]){fprintf(stderr,"'%s' must give no address\n",q.UTF8String);abort();}
 for(int k=0;k<20000;k++){unichar c[40];NSUInteger n=arc4random_uniform(40);const char *set="abcmo0123456789.:/?#-_ wh@tps";for(NSUInteger i=0;i<n;i++)c[i]=(unichar)set[arc4random_uniform(29)];[SHWeb addressForQuery:[NSString stringWithCharacters:c length:n]];}
 // Web search: the default engine, each engine, unknown ids, encoding, and collapsed spaces.
 NSArray *engines=SHWeb.engines;assert(engines.count==5 && [engines[0][@"id"] isEqual:@"google"]);
 NSDictionary *web=[SHWeb searchForQuery:@"  hello   world " engine:nil];
 assert(([web[@"type"] isEqual:@"web"] && [web[@"id"] isEqual:@"web"] && [web[@"name"] isEqual:@"Search Google for “hello world”"] && [web[@"url"] isEqual:@"https://www.google.com/search?q=hello%20world"]));
 assert([[SHWeb searchForQuery:@"c++ & a/b?#x=1" engine:@"google"][@"url"] isEqual:@"https://www.google.com/search?q=c%2B%2B%20%26%20a%2Fb%3F%23x%3D1"]);
 assert([[SHWeb searchForQuery:@"東京 café" engine:@"google"][@"url"] isEqual:@"https://www.google.com/search?q=%E6%9D%B1%E4%BA%AC%20caf%C3%A9"]);
 assert([[SHWeb searchForQuery:@"x" engine:@"unknown"][@"url"] isEqual:@"https://www.google.com/search?q=x"]);
 NSDictionary *expected=@{@"google":@"https://www.google.com/search?q=x",@"duckduckgo":@"https://duckduckgo.com/?q=x",@"bing":@"https://www.bing.com/search?q=x",@"brave":@"https://search.brave.com/search?q=x",@"kagi":@"https://kagi.com/search?q=x"};
 for(NSDictionary *e in engines)assert([[SHWeb searchForQuery:@"x" engine:e[@"id"]][@"url"] isEqual:expected[e[@"id"]]]);
 assert([[SHWeb searchForQuery:@"x" engine:@"brave"][@"name"] isEqual:@"Search Brave Search for “x”"]);
 for(NSString *q in @[@"",@"   ",@"\n\t"])assert(![SHWeb searchForQuery:q engine:nil]);
 puts("PASS web: addresses, local and numeric hosts, ports, rejected file names and text, search engines and encoding, 20000 random inputs");
}return 0;}
