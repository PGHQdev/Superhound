#import <Foundation/Foundation.h>
#import "SHCatalog.h"
#import "SHScanner.h"
#import <libproc.h>
#include <time.h>
static double Now(void){return (double)clock_gettime_nsec_np(CLOCK_UPTIME_RAW)/1e6;}
static uint64_t PeakFootprint(void){struct rusage_info_v4 usage={0};proc_pid_rusage(getpid(),RUSAGE_INFO_V4,(rusage_info_t *)&usage);return usage.ri_lifetime_max_phys_footprint;}
static uint64_t Footprint(void){struct rusage_info_v4 usage={0};proc_pid_rusage(getpid(),RUSAGE_INFO_V4,(rusage_info_t *)&usage);return usage.ri_phys_footprint;}
int main(void){@autoreleasepool{
 NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
 NSURL *tree=[tmp URLByAppendingPathComponent:@"tree"],*db=[tmp URLByAppendingPathComponent:@"catalog.sqlite"];
 NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtURL:tree withIntermediateDirectories:YES attributes:nil error:nil];
 for(int i=0;i<10000;i++){@autoreleasepool{NSURL *file=[tree URLByAppendingPathComponent:[NSString stringWithFormat:@"report %05d.txt",i]];if(![NSData.data writeToURL:file atomically:YES])return 1;}}
 NSError *error=nil;uint64_t before=Footprint();double start=Now();NSArray *entries=[SHScanner scanURL:tree applicationsOnly:NO excludeGenerated:YES progress:nil error:&error];double scan=Now()-start;if(!entries)return 1;uint64_t scanPeak=PeakFootprint()>before?PeakFootprint()-before:0;
 start=Now();SHCatalog *catalog=[[SHCatalog alloc] initWithURL:db error:&error];if(![catalog replaceRoot:@"synthetic" entries:entries error:&error])return 1;double commit=Now()-start;catalog=nil;
 start=Now();catalog=[[SHCatalog alloc] initWithURL:db error:&error];NSArray *loaded=[catalog entriesForRoot:@"synthetic"];double warm=Now()-start;
 printf("records=%lu scan_ms=%.2f scan_peak_growth_bytes=%llu create_and_commit_ms=%.2f warm_catalog_load_ms=%.2f catalog_bytes=%llu\n",(unsigned long)loaded.count,scan,scanPeak,commit,warm,[[fm attributesOfItemAtPath:db.path error:nil][NSFileSize] unsignedLongLongValue]);
 catalog=nil;[fm removeItemAtURL:tmp error:nil];
}return 0;}
