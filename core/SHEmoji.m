#import "SHEmoji.h"
#import "SHSearchSnapshot.h"
#import <CoreText/CoreText.h>
static NSArray<NSString *> *Words(NSString *text) {
 NSMutableArray *words=NSMutableArray.array;
 for(NSString *w in [SHFold(text) componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet])if(w.length)[words addObject:w];
 return words;
}
@implementation SHEmoji {NSArray<NSDictionary *> *_items;dispatch_group_t _loading;}
- (instancetype)initWithURL:(NSURL *)url {
 if((self=[super init])){
  _items=@[];_loading=dispatch_group_create();
  dispatch_group_async(_loading,dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   NSMutableArray *items=NSMutableArray.array;
   CTFontRef font=CTFontCreateWithName(CFSTR("AppleColorEmoji"),12,NULL);
   NSString *file=[NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
   for(NSString *line in [file componentsSeparatedByString:@"\n"]){@autoreleasepool{
    NSArray<NSString *> *fields=[line componentsSeparatedByString:@"\t"];if(fields.count<3)continue;
    // The list can be newer than this macOS; an emoji the system font cannot draw as one glyph is left out.
    CTLineRef drawn=CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString:fields[0] attributes:@{(__bridge id)kCTFontAttributeName:(__bridge id)font}]);
    NSArray *runs=(__bridge NSArray *)CTLineGetGlyphRuns(drawn);BOOL supported=CTLineGetGlyphCount(drawn)==1 && runs.count==1;
    if(supported){CTFontRef used=CFDictionaryGetValue(CTRunGetAttributes((__bridge CTRunRef)runs[0]),kCTFontAttributeName);NSString *name=CFBridgingRelease(CTFontCopyPostScriptName(used));supported=[name isEqual:@"AppleColorEmoji"];}
    CFRelease(drawn);if(!supported)continue;
    NSMutableArray *keywords=NSMutableArray.array;for(NSString *k in [fields[2] componentsSeparatedByString:@"|"])[keywords addObjectsFromArray:Words(k)];
    NSString *path=[@"emoji:" stringByAppendingString:fields[0]];
    [items addObject:@{@"nameWords":Words(fields[1]),@"keywords":keywords,@"foldedName":[Words(fields[1]) componentsJoinedByString:@" "],
     @"result":@{@"type":@"emoji",@"id":path,@"path":path,@"name":fields[1],@"emoji":fields[0],@"copy":fields[0]}}];
   }}
   CFRelease(font);
   dispatch_async(dispatch_get_main_queue(),^{self->_items=items;});
  });
 }
 return self;
}
- (NSArray<NSDictionary *> *)list {return [_items valueForKey:@"result"];}
- (void)waitUntilLoaded {dispatch_group_wait(_loading,DISPATCH_TIME_FOREVER);[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];}
- (NSArray<NSDictionary *> *)search:(NSString *)query limit:(NSUInteger)limit {
 NSArray<NSString *> *terms=Words(query);NSString *whole=[terms componentsJoinedByString:@" "];
 if(whole.length<2)return @[];
 NSMutableArray *found=NSMutableArray.array;NSUInteger order=0;
 for(NSDictionary *item in _items){
  // Lower is better per word: 0 a whole word of the name, 1 its start, 2 a whole keyword, 3 its start.
  NSUInteger score=0;BOOL match=YES;
  for(NSString *term in terms){
   NSUInteger best=9;
   for(NSString *w in item[@"nameWords"]){if([w isEqual:term])best=0;else if(best>1 && [w hasPrefix:term])best=1;}
   if(best>2)for(NSString *w in item[@"keywords"]){if([w isEqual:term]){best=2;break;}else if([w hasPrefix:term])best=3;}
   if(best==9){match=NO;break;}
   score+=best;
  }
  if(!match){order++;continue;}
  // The full name outranks every partial match; a shorter name outranks a longer one.
  score=score*100+([item[@"foldedName"] isEqual:whole]?0:MIN((NSUInteger)99,[item[@"nameWords"] count]));
  [found addObject:@[@(score),@(order++),item[@"result"]]];
 }
 [found sortUsingComparator:^NSComparisonResult(NSArray *a,NSArray *b){NSComparisonResult c=[a[0] compare:b[0]];return c==NSOrderedSame?[a[1] compare:b[1]]:c;}];
 NSMutableArray *results=NSMutableArray.array;for(NSArray *f in found){if(results.count==limit)break;[results addObject:f[2]];}
 return results;
}
@end
