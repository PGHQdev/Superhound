#import <Foundation/Foundation.h>
// Opt-in local timing, enabled with `defaults write com.superhound.app measurePerformance -bool YES`.
double SHTime(void);
void SHMeasure(NSString *name,double started);
