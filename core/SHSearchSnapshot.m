#import "SHSearchSnapshot.h"
#include "sh_match.h"
#include <stdlib.h>
#include <string.h>
NSString *SHFold(NSString *text) {
 return [[text precomposedStringWithCanonicalMapping] stringByFoldingWithOptions:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
}
BOOL SHLaunchable(NSDictionary *entry) {NSString *type=entry[@"type"];return [type isEqual:@"app"] || [type isEqual:@"settings"] || [type isEqual:@"command"];}
// Names are usually unique; aliases and parent paths commonly repeat across entries.
// Store those shared texts once and keep compact indexes in each record.
// Fields of a catalog entry stay as UTF-8 in one buffer and become a dictionary only for a result; other entries keep their dictionary.
typedef struct { SHText name; uint32_t alias,path,root; uint8_t type,flags; uint32_t nameBytes,pathBytes,relativeBytes,aliasBytes; size_t bytes; int64_t id; } SHRecord;
enum { HasID=1,HasRoot=2,HasRelative=4,HasAlias=8,RelativeInPath=16,Kept=32,App=64,Launchable=128 };
static NSString *const Fields[]={@"id",@"root",@"relative",@"name",@"path",@"type",@"alias"};
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
static NSString *String(const char *bytes,uint32_t length) {return length?[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding]:@"";}
typedef struct { NSUInteger index; unsigned learned,worst,total,pathTerms; size_t compactness; } Ranked;
@implementation SHSearchSnapshot {
 NSUInteger _size;
 SHRecord *_records;
 char *_bytes;
 size_t _byteCount,_byteCapacity;
 NSMutableArray *_types,*_roots;
 NSMutableDictionary<NSNumber *,NSDictionary *> *_kept;
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
// Stores the fields of a catalog entry in the byte buffer. NO when the entry has other keys or values that UTF-8 cannot hold; failed reports an allocation failure.
- (BOOL)compact:(NSDictionary *)e record:(SHRecord *)r failed:(BOOL *)failed {
 NSUInteger known=0;for(int k=0;k<7;k++)if(e[Fields[k]])known++;
 if(known!=e.count || ![e[@"name"] isKindOfClass:NSString.class] || ![e[@"path"] isKindOfClass:NSString.class] || ![e[@"type"] isKindOfClass:NSString.class])return NO;
 for(int k=1;k<7;k++)if(e[Fields[k]] && ![e[Fields[k]] isKindOfClass:NSString.class])return NO;
 NSNumber *identifier=e[@"id"];if(identifier && (![identifier isKindOfClass:NSNumber.class] || ![@(identifier.longLongValue) isEqual:identifier]))return NO;
 NSString *fields[4]={e[@"name"],e[@"path"],e[@"relative"]?:@"",e[@"alias"]?:@""};NSUInteger lengths[4],total=0;
 for(int k=0;k<4;k++){lengths[k]=[fields[k] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];if((!lengths[k] && fields[k].length) || lengths[k]>UINT32_MAX)return NO;total+=lengths[k];}
 NSUInteger type=[_types indexOfObject:e[@"type"]];if(type==NSNotFound){if(_types.count==UINT8_MAX)return NO;type=_types.count;[_types addObject:e[@"type"]];}
 if(!_bytes || _byteCount+total>_byteCapacity){
  size_t capacity=MAX(_byteCapacity*2,_byteCount+total+4096);char *grown=realloc(_bytes,capacity);
  if(!grown){*failed=YES;return NO;}_bytes=grown;_byteCapacity=capacity;
 }
 r->bytes=_byteCount;
 for(int k=0;k<4;k++){NSUInteger used=0;[fields[k] getBytes:_bytes+_byteCount maxLength:lengths[k] usedLength:&used encoding:NSUTF8StringEncoding options:0 range:NSMakeRange(0,fields[k].length) remainingRange:NULL];_byteCount+=used;}
 r->nameBytes=(uint32_t)lengths[0];r->pathBytes=(uint32_t)lengths[1];r->relativeBytes=(uint32_t)lengths[2];r->aliasBytes=(uint32_t)lengths[3];r->type=(uint8_t)type;r->id=identifier.longLongValue;
 r->flags|=(identifier?HasID:0)|(e[@"root"]?HasRoot:0)|(e[@"relative"]?HasRelative:0)|(e[@"alias"]?HasAlias:0);
 // A relative path is usually the end of the full path; then only the full path is stored.
 char *path=_bytes+r->bytes+r->nameBytes,*relative=path+r->pathBytes;
 if(r->relativeBytes<=r->pathBytes && !memcmp(relative-r->relativeBytes,relative,r->relativeBytes)){memmove(relative,relative+r->relativeBytes,r->aliasBytes);_byteCount-=r->relativeBytes;r->flags|=RelativeInPath;}
 return YES;
}
- (instancetype)initWithEntries:(NSArray<NSDictionary *> *)entries generation:(uint64_t)generation {
 if(!(self=[super init])) return nil;
 _generation=generation;
 // Sorting once provides stable lexicographic tie breaking without Foundation work per candidate.
 NSArray<NSDictionary *> *sorted=[entries sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
  NSComparisonResult c=[SHFold(a[@"name"]) compare:SHFold(b[@"name"])];
  if(c==NSOrderedSame) c=[SHFold(a[@"path"]) compare:SHFold(b[@"path"])];
  if(c==NSOrderedSame) c=[a[@"id"] compare:b[@"id"]]; return c;
 }];
 _size=_count=sorted.count;
 NSMutableDictionary *counts=NSMutableDictionary.dictionary;
 for(NSDictionary *e in sorted)if(e[@"root"])counts[e[@"root"]]=@([counts[e[@"root"]] unsignedIntegerValue]+1);
 _rootCounts=[counts copy];_excludedRoots=NSSet.set;_types=NSMutableArray.array;_roots=NSMutableArray.array;_kept=NSMutableDictionary.dictionary;
 if(_count>SIZE_MAX/sizeof(SHRecord)) return nil;
 _records=calloc(MAX(_count,1),sizeof(SHRecord)); if(!_records)return nil;
 NSMutableDictionary<NSString *,NSNumber *> *indexes=NSMutableDictionary.dictionary,*roots=NSMutableDictionary.dictionary;
 for(NSUInteger i=0;i<_count;i++) {@autoreleasepool {
  NSDictionary *e=sorted[i];SHRecord *r=&_records[i];
  NSString *relative=e[@"relative"]?:e[@"path"];
  // A basename already matched by name cannot improve its class as a path match.
  // Avoid storing its normalized code points twice; preserve differing app bundle names.
  if([SHFold(relative.lastPathComponent) isEqual:SHFold(e[@"name"])])relative=relative.stringByDeletingLastPathComponent;
  r->name=Text(e[@"name"]);
  if(!r->name.points ||
     ![self intern:e[@"alias"]?:@"" indexes:indexes result:&r->alias] ||
     ![self intern:relative indexes:indexes result:&r->path])return nil;
  NSString *root=[e[@"root"] isKindOfClass:NSString.class]?e[@"root"]:@"";NSNumber *rootIndex=roots[root];
  if(!rootIndex){rootIndex=roots[root]=@(_roots.count);[_roots addObject:root];}r->root=rootIndex.unsignedIntValue;
  r->flags=([e[@"type"] isEqual:@"app"]?App:0)|(SHLaunchable(e)?Launchable:0);
  BOOL failed=NO;if(![self compact:e record:r failed:&failed]){if(failed)return nil;r->flags|=Kept;_kept[@(i)]=e;}
 }}
 return self;
}
- (NSString *)nameAt:(NSUInteger)i {SHRecord r=_records[i];return r.flags&Kept?_kept[@(i)][@"name"]:String(_bytes+r.bytes,r.nameBytes);}
- (NSString *)pathAt:(NSUInteger)i {SHRecord r=_records[i];return r.flags&Kept?_kept[@(i)][@"path"]:String(_bytes+r.bytes+r.nameBytes,r.pathBytes);}
- (NSDictionary *)entryAt:(NSUInteger)i {
 SHRecord r=_records[i];if(r.flags&Kept)return _kept[@(i)];
 const char *path=_bytes+r.bytes+r.nameBytes,*next=path+r.pathBytes;
 NSMutableDictionary *e=[NSMutableDictionary dictionaryWithCapacity:7];e[@"name"]=String(_bytes+r.bytes,r.nameBytes);e[@"path"]=String(path,r.pathBytes);e[@"type"]=_types[r.type];
 if(r.flags&HasRelative){if(r.flags&RelativeInPath)e[@"relative"]=String(next-r.relativeBytes,r.relativeBytes);else {e[@"relative"]=String(next,r.relativeBytes);next+=r.relativeBytes;}}
 if(r.flags&HasAlias)e[@"alias"]=String(next,r.aliasBytes);
 if(r.flags&HasRoot)e[@"root"]=_roots[r.root];
 if(r.flags&HasID)e[@"id"]=@(r.id);
 return [e copy];
}
- (SHSearchSnapshot *)snapshotByExcludingRoots:(NSSet<NSString *> *)roots {
 BOOL relevant=NO;for(NSString *root in roots)if([_rootCounts[root] unsignedIntegerValue] && ![_excludedRoots containsObject:root]){relevant=YES;break;}if(!relevant)return self;
 SHSearchSnapshot *s=[SHSearchSnapshot new];s->_storageOwner=self;s->_records=_records;s->_sharedTexts=_sharedTexts;s->_size=_size;s->_bytes=_bytes;s->_types=_types;s->_roots=_roots;s->_kept=_kept;s->_rootCounts=_rootCounts;s->_generation=_generation;
 NSMutableSet *all=[_excludedRoots mutableCopy];[all unionSet:roots];s->_excludedRoots=[all copy];s->_count=_size;for(NSString *root in all)s->_count-=[_rootCounts[root] unsignedIntegerValue];return s;
}
- (void)dealloc {
 if(!_storageOwner){
  if(_records){for(NSUInteger i=0;i<_size;i++)FreeText(_records[i].name);free(_records);}
  free(_bytes);
  for(size_t i=0;i<_sharedCount;i++)FreeText(_sharedTexts[i]);free(_sharedTexts);
 }
}
- (BOOL)rank:(Ranked)a precedes:(Ranked)b {
 if(a.learned!=b.learned)return a.learned>b.learned;
 // An application, settings pane, or command matched by its name or alias precedes every file, folder, and link.
 // Exact matches precede typing-error matches; within each group, those results come first.
 BOOL aa=a.worst!=4 && (_records[a.index].flags&Launchable),ba=b.worst!=4 && (_records[b.index].flags&Launchable);
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
 if(!name || !path)return NSNotFound;
 NSString *folded=SHFold(name);NSUInteger low=0,high=_size;
 while(low<high){NSUInteger middle=low+(high-low)/2;if([SHFold([self nameAt:middle]) compare:folded]==NSOrderedAscending)low=middle+1;else high=middle;}
 for(NSUInteger i=low;i<_size && [SHFold([self nameAt:i]) isEqual:folded];i++)if([[self pathAt:i] isEqual:path])return i;
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
  NSMutableArray *apps=NSMutableArray.array;NSMutableIndexSet *chosen=NSMutableIndexSet.indexSet;
  void (^consider)(NSUInteger)=^(NSUInteger i){if(apps.count<8 && (self->_records[i].flags&App) && ![self->_excludedRoots containsObject:self->_roots[self->_records[i].root]] && ![chosen containsIndex:i]){[chosen addIndex:i];[apps addObject:[self entryAt:i]];}};
  for(NSDictionary *p in preferred){NSUInteger i=[self indexOfName:p[@"name"] path:p[@"path"]];if(i!=NSNotFound)consider(i);}
  for(NSUInteger i=0;i<_size && apps.count<8;i++)consider(i);
  return apps;
 }
 if(terms.count>SIZE_MAX/sizeof(SHText))return @[];
 SHText *texts=calloc(terms.count,sizeof(SHText)); if(!texts)return @[];
 BOOL valid=YES; for(NSUInteger j=0;j<terms.count;j++){texts[j]=Text(terms[j]);if(!texts[j].points)valid=NO;}
 BOOL *excluded=calloc(MAX(_roots.count,1),sizeof(BOOL));if(!excluded)valid=NO;else for(NSUInteger k=0;k<_roots.count;k++)excluded[k]=[_excludedRoots containsObject:_roots[k]];
 Ranked top[8];NSUInteger found=0;
 if(valid)for(NSUInteger i=0;i<_size;i++) {
  if(excluded[_records[i].root])continue;
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
 for(NSUInteger j=0;j<terms.count;j++)FreeText(texts[j]);free(texts);free(excluded);
 NSMutableArray *result=NSMutableArray.array;for(NSUInteger i=0;i<found;i++)[result addObject:[self entryAt:top[i].index]];return result;
}
@end
