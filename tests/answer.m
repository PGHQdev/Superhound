#import <Foundation/Foundation.h>
#import "SHAnswer.h"
#include <assert.h>
static void Is(NSString *query,NSString *name,NSString *copy) {
 NSDictionary *a=[SHAnswer answerForQuery:query];
 if(![a[@"name"] isEqual:name] || ![a[@"copy"] isEqual:copy]){fprintf(stderr,"'%s' gave '%s' / '%s'\n",query.UTF8String,[a[@"name"] UTF8String]?:"nil",[a[@"copy"] UTF8String]?:"nil");abort();}
}
int main(void){@autoreleasepool{
 Is(@"48*12",@"= 576",@"576");Is(@" (1200-350)/4 ",@"= 212.5",@"212.5");Is(@"2^10",@"= 1,024",@"1024");Is(@"sqrt(81)",@"= 9",@"9");
 Is(@"1,200 x 3",@"= 3,600",@"3600");Is(@"3x4",@"= 12",@"12");Is(@"0.1+0.2",@"= 0.3",@"0.3");Is(@"-2^2",@"= -4",@"-4");Is(@"2^3^2",@"= 512",@"512");
 Is(@"10 % 3",@"= 1",@"1");Is(@"15% of 240",@"= 36",@"36");Is(@"240 + 15%",@"= 276",@"276");Is(@"240 - 15%",@"= 204",@"204");Is(@"2 * pi",@"= 6.283185307",@"6.283185307");
 Is(@"5 km to mi",@"3.106855961 mi",@"3.106855961");Is(@"72f to c",@"22.22222222 °C",@"22.22222222");Is(@"2.5 lb in kg",@"1.133980925 kg",@"1.133980925");
 Is(@"500 mb to gb",@"0.5 GB",@"0.5");Is(@"2 days to hours",@"48 h",@"48");Is(@"1 cup to ml",@"236.5882365 mL",@"236.5882365");Is(@"1 gal to l",@"3.785411784 L",@"3.785411784");Is(@"16 oz to lb",@"1 lb",@"1");Is(@"5 in to cm",@"12.7 cm",@"12.7");Is(@"(2+3) km to m",@"5,000 m",@"5000");
 for(NSString *q in @[@"",@"2024",@"-5",@"3.14",@"claude",@"a-b",@"report 2024",@"1/0",@"5 km",@"5 km to kg",@"5 km to",@"2 +",@"(2+3",@"e",@"pi",@"x",@"main.c",@"5 to 6"])
  if([SHAnswer answerForQuery:q]){fprintf(stderr,"'%s' must give no answer\n",q.UTF8String);abort();}
 for(int k=0;k<20000;k++){unichar c[40];NSUInteger n=arc4random_uniform(40);const char *set="0123456789+-*/^%().,x ofpiesqrtkm";for(NSUInteger i=0;i<n;i++)c[i]=(unichar)set[arc4random_uniform(34)];[SHAnswer answerForQuery:[NSString stringWithCharacters:c length:n]];}
 puts("PASS answer: arithmetic, percent, unit conversion, rejected input, 20000 random inputs");
}return 0;}
