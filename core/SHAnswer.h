#import <Foundation/Foundation.h>
// Quick answers: arithmetic, percent, and unit conversion, computed offline.
@interface SHAnswer : NSObject
// Returns nil unless the whole query is a calculation or a conversion.
// Keys: type "answer", id, name (text to show), copy (text for the pasteboard), detail (the input).
+ (NSDictionary *)answerForQuery:(NSString *)query;
@end
