#import "SHAnswer.h"
#include <math.h>
#include <stdlib.h>
// op: an operator or function was used, so a plain number gives no answer.
// percent: the value just parsed is a bare percent such as "15%".
typedef struct { const unichar *s; NSUInteger n,i; BOOL ok,op,percent; } Parser;
static double Expression(Parser *p);
static double Unary(Parser *p);
static unichar Peek(Parser *p) {while(p->i<p->n && p->s[p->i]==' ')p->i++;return p->i<p->n?p->s[p->i]:0;}
static BOOL Letter(unichar c) {return c<128 && ((c>='a' && c<='z') || (c>='A' && c<='Z'));}
static BOOL Digit(unichar c) {return c>='0' && c<='9';}
static BOOL StartsValue(unichar c) {return Digit(c) || c=='.' || c=='(';}
static BOOL Word(Parser *p,const char *word) {
 Peek(p);NSUInteger k=p->i;
 for(;*word;word++,k++)if(k>=p->n || (p->s[k]|32)!=(unichar)*word)return NO;
 if(k<p->n && Letter(p->s[k]))return NO;
 p->i=k;return YES;
}
static double Primary(Parser *p) {
 unichar c=Peek(p);
 if(c=='('){p->i++;double v=Expression(p);if(Peek(p)!=')')p->ok=NO;else p->i++;p->percent=NO;return v;}
 if(Digit(c) || c=='.'){
  char digits[64];size_t length=0;BOOL any=NO;
  while(p->i<p->n && length<63){
   c=p->s[p->i];
   if(Digit(c)){digits[length++]=(char)c;any=YES;}
   else if(c=='.')digits[length++]='.';
   else if(!(c==',' && p->i+1<p->n && Digit(p->s[p->i+1])))break;
   p->i++;
  }
  digits[length]=0;char *end=NULL;double v=strtod(digits,&end);if(!any || *end)p->ok=NO;return v;
 }
 static const char *names[]={"sqrt","abs","round","floor","ceil","sin","cos","tan","ln","log"};
 for(int f=0;f<10;f++)if(Word(p,names[f])){
  if(Peek(p)!='('){p->ok=NO;return 0;}
  double v=Primary(p);p->op=YES;
  switch(f){case 0:return sqrt(v);case 1:return fabs(v);case 2:return round(v);case 3:return floor(v);case 4:return ceil(v);case 5:return sin(v);case 6:return cos(v);case 7:return tan(v);case 8:return log(v);default:return log10(v);}
 }
 if(Word(p,"pi"))return M_PI;
 if(Word(p,"e"))return M_E;
 p->ok=NO;return 0;
}
static double Postfix(Parser *p) {
 double v=Primary(p);p->percent=NO;
 if(Peek(p)=='%'){
  // "10 % 3" is a remainder; "15%" with no value after it is a percent.
  NSUInteger save=p->i;p->i++;unichar next=Peek(p);
  if(StartsValue(next))p->i=save;else {v/=100;p->percent=YES;p->op=YES;}
 }
 return v;
}
static double Power(Parser *p) {
 double v=Postfix(p);
 if(Peek(p)=='^'){p->i++;v=pow(v,Unary(p));p->op=YES;p->percent=NO;}
 return v;
}
static double Unary(Parser *p) {
 unichar c=Peek(p);
 if(c=='-' || c==0x2212){p->i++;return -Unary(p);}
 if(c=='+'){p->i++;return Unary(p);}
 return Power(p);
}
static double Term(Parser *p) {
 double v=Unary(p);
 while(p->ok){
  unichar c=Peek(p);
  if(c=='*' || c==0xD7){p->i++;v*=Unary(p);}
  else if(c=='/' || c==0xF7){p->i++;v/=Unary(p);}
  else if(c=='%'){p->i++;v=fmod(v,Unary(p));}
  else if((c=='x' || c=='X') && p->i+1<p->n && (StartsValue(p->s[p->i+1]) || p->s[p->i+1]==' ')){p->i++;v*=Unary(p);}
  else if(Word(p,"of"))v*=Unary(p);
  else break;
  p->op=YES;p->percent=NO;
 }
 return v;
}
static double Expression(Parser *p) {
 double v=Term(p);
 while(p->ok){
  unichar c=Peek(p);BOOL minus=c=='-' || c==0x2212;
  if(c!='+' && !minus)break;
  p->i++;double right=Term(p);
  // "240 + 15%" adds 15 percent of 240.
  if(p->percent)right*=v;
  v=minus?v-right:v+right;p->op=YES;p->percent=NO;
 }
 return v;
}
static BOOL Evaluate(NSString *text,BOOL needsOperator,double *value) {
 NSUInteger n=text.length;if(!n || n>200)return NO;
 unichar buffer[200];[text getCharacters:buffer range:NSMakeRange(0,n)];
 Parser p={buffer,n,0,YES,NO,NO};double v=Expression(&p);Peek(&p);
 if(!p.ok || p.i!=n || (needsOperator && !p.op) || !isfinite(v))return NO;
 *value=v;return YES;
}
static NSString *Format(double value,BOOL grouping) {
 NSNumberFormatter *f=NSNumberFormatter.new;f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.numberStyle=NSNumberFormatterDecimalStyle;
 f.usesSignificantDigits=YES;f.minimumSignificantDigits=1;f.maximumSignificantDigits=10;f.usesGroupingSeparator=grouping;
 if(value!=0 && (fabs(value)>=1e15 || fabs(value)<1e-9))f.numberStyle=NSNumberFormatterScientificStyle;
 return [f stringFromNumber:@(value==0?0:value)];
}
// Each row: unit, symbol to show, then the names accepted in a query.
static NSDictionary<NSString *,NSArray *> *Units(void) {
 static NSDictionary *units;static dispatch_once_t once;
 dispatch_once(&once,^{
  NSUnitDuration *day=[[NSUnitDuration alloc] initWithSymbol:@"d" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:86400]];
  NSUnitDuration *week=[[NSUnitDuration alloc] initWithSymbol:@"wk" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:604800]];
  // Foundation rounds its US customary factors to 6 digits; these are the exact definitions.
  NSUnitMass *(^mass)(double)=^(double kilograms){return [[NSUnitMass alloc] initWithSymbol:@"" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:kilograms]];};
  NSUnitVolume *(^volume)(double)=^(double liters){return [[NSUnitVolume alloc] initWithSymbol:@"" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:liters]];};
  NSArray *rows=@[
   @[NSUnitLength.millimeters,@"mm",@"mm",@"millimeter",@"millimetre"],@[NSUnitLength.centimeters,@"cm",@"cm",@"centimeter",@"centimetre"],@[NSUnitLength.meters,@"m",@"m",@"meter",@"metre"],@[NSUnitLength.kilometers,@"km",@"km",@"kilometer",@"kilometre"],
   @[NSUnitLength.inches,@"in",@"in",@"inch",@"inches"],@[NSUnitLength.feet,@"ft",@"ft",@"foot",@"feet"],@[NSUnitLength.yards,@"yd",@"yd",@"yard"],@[NSUnitLength.miles,@"mi",@"mi",@"mile"],
   @[NSUnitMass.milligrams,@"mg",@"mg",@"milligram"],@[NSUnitMass.grams,@"g",@"g",@"gram"],@[NSUnitMass.kilograms,@"kg",@"kg",@"kilo",@"kilogram"],@[NSUnitMass.metricTons,@"t",@"t",@"ton",@"tonne"],
   @[mass(0.028349523125),@"oz",@"oz",@"ounce"],@[mass(0.45359237),@"lb",@"lb",@"lbs",@"pound"],@[mass(6.35029318),@"st",@"st",@"stone"],
   @[NSUnitTemperature.celsius,@"°C",@"c",@"°c",@"celsius"],@[NSUnitTemperature.fahrenheit,@"°F",@"f",@"°f",@"fahrenheit"],@[NSUnitTemperature.kelvin,@"K",@"k",@"kelvin"],
   @[NSUnitVolume.milliliters,@"mL",@"ml",@"milliliter",@"millilitre"],@[NSUnitVolume.liters,@"L",@"l",@"liter",@"litre"],@[volume(0.00492892159375),@"tsp",@"tsp",@"teaspoon"],@[volume(0.01478676478125),@"tbsp",@"tbsp",@"tablespoon"],
   @[volume(0.2365882365),@"cups",@"cup"],@[volume(0.0295735295625),@"fl oz",@"floz"],@[volume(0.473176473),@"pt",@"pt",@"pint"],@[volume(0.946352946),@"qt",@"qt",@"quart"],@[volume(3.785411784),@"gal",@"gal",@"gallon"],
   @[NSUnitInformationStorage.bits,@"bit",@"bit"],@[NSUnitInformationStorage.bytes,@"B",@"b",@"byte"],@[NSUnitInformationStorage.kilobytes,@"kB",@"kb",@"kilobyte"],@[NSUnitInformationStorage.megabytes,@"MB",@"mb",@"megabyte"],
   @[NSUnitInformationStorage.gigabytes,@"GB",@"gb",@"gigabyte"],@[NSUnitInformationStorage.terabytes,@"TB",@"tb",@"terabyte"],
   @[NSUnitInformationStorage.kibibytes,@"KiB",@"kib"],@[NSUnitInformationStorage.mebibytes,@"MiB",@"mib"],@[NSUnitInformationStorage.gibibytes,@"GiB",@"gib"],@[NSUnitInformationStorage.tebibytes,@"TiB",@"tib"],
   @[NSUnitDuration.milliseconds,@"ms",@"ms",@"millisecond"],@[NSUnitDuration.seconds,@"s",@"s",@"sec",@"second"],@[NSUnitDuration.minutes,@"min",@"min",@"minute"],@[NSUnitDuration.hours,@"h",@"h",@"hr",@"hour"],
   @[day,@"d",@"d",@"day"],@[week,@"wk",@"wk",@"week"]];
  NSMutableDictionary *map=NSMutableDictionary.dictionary;
  for(NSArray *row in rows)for(NSUInteger i=2;i<row.count;i++)map[row[i]]=row;
  units=map;
 });
 return units;
}
static NSArray *Unit(NSString *name) {
 name=name.lowercaseString;NSArray *row=Units()[name];
 if(!row && name.length>2 && [name hasSuffix:@"s"])row=Units()[[name substringToIndex:name.length-1]];
 return row;
}
// "#RGB", "#RRGGBB", "rgb(r, g, b)", or "hsl(h, s%, l%)", with commas or spaces; gives red, green, and blue from 0 to 255.
static BOOL Color(NSString *input,int rgb[3],BOOL *hex) {
 static NSRegularExpression *hexForm,*rgbForm,*hslForm;static dispatch_once_t once;
 dispatch_once(&once,^{
  hexForm=[NSRegularExpression regularExpressionWithPattern:@"^#([0-9a-f]{3}|[0-9a-f]{6})$" options:NSRegularExpressionCaseInsensitive error:nil];
  rgbForm=[NSRegularExpression regularExpressionWithPattern:@"^rgb\\( ?([0-9]{1,3}) ?[, ] ?([0-9]{1,3}) ?[, ] ?([0-9]{1,3}) ?\\)$" options:NSRegularExpressionCaseInsensitive error:nil];
  hslForm=[NSRegularExpression regularExpressionWithPattern:@"^hsl\\( ?([0-9]{1,3}(?:\\.[0-9]+)?)(?:deg)? ?[, ] ?([0-9]{1,3}(?:\\.[0-9]+)?)% ?[, ] ?([0-9]{1,3}(?:\\.[0-9]+)?)% ?\\)$" options:NSRegularExpressionCaseInsensitive error:nil];
 });
 NSRange all=NSMakeRange(0,input.length);NSTextCheckingResult *m;
 if((m=[hexForm firstMatchInString:input options:0 range:all])){
  NSString *digits=[input substringWithRange:[m rangeAtIndex:1]];
  if(digits.length==3)digits=[NSString stringWithFormat:@"%C%C%C%C%C%C",[digits characterAtIndex:0],[digits characterAtIndex:0],[digits characterAtIndex:1],[digits characterAtIndex:1],[digits characterAtIndex:2],[digits characterAtIndex:2]];
  unsigned value=0;[[NSScanner scannerWithString:digits] scanHexInt:&value];rgb[0]=(value>>16)&255;rgb[1]=(value>>8)&255;rgb[2]=value&255;*hex=YES;return YES;
 }
 *hex=NO;
 if((m=[rgbForm firstMatchInString:input options:0 range:all])){
  for(int i=0;i<3;i++){rgb[i]=[input substringWithRange:[m rangeAtIndex:(NSUInteger)i+1]].intValue;if(rgb[i]>255)return NO;}
  return YES;
 }
 if((m=[hslForm firstMatchInString:input options:0 range:all])){
  double h=fmod([input substringWithRange:[m rangeAtIndex:1]].doubleValue,360)/60,s=[input substringWithRange:[m rangeAtIndex:2]].doubleValue/100,l=[input substringWithRange:[m rangeAtIndex:3]].doubleValue/100;
  if(s>1 || l>1)return NO;
  double c=(1-fabs(2*l-1))*s,x=c*(1-fabs(fmod(h,2)-1)),light=l-c/2,r=0,g=0,b=0;
  if(h<1){r=c;g=x;}else if(h<2){r=x;g=c;}else if(h<3){g=c;b=x;}else if(h<4){g=x;b=c;}else if(h<5){r=x;b=c;}else {r=c;b=x;}
  rgb[0]=(int)lround((r+light)*255);rgb[1]=(int)lround((g+light)*255);rgb[2]=(int)lround((b+light)*255);return YES;
 }
 return NO;
}
static NSArray<NSString *> *ColorForms(const int rgb[3]) {
 double r=rgb[0]/255.0,g=rgb[1]/255.0,b=rgb[2]/255.0,high=fmax(r,fmax(g,b)),low=fmin(r,fmin(g,b)),d=high-low,l=(high+low)/2,s=d?d/(1-fabs(2*l-1)):0,h=0;
 if(d){h=high==r?fmod((g-b)/d+6,6):high==g?(b-r)/d+2:(r-g)/d+4;}
 return @[[NSString stringWithFormat:@"#%02X%02X%02X",rgb[0],rgb[1],rgb[2]],[NSString stringWithFormat:@"rgb(%d, %d, %d)",rgb[0],rgb[1],rgb[2]],[NSString stringWithFormat:@"hsl(%ld, %ld%%, %ld%%)",lround(h*60)%360,lround(s*100),lround(l*100)]];
}
@implementation SHAnswer
+ (NSDictionary *)answerForQuery:(NSString *)query {
 NSMutableArray<NSString *> *words=NSMutableArray.array;
 for(NSString *w in [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet])if(w.length)[words addObject:w];
 if(!words.count)return nil;
 NSString *input=[words componentsJoinedByString:@" "];double value=0;
 if(Evaluate(input,YES,&value))return @{@"type":@"answer",@"id":@"answer",@"name":[@"= " stringByAppendingString:Format(value,YES)],@"copy":Format(value,NO),@"detail":input};
 // A colour shows in another form: a hex value as rgb, and rgb or hsl as hex.
 int rgb[3];BOOL hex=NO;
 if(Color(input,rgb,&hex)){NSArray *forms=ColorForms(rgb);NSString *shown=hex?forms[1]:forms[0];return @{@"type":@"answer",@"id":@"answer",@"name":shown,@"copy":shown,@"detail":input,@"color":forms[0],@"formats":forms};}
 // Conversion: "<value> <unit> to <unit>", for example "5 km to mi" or "72f in c".
 NSArray *target=words.count>=3 && [@[@"to",@"in",@"as",@"->",@"→",@"="] containsObject:words[words.count-2].lowercaseString]?Unit(words.lastObject):nil;
 if(!target)return nil;
 NSString *source=[[words subarrayWithRange:NSMakeRange(0,words.count-2)] componentsJoinedByString:@" "];
 NSUInteger split=source.length;
 while(split>0 && ([NSCharacterSet.letterCharacterSet characterIsMember:[source characterAtIndex:split-1]] || [source characterAtIndex:split-1]==0xB0))split--;
 NSArray *from=Unit([source substringFromIndex:split]);
 NSString *amount=[[source substringToIndex:split] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
 if(!from || ![[[from[0] class] baseUnit] isEqual:[[target[0] class] baseUnit]] || !Evaluate(amount,NO,&value))return nil;
 double converted=[[[NSMeasurement alloc] initWithDoubleValue:value unit:from[0]] measurementByConvertingToUnit:target[0]].doubleValue;
 if(!isfinite(converted))return nil;
 return @{@"type":@"answer",@"id":@"answer",@"name":[NSString stringWithFormat:@"%@ %@",Format(converted,YES),target[1]],@"copy":Format(converted,NO),@"detail":[NSString stringWithFormat:@"%@ %@",Format(value,YES),from[1]]};
}
@end
