#import "SHSearchSnapshot.h"
#include "sh_match.h"
#include <stdlib.h>
#include <string.h>
NSString *SHFold(NSString *text) {
 return [[text precomposedStringWithCanonicalMapping] stringByFoldingWithOptions:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
}
typedef struct { SHText name,alias,path; } SHRecord;
static SHText Text(NSString *value) {
 NSData *data=[SHFold(value) dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
 size_t n=data.length/4;
 if(n>SIZE_MAX/sizeof(uint32_t)) return (SHText){0};
 uint32_t *p=malloc(MAX(data.length,1)); uint8_t *b=calloc(MAX(n,1),1);
 if(!p||!b){free(p);free(b);return (SHText){0};}
 memcpy(p,data.bytes,data.length);
 NSCharacterSet *letters=NSCharacterSet.alphanumericCharacterSet;
 for(size_t i=0;i<n;i++) b[i]=i==0 || ![letters longCharacterIsMember:p[i-1]];
 return (SHText){p,b,n};
}
static void FreeText(SHText t) {free((void *)t.points);free((void *)t.boundaries);}
typedef struct { NSUInteger index; unsigned worst,total,pathTerms; size_t compactness; } Ranked;
@implementation SHSearchSnapshot {
 NSArray<NSDictionary *> *_entries;
 SHRecord *_records;
 SHSearchSnapshot *_storageOwner;
 NSSet *_excludedRoots;
 NSDictionary *_rootCounts;
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
 for(NSUInteger i=0;i<_count;i++) {@autoreleasepool {
  NSDictionary *e=_entries[i];
  NSString *relative=e[@"relative"]?:e[@"path"];
  // A basename already matched by name cannot improve its class as a path match.
  // Avoid storing its normalized code points twice; preserve differing app bundle names.
  if([SHFold(relative.lastPathComponent) isEqual:SHFold(e[@"name"])])relative=relative.stringByDeletingLastPathComponent;
  _records[i]=(SHRecord){Text(e[@"name"]),Text(e[@"alias"]?:@""),Text(relative)};
  if(!_records[i].name.points || !_records[i].alias.points || !_records[i].path.points) return nil;
 }}
 return self;
}
- (SHSearchSnapshot *)snapshotByExcludingRoots:(NSSet<NSString *> *)roots {
 BOOL relevant=NO;for(NSString *root in roots)if([_rootCounts[root] unsignedIntegerValue] && ![_excludedRoots containsObject:root]){relevant=YES;break;}if(!relevant)return self;
 SHSearchSnapshot *s=[SHSearchSnapshot new];s->_storageOwner=self;s->_records=_records;s->_entries=_entries;s->_rootCounts=_rootCounts;s->_generation=_generation;
 NSMutableSet *all=[_excludedRoots mutableCopy];[all unionSet:roots];s->_excludedRoots=[all copy];s->_count=_entries.count;for(NSString *root in all)s->_count-=[_rootCounts[root] unsignedIntegerValue];return s;
}
- (void)dealloc {if(_records && !_storageOwner){for(NSUInteger i=0;i<_entries.count;i++){FreeText(_records[i].name);FreeText(_records[i].alias);FreeText(_records[i].path);}free(_records);}}
- (BOOL)rank:(Ranked)a precedes:(Ranked)b {
 if(a.worst!=b.worst)return a.worst<b.worst;
 if(a.total!=b.total)return a.total<b.total;
 if(a.pathTerms!=b.pathTerms)return a.pathTerms<b.pathTerms;
 if(a.compactness!=b.compactness)return a.compactness<b.compactness;
 BOOL aa=[_entries[a.index][@"type"] isEqual:@"app"],ba=[_entries[b.index][@"type"] isEqual:@"app"];
 if(aa!=ba)return aa;
 return a.index<b.index;
}
- (NSArray<NSDictionary *> *)search:(NSString *)query cancelled:(BOOL (^)(void))cancelled {
 NSArray *raw=[query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSMutableArray *terms=NSMutableArray.array; for(NSString *t in raw)if(t.length)[terms addObject:t];
 if(cancelled && cancelled())return @[];
 if(!terms.count){NSMutableArray *apps=NSMutableArray.array;for(NSDictionary *e in _entries){if([e[@"type"] isEqual:@"app"] && ![_excludedRoots containsObject:e[@"root"]?:@""])[apps addObject:e];if(apps.count==8)break;}return apps;}
 if(terms.count>SIZE_MAX/sizeof(SHText))return @[];
 SHText *texts=calloc(terms.count,sizeof(SHText)); if(!texts)return @[];
 BOOL valid=YES; for(NSUInteger j=0;j<terms.count;j++){texts[j]=Text(terms[j]);if(!texts[j].points)valid=NO;}
 Ranked top[8];NSUInteger found=0;
 if(valid)for(NSUInteger i=0;i<_entries.count;i++) {
  if(_excludedRoots.count && [_excludedRoots containsObject:_entries[i][@"root"]?:@""])continue;
  if((i&255)==0 && cancelled && cancelled()){found=0;break;}
  SHRecord rec=_records[i]; Ranked rank={i,0,0,0,0}; BOOL match=YES;
  for(NSUInteger j=0;j<terms.count;j++) {
   SHMatch m=sh_match(rec.name,texts[j]),alias=sh_match(rec.alias,texts[j]);
   if(alias.rank<m.rank || (alias.rank==m.rank && alias.compactness<m.compactness))m=alias;
   if(m.rank==9) {
    // A term may match a relative path component, never cross a slash boundary.
    for(size_t start=0;start<rec.path.length;) {
     size_t end=start;while(end<rec.path.length && rec.path.points[end]!='/')end++;
     SHMatch p=sh_match((SHText){rec.path.points+start,rec.path.boundaries+start,end-start},texts[j]);
     if(p.rank<9){m=(SHMatch){4,p.compactness};break;}start=end+1;
    }
   }
   if(m.rank==9){match=NO;break;}
   rank.worst=MAX(rank.worst,m.rank);rank.total+=m.rank;rank.pathTerms+=m.rank==4;rank.compactness+=m.compactness;
  }
  if(!match)continue;
  NSUInteger pos=0;while(pos<found && ![self rank:rank precedes:top[pos]])pos++;
  if(pos<8){for(NSUInteger k=MIN(found,7);k>pos;k--)top[k]=top[k-1];top[pos]=rank;found=MIN(found+1,8);}
 }
 for(NSUInteger j=0;j<terms.count;j++)FreeText(texts[j]);free(texts);
 NSMutableArray *result=NSMutableArray.array;for(NSUInteger i=0;i<found;i++)[result addObject:_entries[top[i].index]];return result;
}
@end
