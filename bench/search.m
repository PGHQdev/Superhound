#import <Foundation/Foundation.h>
#import "SHSearchSnapshot.h"
#import <libproc.h>
#import <sys/resource.h>
#import <mach/mach_time.h>
static double Millis(void){return (double)clock_gettime_nsec_np(CLOCK_UPTIME_RAW)/1e6;}
static uint64_t PeakFootprint(void){struct rusage_info_v4 usage={0};proc_pid_rusage(getpid(),RUSAGE_INFO_V4,(rusage_info_t *)&usage);return usage.ri_lifetime_max_phys_footprint;}
static uint64_t Footprint(void){struct rusage_info_v4 usage={0};proc_pid_rusage(getpid(),RUSAGE_INFO_V4,(rusage_info_t *)&usage);return usage.ri_phys_footprint;}
static int Compare(const void *a,const void *b){double x=*(const double *)a,y=*(const double *)b;return (x>y)-(x<y);}
int main(int argc,const char *argv[]){@autoreleasepool{
 BOOL check=argc>2 && strcmp(argv[2],"--check-memory")==0;
 BOOL uniqueParents=argc>2 && strcmp(argv[2],"--unique-parents")==0;
 if(argc>3 || (argc>2 && !check && !uniqueParents)){fprintf(stderr,"Usage: search [count] [--check-memory|--unique-parents]\n");return 2;}
 NSUInteger count=argc>1?(NSUInteger)strtoull(argv[1],NULL,10):10000;
 if(check && count!=100000){fprintf(stderr,"Memory budget check requires the 100000-record reference fixture\n");return 2;}
 NSArray *(^Fixture)(void)=^NSArray *{NSMutableArray *entries=NSMutableArray.array;
 for(NSUInteger i=0;i<count;i++){@autoreleasepool{
  NSString *name=[NSString stringWithFormat:@"%@ %06lu.%@",@[@"Project report",@"Visual Studio Code",@"Café notes",@"東京旅行",@"Quarterly budget",@"Screenshot",@"README",@"Design brief"][i%8],(unsigned long)i,i%9?@"txt":@"app"];
  NSString *path=[NSString stringWithFormat:@"/synthetic/Team %lu/2026/%@",(unsigned long)(uniqueParents?i:i%17),name];
  [entries addObject:@{@"id":@(i+1),@"name":name,@"relative":path,@"path":path,@"alias":@"",@"type":i%9?@"file":@"app"}];
 }}
 return entries;};
 // Like the library, the benchmark keeps no entries after a snapshot is prepared; the replacement reads a new set.
 NSArray *entries;double began=Millis();@autoreleasepool{entries=Fixture();}double fixture=Millis()-began;SHSearchSnapshot *snapshot;
 began=Millis();@autoreleasepool{snapshot=[[SHSearchSnapshot alloc] initWithEntries:entries generation:1];}double prepare=Millis()-began;entries=nil;
 if(!snapshot || snapshot.count!=count){fprintf(stderr,"Could not prepare the full snapshot\n");return 1;}
 NSArray *queries=@[@"Project",@"vsc",@"cafe",@"東京",@"Team 7 report",@"budget",@"readme",@"zzzz-missing",@"000999",@"design brief",@"screenshot",@""];
 double samples[360];for(int i=0;i<360;i++){@autoreleasepool{began=Millis();[snapshot search:queries[(NSUInteger)i%queries.count] cancelled:nil];samples[i]=Millis()-began;}}
 qsort(samples,360,sizeof(double),Compare);
 uint64_t steady=Footprint();SHSearchSnapshot *replacement;
 @autoreleasepool{entries=Fixture();}began=Millis();@autoreleasepool{replacement=[[SHSearchSnapshot alloc] initWithEntries:entries generation:2];}double replace=Millis()-began;
 if(!replacement || replacement.count!=count){fprintf(stderr,"Could not prepare the full replacement snapshot\n");return 1;}
 uint64_t peak=Footprint(),lifetimePeak=PeakFootprint();
 printf("records=%lu parent_layout=%s fixture_ms=%.2f prepare_ms=%.2f query_p50_ms=%.3f query_p95_ms=%.3f query_p99_ms=%.3f snapshot_steady_bytes=%llu overlapping_snapshots_bytes=%llu replace_ms=%.2f replacement_count=%lu lifetime_peak_bytes=%llu\n",(unsigned long)count,uniqueParents?"unique":"shared",fixture,prepare,samples[179],samples[341],samples[356],steady,peak,replace,(unsigned long)replacement.count,lifetimePeak);
 if(check && (steady>50*1024*1024ULL || peak>100*1024*1024ULL || lifetimePeak>100*1024*1024ULL)){fprintf(stderr,"FAIL: 100k reference fixture exceeds 50 MiB steady / 100 MiB lifetime-peak budget\n");return 1;}
}return 0;}
