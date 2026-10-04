#import <Foundation/Foundation.h>
@interface SHScanner : NSObject
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude progress:(void (^)(NSUInteger))progress error:(NSError **)error;
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error;
+ (NSArray<NSDictionary *> *)scanURL:(NSURL *)url applicationsOnly:(BOOL)apps excludeGenerated:(BOOL)exclude excludingURLs:(NSArray<NSURL *> *)ignored cancelled:(BOOL (^)(void))cancelled progress:(void (^)(NSUInteger))progress error:(NSError **)error;
@end
