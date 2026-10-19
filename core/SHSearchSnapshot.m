#import "SHSearchSnapshot.h"
#include "sh_match.h"
#include <stdlib.h>
#include <string.h>
NSString *SHFold(NSString *text) {
 return [[text precomposedStringWithCanonicalMapping] stringByFoldingWithOptions:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
}
// Names are usually unique; aliases and parent paths commonly repeat across entries.
// Store those shared texts once and keep compact indexes in each record.
typedef struct { SHText name; uint32_t alias,path; } SHRecord;
static const uint32_t EmptyPoint=0;
static const uint8_t EmptyBoundary=0;
static SHText Text(NSString *value) {
 NSData *data=[SHFold(value) dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
 size_t n=data.length/4;
 if(!n)return (SHText){&EmptyPoint,&EmptyBoundary,0};
 if(n>SIZE_MAX/(sizeof(uint32_t)+sizeof(uint8_t)))return (SHText){0};
 uint32_t *p=malloc(n*(sizeof(uint32_t)+sizeof(uint8_t)));
 if(!p)return (SHText){0};
 uint8_t *b=(uint8_t *)(p+n);
 memcpy(p,data.bytes,data.length);
 NSCharacterSet *letters=NSCharacterSet.alphanumericCharacterSet;
 for(size_t i=0;i<n;i++) b[i]=i==0 || ![letters longCharacterIsMember:p[i-1]];
 return (SHText){p,b,n};
}
static void FreeText(SHText t) {if(t.length)free((void *)t.points);}
typedef struct { NSUInteger index; unsigned learned,worst,total,pathTerms; size_t compactness; } Ranked;
@implementation SHSearchSnapshot {
 NSArray<NSDictionary *> *_entries;
 SHRecord *_records;
 SHText *_sharedTexts;
 size_t _sharedCount,_sharedCapacity;
 SHSearchSnapshot *_storageOwner;
 NSSet *_excludedRoots;
 NSDictionary *_rootCounts;
}
- (BOOL)intern:(NSString *)value indexes:(NSMutableDictionary<NSString *,NSNumber *> *)indexes result:(uint32_t *)index {
 NSNumber *existing=indexes[value];
 if(existing){*index=existing.unsignedIntValue;return YES;}
 if(_sharedCount==UINT32_MAX)return NO;
 if(_sharedCount==_sharedCapacity){
  size_t capacity=MIN((size_t)UINT32_MAX,MAX((size_t)16,_sharedCapacity*2));
  if(capacity>SIZE_MAX/sizeof(SHText))return NO;
  SHText *grown=realloc(_sharedTexts,capacity*sizeof(SHText));
  if(!grown)return NO;
  _sharedTexts=grown;_sharedCapacity=capacity;
 }
 SHText text=Text(value);if(!text.points)return NO;
 *index=(uint32_t)_sharedCount;_sharedTexts[_sharedCount++]=text;indexes[value]=@(*index);return YES;
}
- (instancetype)initWithEntries:(NSArray<NSDictionary *> *)entries generation:(uint64_t)generation {
 if(!(self=[super init])) return nil;
 _generation=generation;
 // Sorting once provides stable lexicographic tie breaking without Foundation work per candidate.
 _entries=[entries sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
  NSComparisonResult c=[SHFold(a[@"name"]) compare:SHFold(b[@"name"])];
  if(c==NSOrderedSame) c=[SHFold(a[@"path"]) compare:SHFold(b[@"path"])];
  if(c==NSOrderedSame) c=[a[@"id"] compare:b[@"id"]]; return c;
 }];
 _count=_entries.count;
 NSMutableDictionary *counts=NSMutableDictionary.dictionary;
 for(NSDictionary *e in _entries)if(e[@"root"])counts[e[@"root"]]=@([counts[e[@"root"]] unsignedIntegerValue]+1);
 _rootCounts=[counts copy];_excludedRoots=NSSet.set;
 if(_count>SIZE_MAX/sizeof(SHRecord)) return nil;
 _records=calloc(MAX(_count,1),sizeof(SHRecord)); if(!_records)return nil;
 NSMutableDictionary<NSString *,NSNumber *> *indexes=NSMutableDictionary.dictionary;
 for(NSUInteger i=0;i<_count;i++) {@autoreleasepool {
  NSDictionary *e=_entries[i];
  NSString *relative=e[@"relative"]?:e[@"path"];
  // A basename already matched by name cannot improve its class as a path match.
  // Avoid storing its normalized code points twice; preserve differing app bundle names.
  if([SHFold(relative.lastPathComponent) isEqual:SHFold(e[@"name"])])relative=relative.stringByDeletingLastPathComponent;
  _records[i].name=Text(e[@"name"]);
  if(!_records[i].name.points ||
     ![self intern:e[@"alias"]?:@"" indexes:indexes result:&_records[i].alias] ||
     ![self intern:relative indexes:indexes result:&_records[i].path])return nil;
 }}
 return self;
}
- (SHSearchSnapshot *)snapshotByExcludingRoots:(NSSet<NSString *> *)roots {
 BOOL relevant=NO;for(NSString *root in roots)if([_rootCounts[root] unsignedIntegerValue] && ![_excludedRoots containsObject:root]){relevant=YES;break;}if(!relevant)return self;
 SHSearchSnapshot *s=[SHSearchSnapshot new];s->_storageOwner=self;s->_records=_records;s->_sharedTexts=_sharedTexts;s->_entries=_entries;s->_rootCounts=_rootCounts;s->_generation=_generation;
 NSMutableSet *all=[_excludedRoots mutableCopy];[all unionSet:roots];s->_excludedRoots=[all copy];s->_count=_entries.count;for(NSString *root in all)s->_count-=[_rootCounts[root] unsignedIntegerValue];return s;
}
- (void)dealloc {
 if(!_storageOwner){
  if(_records){for(NSUInteger i=0;i<_entries.count;i++)FreeText(_records[i].name);free(_records);}
  for(size_t i=0;i<_sharedCount;i++)FreeText(_sharedTexts[i]);free(_sharedTexts);
 }
}
- (BOOL)rank:(Ranked)a precedes:(Ranked)b {
 if(a.learned!=b.learned)return a.learned>b.learned;
 // An application or settings pane matched by its name or alias precedes every file, folder, and link.
 // Exact matches precede typing-error matches; within each group, applications and settings panes come first.
 NSString *at=_entries[a.index][@"type"],*bt=_entries[b.index][@"type"];
 BOOL aa=a.worst!=4 && ([at isEqual:@"app"] || [at isEqual:@"settings"]),ba=b.worst!=4 && ([bt isEqual:@"app"] || [bt isEqual:@"settings"]);
 if((a.worst>4)!=(b.worst>4))return a.worst<=4;
 if(aa!=ba)return aa;
 if(a.worst!=b.worst)return a.worst<b.worst;
 if(a.total!=b.total)return a.total<b.total;
 if(a.pathTerms!=b.pathTerms)return a.pathTerms<b.pathTerms;
 if(a.compactness!=b.compactness)return a.compactness<b.compactness;
 return a.index<b.index;
}
- (NSArray<NSDictionary *> *)search:(NSString *)query cancelled:(BOOL (^)(void))cancelled {return [self search:query preferred:nil cancelled:cancelled];}
- (NSUInteger)indexOfName:(NSString *)name path:(NSString *)path {
 NSString *folded=SHFold(name);
 NSUInteger i=[_entries indexOfObject:@{@"name":name} inSortedRange:NSMakeRange(0,_entries.count) options:NSBinarySearchingFirstEqual usingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [SHFold(a[@"name"]) compare:SHFold(b[@"name"])];}];
 for(;i!=NSNotFound && i<_entries.count && [SHFold(_entries[i][@"name"]) isEqual:folded];i++)if([_entries[i][@"path"] isEqual:path])return i;
 return NSNotFound;
}
- (NSArray<NSDictionary *> *)search:(NSString *)query preferred:(NSArray<NSDictionary *> *)preferred cancelled:(BOOL (^)(void))cancelled {
 NSUInteger learned[8],learnedCount=0;
 for(NSDictionary *p in preferred){if(learnedCount==8)break;learned[learnedCount]=[self indexOfName:p[@"name"] path:p[@"path"]];learnedCount++;}
 NSArray *raw=[query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSMutableArray *terms=NSMutableArray.array; for(NSString *t in raw)if(t.length)[terms addObject:t];
 if(cancelled && cancelled())return @[];
 if(!terms.count){
  // The most opened applications lead; applications by name fill the remaining rows.
  NSMutableArray *apps=NSMutableArray.array;NSMutableArray *candidates=NSMutableArray.array;
  for(NSDictionary *p in preferred){NSUInteger i=[self indexOfName:p[@"name"] path:p[@"path"]];if(i!=NSNotFound)[candidates addObject:_entries[i]];}
  [candidates addObjectsFromArray:_entries];
  for(NSDictionary *e in candidates){if(apps.count==8)break;if([e[@"type"] isEqual:@"app"] && ![_excludedRoots containsObject:e[@"root"]?:@""] && [apps indexOfObjectIdenticalTo:e]==NSNotFound)[apps addObject:e];}
  return apps;
 }
 if(terms.count>SIZE_MAX/sizeof(SHText))return @[];
 SHText *texts=calloc(terms.count,sizeof(SHText)); if(!texts)return @[];
 BOOL valid=YES; for(NSUInteger j=0;j<terms.count;j++){texts[j]=Text(terms[j]);if(!texts[j].points)valid=NO;}
 Ranked top[8];NSUInteger found=0;
 if(valid)for(NSUInteger i=0;i<_entries.count;i++) {
  if(_excludedRoots.count && [_excludedRoots containsObject:_entries[i][@"root"]?:@""])continue;
  if((i&255)==0 && cancelled && cancelled()){found=0;break;}
  SHRecord rec=_records[i];SHText path=_sharedTexts[rec.path]; Ranked rank={i,0,0,0,0,0}; BOOL match=YES;
  for(NSUInteger j=0;j<terms.count;j++) {
   SHMatch m=sh_match(rec.name,texts[j]),alias=sh_match(_sharedTexts[rec.alias],texts[j]);
   if(alias.rank<m.rank || (alias.rank==m.rank && alias.compactness<m.compactness))m=alias;
   if(m.rank==9) {
    // A term may match a relative path component, never cross a slash boundary.
    for(size_t start=0;start<path.length;) {
     size_t end=start;while(end<path.length && path.points[end]!='/')end++;
     SHMatch p=sh_match((SHText){path.points+start,path.boundaries+start,end-start},texts[j]);
     if(p.rank<9){m=(SHMatch){4,p.compactness};break;}start=end+1;
    }
   }
   if(m.rank==9) {
    // Typing errors are accepted in names only, and rank below every exact match.
    m=sh_match_typo(rec.name,texts[j]);alias=sh_match_typo(_sharedTexts[rec.alias],texts[j]);
    if(alias.rank<m.rank || (alias.rank==m.rank && alias.compactness<m.compactness))m=alias;
   }
   if(m.rank==9){match=NO;break;}
   rank.worst=MAX(rank.worst,m.rank);rank.total+=m.rank;rank.pathTerms+=m.rank==4;rank.compactness+=m.compactness;
  }
  if(!match)continue;
  for(NSUInteger k=0;k<learnedCount;k++)if(learned[k]==i){rank.learned=(unsigned)(8-k);break;}
  NSUInteger pos=0;while(pos<found && ![self rank:rank precedes:top[pos]])pos++;
  if(pos<8){for(NSUInteger k=MIN(found,7);k>pos;k--)top[k]=top[k-1];top[pos]=rank;found=MIN(found+1,8);}
 }
 for(NSUInteger j=0;j<terms.count;j++)FreeText(texts[j]);free(texts);
 NSMutableArray *result=NSMutableArray.array;for(NSUInteger i=0;i<found;i++)[result addObject:_entries[top[i].index]];return result;
}
@end
