#import <Foundation/Foundation.h>
#import "SHSearchSnapshot.h"
#import <libproc.h>
#import <sys/resource.h>
#import <mach/mach_time.h>
static double Millis(void){return (double)clock_gettime_nsec_np(CLOCK_UPTIME_RAW)/1e6;}
static uint64_t Footprint(void){struct rusage_info_v4 usage={0};proc_pid_rusage(getpid(),RUSAGE_INFO_V4,(rusage_info_t *)&usage);return usage.ri_phys_footprint;}
static int Compare(const void *a,const void *b){double x=*(const double *)a,y=*(const double *)b;return (x>y)-(x<y);}
int main(int argc,const char *argv[]){@autoreleasepool{
 NSUInteger count=argc>1?(NSUInteger)strtoull(argv[1],NULL,10):10000;
 NSMutableArray *entries=NSMutableArray.array;double began=Millis();
 for(NSUInteger i=0;i<count;i++){@autoreleasepool{
  NSString *name=[NSString stringWithFormat:@"%@ %06lu.%@",@[@"Project report",@"Visual Studio Code",@"Café notes",@"東京旅行",@"Quarterly budget",@"Screenshot",@"README",@"Design brief"][i%8],(unsigned long)i,i%9?@"txt":@"app"];
  NSString *path=[NSString stringWithFormat:@"/synthetic/Team %lu/2026/%@",(unsigned long)(i%17),name];
  [entries addObject:@{@"id":@(i+1),@"name":name,@"relative":path,@"path":path,@"alias":@"",@"type":i%9?@"file":@"app"}];
 }}
 double fixture=Millis()-began;SHSearchSnapshot *snapshot;
 began=Millis();@autoreleasepool{snapshot=[[SHSearchSnapshot alloc] initWithEntries:entries generation:1];}double prepare=Millis()-began;
 if(!snapshot)return 1;
 NSArray *queries=@[@"Project",@"vsc",@"cafe",@"東京",@"Team 7 report",@"budget",@"readme",@"zzzz-missing",@"000999",@"design brief",@"screenshot",@""];
 double samples[360];for(int i=0;i<360;i++){@autoreleasepool{began=Millis();[snapshot search:queries[(NSUInteger)i%queries.count] cancelled:nil];samples[i]=Millis()-began;}}
 qsort(samples,360,sizeof(double),Compare);
 uint64_t steady=Footprint();SHSearchSnapshot *replacement;
 began=Millis();@autoreleasepool{replacement=[[SHSearchSnapshot alloc] initWithEntries:entries generation:2];}double replace=Millis()-began;uint64_t peak=Footprint();
 printf("records=%lu fixture_ms=%.2f prepare_ms=%.2f query_p50_ms=%.3f query_p95_ms=%.3f query_p99_ms=%.3f snapshot_steady_bytes=%llu overlapping_snapshots_bytes=%llu replace_ms=%.2f replacement_count=%lu\n",(unsigned long)count,fixture,prepare,samples[179],samples[341],samples[356],steady,peak,replace,(unsigned long)replacement.count);
}return 0;}
