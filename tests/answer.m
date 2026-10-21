#import <Foundation/Foundation.h>
#import "SHAnswer.h"
#include <assert.h>
// Fixed locales, so the results do not depend on the region of the Mac that runs the tests.
static NSLocale *Posix,*German;
static void In(NSLocale *locale,NSString *query,NSString *name,NSString *copy) {
 NSDictionary *a=[SHAnswer answerForQuery:query locale:locale];
 if(![a[@"name"] isEqual:name] || ![a[@"copy"] isEqual:copy]){fprintf(stderr,"'%s' gave '%s' / '%s'\n",query.UTF8String,[a[@"name"] UTF8String]?:"nil",[a[@"copy"] UTF8String]?:"nil");abort();}
}
static void Is(NSString *query,NSString *name,NSString *copy) {In(Posix,query,name,copy);}
int main(void){@autoreleasepool{
 Posix=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];German=[NSLocale localeWithLocaleIdentifier:@"de_DE"];
 Is(@"48*12",@"= 576",@"576");Is(@" (1200-350)/4 ",@"= 212.5",@"212.5");Is(@"2^10",@"= 1,024",@"1024");Is(@"sqrt(81)",@"= 9",@"9");
 Is(@"1,200 x 3",@"= 3,600",@"3600");Is(@"3x4",@"= 12",@"12");Is(@"0.1+0.2",@"= 0.3",@"0.3");Is(@"-2^2",@"= -4",@"-4");Is(@"2^3^2",@"= 512",@"512");
 Is(@"10 % 3",@"= 1",@"1");Is(@"15% of 240",@"= 36",@"36");Is(@"240 + 15%",@"= 276",@"276");Is(@"240 - 15%",@"= 204",@"204");Is(@"2 * pi",@"= 6.283185307",@"6.283185307");
 Is(@"5 km to mi",@"3.106855961 mi",@"3.106855961");Is(@"72f to c",@"22.22222222 °C",@"22.22222222");Is(@"2.5 lb in kg",@"1.133980925 kg",@"1.133980925");
 Is(@"500 mb to gb",@"0.5 GB",@"0.5");Is(@"2 days to hours",@"48 h",@"48");Is(@"1 cup to ml",@"236.5882365 mL",@"236.5882365");Is(@"1 gal to l",@"3.785411784 L",@"3.785411784");Is(@"16 oz to lb",@"1 lb",@"1");Is(@"5 in to cm",@"12.7 cm",@"12.7");Is(@"(2+3) km to m",@"5,000 m",@"5000");
 Is(@"#ff5733",@"rgb(255, 87, 51)",@"rgb(255, 87, 51)");Is(@"#F53",@"rgb(255, 85, 51)",@"rgb(255, 85, 51)");Is(@"rgb(255, 87, 51)",@"#FF5733",@"#FF5733");Is(@"RGB(255 87 51)",@"#FF5733",@"#FF5733");
 Is(@"hsl(11, 100%, 60%)",@"#FF5833",@"#FF5833");Is(@"hsl(120deg 100% 25%)",@"#008000",@"#008000");Is(@"hsl(360, 100%, 50%)",@"#FF0000",@"#FF0000");Is(@"#000",@"rgb(0, 0, 0)",@"rgb(0, 0, 0)");
 NSDictionary *color=[SHAnswer answerForQuery:@" #ff5733 " locale:Posix];assert(([color[@"color"] isEqual:@"#FF5733"] && [color[@"formats"] isEqual:(@[@"#FF5733",@"rgb(255, 87, 51)",@"hsl(11, 100%, 60%)"])] && [color[@"detail"] isEqual:@"#ff5733"]));
 assert(([[SHAnswer answerForQuery:@"#fff" locale:Posix][@"formats"] isEqual:(@[@"#FFFFFF",@"rgb(255, 255, 255)",@"hsl(0, 0%, 100%)"])]));assert(![SHAnswer answerForQuery:@"48*12" locale:Posix][@"color"]);
 for(NSString *q in @[@"#ff573",@"#gggggg",@"ff5733",@"#",@"rgb(256, 0, 0)",@"rgb(1, 2)",@"rgb(1,2,3,4)",@"hsl(10, 50, 50)",@"hsl(10, 101%, 50%)",@"rgb (1, 2, 3)"])
  if([SHAnswer answerForQuery:q locale:Posix]){fprintf(stderr,"'%s' must give no colour\n",q.UTF8String);abort();}
 for(NSString *q in @[@"",@"2024",@"-5",@"3.14",@"claude",@"a-b",@"report 2024",@"1/0",@"5 km",@"5 km to kg",@"5 km to",@"2 +",@"(2+3",@"e",@"pi",@"x",@"main.c",@"5 to 6"])
  if([SHAnswer answerForQuery:q locale:Posix]){fprintf(stderr,"'%s' must give no answer\n",q.UTF8String);abort();}
 // A lone comma before 1, 2, or 4 or more digits is decimal everywhere; before 3 digits it follows the locale. Answers use the locale's separators.
 Is(@"1,5*2",@"= 3",@"3");Is(@"1,5+1",@"= 2.5",@"2.5");Is(@"0,25 x 4",@"= 1",@"1");Is(@"1,2345*2",@"= 2.469",@"2.469");Is(@"1,234.5+0.5",@"= 1,235",@"1235");Is(@"1.234,5+0,5",@"= 1,235",@"1235");Is(@"1.234.567+1",@"= 1,234,568",@"1234568");Is(@"1,5 km to m",@"1,500 m",@"1500");
 In(German,@"1,5+1",@"= 2,5",@"2,5");In(German,@"1,200 x 3",@"= 3,6",@"3,6");In(German,@"1.234,5+0,5",@"= 1.235",@"1235");In(German,@"1.234.567+1",@"= 1.234.568",@"1234568");In(German,@"2^10",@"= 1.024",@"1024");
 In(German,@"5,5 km to m",@"5.500 m",@"5500");In(German,@"72f to c",@"22,22222222 °C",@"22,22222222");In(German,@"(1200-350)/4",@"= 212,5",@"212,5");
 for(NSString *q in @[@"1,2,3+1",@"1.2.3+1",@"1,23,456+1",@"1,234,56+1",@"1.234,5.6+1",@"1,2.3,4+1",@"1,5"])
  if([SHAnswer answerForQuery:q locale:Posix] || [SHAnswer answerForQuery:q locale:German]){fprintf(stderr,"'%s' must give no answer\n",q.UTF8String);abort();}
 for(int k=0;k<20000;k++){unichar c[40];NSUInteger n=arc4random_uniform(40);const char *set="0123456789+-*/^%().,x ofpiesqrtkm";for(NSUInteger i=0;i<n;i++)c[i]=(unichar)set[arc4random_uniform(34)];[SHAnswer answerForQuery:[NSString stringWithCharacters:c length:n] locale:k%2?Posix:German];}
 puts("PASS answer: arithmetic, percent, decimal commas and locales, unit conversion, colours, rejected input, 20000 random inputs");
}return 0;}
