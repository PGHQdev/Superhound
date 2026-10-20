#import <Foundation/Foundation.h>
// Quick answers: arithmetic, percent, unit conversion, and colour values, computed offline.
@interface SHAnswer : NSObject
// Returns nil unless the whole query is a calculation or a conversion.
// Keys: type "answer", id, name (text to show), copy (text for the pasteboard), detail (the input).
// A colour also has color (its "#RRGGBB" value) and formats (hex, rgb, and hsl).
+ (NSDictionary *)answerForQuery:(NSString *)query;
@end
