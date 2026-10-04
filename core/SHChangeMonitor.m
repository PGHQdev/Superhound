#import "SHChangeMonitor.h"
#import <CoreServices/CoreServices.h>
@implementation SHChangeMonitor {
 FSEventStreamRef _stream;
 dispatch_queue_t _queue;
 dispatch_source_t _timer;
 void (^_changed)(BOOL);
 NSTimeInterval _first;
 BOOL _invalidated;
}
static void Events(ConstFSEventStreamRef stream,void *info,size_t count,void *paths,const FSEventStreamEventFlags flags[],const FSEventStreamEventId ids[]) {
 (void)stream;(void)paths;(void)ids;
 SHChangeMonitor *monitor=(__bridge SHChangeMonitor *)info;
 BOOL invalid=NO;
 for(size_t i=0;i<count;i++)if(flags[i]&(kFSEventStreamEventFlagMustScanSubDirs|kFSEventStreamEventFlagUserDropped|kFSEventStreamEventFlagKernelDropped|kFSEventStreamEventFlagRootChanged|kFSEventStreamEventFlagUnmount))invalid=YES;
 [monitor dirty:invalid];
}
- (instancetype)initWithURL:(NSURL *)url excludingURLs:(NSArray<NSURL *> *)ignored changed:(void (^)(BOOL))changed {
 if(!(self=[super init]))return nil;
 _changed=[changed copy];_queue=dispatch_queue_create("com.superhound.changes",DISPATCH_QUEUE_SERIAL);
 dispatch_queue_set_specific(_queue,(__bridge const void *)self,(__bridge void *)self,NULL);
 _timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_queue);
 __weak typeof(self) weak=self;
 dispatch_source_set_event_handler(_timer,^{[weak fire];});
 dispatch_source_set_timer(_timer,DISPATCH_TIME_FOREVER,DISPATCH_TIME_FOREVER,0);dispatch_resume(_timer);
 FSEventStreamContext context={0,(__bridge void *)self,NULL,NULL,NULL};
 _stream=FSEventStreamCreate(NULL,Events,&context,(__bridge CFArrayRef)@[url.path],kFSEventStreamEventIdSinceNow,0.2,kFSEventStreamCreateFlagWatchRoot|kFSEventStreamCreateFlagFileEvents|kFSEventStreamCreateFlagNoDefer);
 if(!_stream)return nil;
 if(ignored.count)FSEventStreamSetExclusionPaths(_stream,(__bridge CFArrayRef)[ignored valueForKey:@"path"]);
 FSEventStreamSetDispatchQueue(_stream,_queue);
 if(!FSEventStreamStart(_stream))return nil;
 return self;
}
- (void)dirty:(BOOL)invalid {
 NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;if(!_first)_first=now;
 _invalidated|=invalid;
 if(invalid && _changed)_changed(YES);
 NSTimeInterval delay=MAX(0,MIN(2.0,10.0-(now-_first)));
 dispatch_source_set_timer(_timer,dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),DISPATCH_TIME_FOREVER,NSEC_PER_MSEC*50);
}
- (void)fire {_first=0;BOOL invalid=_invalidated;_invalidated=NO;dispatch_source_set_timer(_timer,DISPATCH_TIME_FOREVER,DISPATCH_TIME_FOREVER,0);if(_changed)_changed(invalid);}
- (void)stop {
 if(_stream){FSEventStreamStop(_stream);FSEventStreamInvalidate(_stream);FSEventStreamRelease(_stream);_stream=NULL;}
 if(_timer){dispatch_source_cancel(_timer);_timer=nil;}
 // Drain callbacks before releasing the context's unretained self pointer.
 if(_queue && !dispatch_get_specific((__bridge const void *)self))dispatch_sync(_queue,^{});
 _changed=nil;
}
- (void)dealloc {[self stop];}
@end
