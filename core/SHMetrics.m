#import "SHMetrics.h"
#include <time.h>
double SHTime(void){return (double)clock_gettime_nsec_np(CLOCK_UPTIME_RAW)/1e9;}
void SHMeasure(NSString *name,double started){
 if(![NSUserDefaults.standardUserDefaults boolForKey:@"measurePerformance"])return;
 double milliseconds=(SHTime()-started)*1000;
 static dispatch_queue_t queue;static dispatch_once_t once;
 dispatch_once(&once,^{queue=dispatch_queue_create("com.superhound.measurements",DISPATCH_QUEUE_SERIAL);});
 dispatch_async(queue,^{@autoreleasepool{
  NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  NSURL *folder=[base URLByAppendingPathComponent:@"Superhound" isDirectory:YES];
  [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
  NSURL *file=[folder URLByAppendingPathComponent:@"performance.jsonl"];
  if(![NSFileManager.defaultManager fileExistsAtPath:file.path])[NSData.data writeToURL:file atomically:YES];
  NSFileHandle *handle=[NSFileHandle fileHandleForWritingToURL:file error:nil];
  NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"metric":name,@"milliseconds":@(milliseconds),@"time":@(NSDate.date.timeIntervalSince1970)} options:NSJSONWritingSortedKeys error:nil];
  if([handle seekToEndReturningOffset:NULL error:nil]){[handle writeData:data error:nil];[handle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding] error:nil];}[handle closeAndReturnError:nil];
 }});
}
