#import "SHUsage.h"
#import "SHSearchSnapshot.h"
@implementation SHUsage {NSURL *_url;NSMutableDictionary<NSString *,NSMutableDictionary *> *_items;}
- (instancetype)initWithURL:(NSURL *)url {
 if((self=[super init])){
  _url=url;NSData *data=[NSData dataWithContentsOfURL:url];
  id saved=data?[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainers format:NULL error:nil]:nil;
  _items=[saved isKindOfClass:NSMutableDictionary.class]?saved:NSMutableDictionary.dictionary;
 }
 return self;
}
static NSString *Key(NSString *query) {
 NSMutableArray *terms=NSMutableArray.array;
 for(NSString *t in [SHFold(query) componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet])if(t.length)[terms addObject:t];
 return [terms componentsJoinedByString:@" "];
}
- (void)recordQuery:(NSString *)query result:(NSDictionary *)result {
 NSString *key=Key(query),*path=result[@"path"],*name=result[@"name"];if(!path || !name)return;
 NSMutableDictionary *item=_items[path];if(![item isKindOfClass:NSMutableDictionary.class] || ![item[@"queries"] isKindOfClass:NSMutableDictionary.class])item=_items[path]=[@{@"queries":NSMutableDictionary.dictionary} mutableCopy];
 NSMutableDictionary *queries=item[@"queries"];
 item[@"name"]=name;item[@"last"]=@(NSDate.date.timeIntervalSince1970);queries[key]=@([queries[key] unsignedIntegerValue]+1);
 // Bounded history: the least used query of a result and the oldest result are dropped first.
 if(queries.count>20){NSString *least=nil;for(NSString *q in queries)if(![q isEqual:key] && (!least || [queries[q] compare:queries[least]]==NSOrderedAscending))least=q;[queries removeObjectForKey:least];}
 if(_items.count>500){NSString *oldest=nil;for(NSString *p in _items)if(!oldest || [_items[p][@"last"] compare:_items[oldest][@"last"]]==NSOrderedAscending)oldest=p;[_items removeObjectForKey:oldest];}
 [[NSPropertyListSerialization dataWithPropertyList:_items format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil] writeToURL:_url atomically:YES];
}
- (NSArray<NSDictionary *> *)preferredForQuery:(NSString *)query {
 NSString *key=Key(query);NSUInteger limit=key.length?8:40;
 NSTimeInterval now=NSDate.date.timeIntervalSince1970;NSMutableArray *scored=NSMutableArray.array;
 for(NSString *path in _items){
  NSDictionary *item=_items[path];double score=0;
  for(NSString *q in item[@"queries"]){
   // The same query counts most; a longer query typed before counts more than a shorter one.
   double weight=!key.length?1:[q isEqual:key]?4:[q hasPrefix:key]?2:(q.length && [key hasPrefix:q])?1:0;
   score+=weight*[item[@"queries"][q] doubleValue];
  }
  if(score<=0)continue;
  // A choice loses half of its weight each 30 days without use.
  score*=pow(0.5,MAX(0,now-[item[@"last"] doubleValue])/(30*86400.0));
  [scored addObject:@{@"path":path,@"name":item[@"name"]?:@"",@"score":@(score),@"last":item[@"last"]?:@0}];
 }
 [scored sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO],[NSSortDescriptor sortDescriptorWithKey:@"last" ascending:NO],[NSSortDescriptor sortDescriptorWithKey:@"path" ascending:YES]]];
 return scored.count>limit?[scored subarrayWithRange:NSMakeRange(0,limit)]:scored;
}
@end
