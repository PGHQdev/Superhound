#import "SHQueryController.h"
#include <stdatomic.h>
@implementation SHQueryController {
 dispatch_queue_t _worker;
 NSLock *_lock;
 NSString *_pendingQuery;
 void (^_pendingCompletion)(NSArray *);
 SHSearchSnapshot *_pendingSnapshot;
 BOOL _running;
 atomic_uint_fast64_t _ticket;
}
- (instancetype)init {if((self=[super init])){_worker=dispatch_queue_create("com.superhound.query",DISPATCH_QUEUE_SERIAL);_lock=NSLock.new;atomic_init(&_ticket,0);}return self;}
- (void)setSnapshot:(SHSearchSnapshot *)snapshot {NSAssert(NSThread.isMainThread,@"main thread");[self cancel];_snapshot=snapshot;}
- (void)cancel {[_lock lock];atomic_fetch_add(&_ticket,1);_pendingQuery=nil;_pendingCompletion=nil;_pendingSnapshot=nil;[_lock unlock];}
- (void)submit:(NSString *)query completion:(void (^)(NSArray<NSDictionary *> *))completion {
 NSAssert(NSThread.isMainThread,@"main thread");
 [_lock lock];atomic_fetch_add(&_ticket,1);_pendingQuery=[query copy];_pendingCompletion=[completion copy];_pendingSnapshot=_snapshot;
 BOOL start=!_running;_running=YES;[_lock unlock];if(!start)return;
 dispatch_async(_worker,^{
  while(YES){@autoreleasepool {
   [self->_lock lock];
   NSString *q=self->_pendingQuery;void (^done)(NSArray *)=self->_pendingCompletion;
   SHSearchSnapshot *s=self->_pendingSnapshot;uint64_t ticket=atomic_load(&self->_ticket);
   self->_pendingQuery=nil;self->_pendingCompletion=nil;self->_pendingSnapshot=nil;
   if(!q){self->_running=NO;[self->_lock unlock];break;}[self->_lock unlock];
   NSArray *results=[s search:q cancelled:^BOOL{return atomic_load(&self->_ticket)!=ticket;}];
   dispatch_async(dispatch_get_main_queue(),^{if(ticket==atomic_load(&self->_ticket) && self.snapshot==s && done)done(results?:@[]);});
  }}
 });
}
@end
