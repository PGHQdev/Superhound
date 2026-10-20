#import "SHWeb.h"
// Endings that file names rarely use, so notes.md or main.c stay file searches; a www. host may have any ending.
static NSSet<NSString *> *Endings(void) {
 static NSSet *endings;static dispatch_once_t once;
 dispatch_once(&once,^{endings=[NSSet setWithArray:[@"com net org edu gov mil int io co ai app dev me us uk ca au nz ie de fr es it nl se no dk fi ch at be pl jp cn kr in br mx eu tv xyz info biz site online store tech blog news page cloud gg ly to fm" componentsSeparatedByString:@" "]];});
 return endings;
}
static BOOL Label(NSString *label) {
 if(!label.length || label.length>63 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"])return NO;
 for(NSUInteger i=0;i<label.length;i++){unichar c=[label characterAtIndex:i];if(!((c>='a' && c<='z') || (c>='0' && c<='9') || c=='-'))return NO;}
 return YES;
}
static BOOL Number(NSString *text,NSUInteger digits,NSUInteger maximum) {
 if(!text.length || text.length>digits)return NO;
 for(NSUInteger i=0;i<text.length;i++){unichar c=[text characterAtIndex:i];if(c<'0' || c>'9')return NO;}
 return (NSUInteger)text.integerValue<=maximum;
}
@implementation SHWeb
+ (NSDictionary *)addressForQuery:(NSString *)query {
 NSString *text=[query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!text.length || text.length>2000 || [text rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound)return nil;
 NSString *lower=text.lowercaseString,*address=nil;
 if([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]){NSURL *url=[NSURL URLWithString:text];if(url.host.length)address=url.absoluteString;}
 else {
  NSUInteger end=[lower rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]].location;
  NSString *host=end==NSNotFound?lower:[lower substringToIndex:end],*port=nil;
  NSRange colon=[host rangeOfString:@":"];if(colon.location!=NSNotFound){port=[host substringFromIndex:colon.location+1];host=[host substringToIndex:colon.location];if(!Number(port,5,65535))return nil;}
  NSArray<NSString *> *labels=[host componentsSeparatedByString:@"."];BOOL numeric=labels.count==4,local=[host isEqual:@"localhost"] && port;
  for(NSString *part in labels)if(!Number(part,3,255))numeric=NO;
  BOOL named=labels.count>=2;for(NSString *part in labels)if(!Label(part))named=NO;
  NSString *ending=labels.lastObject;
  named=named && ([Endings() containsObject:ending] || ([labels.firstObject isEqual:@"www"] && labels.count>=3 && ending.length>=2 && [ending rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location==NSNotFound));
  // A local server or an address by number is most often plain http.
  if(local || numeric)address=[@"http://" stringByAppendingString:text];else if(named)address=[@"https://" stringByAppendingString:text];
  if(address && ![NSURL URLWithString:address].host.length)address=nil;
 }
 return address?@{@"type":@"url",@"id":@"url",@"name":text,@"url":address}:nil;
}
+ (NSArray<NSDictionary *> *)engines {
 return @[@{@"id":@"google",@"name":@"Google",@"url":@"https://www.google.com/search?q="},@{@"id":@"duckduckgo",@"name":@"DuckDuckGo",@"url":@"https://duckduckgo.com/?q="},@{@"id":@"bing",@"name":@"Bing",@"url":@"https://www.bing.com/search?q="},
  @{@"id":@"brave",@"name":@"Brave Search",@"url":@"https://search.brave.com/search?q="},@{@"id":@"kagi",@"name":@"Kagi",@"url":@"https://kagi.com/search?q="}];
}
+ (NSDictionary *)searchForQuery:(NSString *)query engine:(NSString *)engine {
 NSMutableArray *words=NSMutableArray.array;for(NSString *w in [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet])if(w.length)[words addObject:w];
 if(!words.count)return nil;
 NSDictionary *chosen=self.engines.firstObject;for(NSDictionary *e in self.engines)if([e[@"id"] isEqual:engine])chosen=e;
 // Only unreserved characters stay as they are, so + & / ? # in the text reach the engine as text.
 NSCharacterSet *plain=[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
 NSString *text=[words componentsJoinedByString:@" "],*encoded=[text stringByAddingPercentEncodingWithAllowedCharacters:plain];if(!encoded)return nil;
 return @{@"type":@"web",@"id":@"web",@"name":[NSString stringWithFormat:NSLocalizedString(@"Search %@ for “%@”",@"Last row of the search results; the first argument is a search engine name such as Google, the second is the typed text"),chosen[@"name"],text],@"url":[chosen[@"url"] stringByAppendingString:encoded]};
}
@end
