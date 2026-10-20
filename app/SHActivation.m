#import "SHActivation.h"
#import <IOKit/IOKitLib.h>
NSString *SHHardwareUUID(void){
 io_service_t service=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("IOPlatformExpertDevice"));if(!service)return nil;
 NSString *uuid=CFBridgingRelease(IORegistryEntryCreateCFProperty(service,CFSTR(kIOPlatformUUIDKey),kCFAllocatorDefault,0));IOObjectRelease(service);return [uuid isKindOfClass:NSString.class]?uuid:nil;
}
@implementation SHActivation {SHLicense *_license;NSURLSession *_session;BOOL _busy;}
- (instancetype)initWithLicense:(SHLicense *)license {
 if((self=[super init])){_license=license;NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;configuration.timeoutIntervalForRequest=20;_session=[NSURLSession sessionWithConfiguration:configuration];}
 return self;
}
static NSInteger Ask(NSString *title,NSString *text,NSString *action,NSView *accessory){
 [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=title;alert.informativeText=text;alert.accessoryView=accessory;[alert addButtonWithTitle:action];if(accessory || ![action isEqual:@"OK"])[alert addButtonWithTitle:@"Cancel"];
 if(accessory)alert.window.initialFirstResponder=accessory;return [alert runModal];
}
// Posts JSON to the license server; reply gets the decoded answer, or nil and a message for the user.
- (void)post:(NSString *)path body:(NSDictionary *)body reply:(void (^)(NSDictionary *answer,NSString *error))reply {
 NSString *server=[NSUserDefaults.standardUserDefaults stringForKey:@"licenseServer"]?:@"https://superhound.app";
 NSURL *url=[NSURL URLWithString:[server stringByAppendingString:path]];if(!url){reply(nil,[NSString stringWithFormat:@"The license server address %@ is not valid.",server]);return;}
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];request.HTTPMethod=@"POST";[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
 _busy=YES;
 [[_session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
  NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;id answer=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;if(![answer isKindOfClass:NSDictionary.class])answer=nil;
  NSString *message=error?[NSString stringWithFormat:@"superhound.app could not be reached. %@",error.localizedDescription]:status!=200?([answer[@"error"] isKindOfClass:NSString.class]?answer[@"error"]:[NSString stringWithFormat:@"superhound.app answered with error %ld.",(long)status]):nil;
  dispatch_async(dispatch_get_main_queue(),^{self->_busy=NO;reply(message?nil:answer,message);});
 }] resume];
}
- (void)enterKey:(NSString *)key {
 if(_busy)return;
 NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,320,24)];field.stringValue=key?:@"";field.placeholderString=@"License key";
 [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=@"Activate Superhound";alert.informativeText=@"Superhound sends the license key and a device ID to superhound.app. The device ID is a one-way hash, so it does not identify you. A license covers 3 Macs.";alert.accessoryView=field;
 [alert addButtonWithTitle:@"Activate"];[alert addButtonWithTitle:@"Cancel"];[alert addButtonWithTitle:@"Buy License"];alert.window.initialFirstResponder=field;
 _busy=YES;NSInteger answer=[alert runModal];_busy=NO;
 if(answer==NSAlertThirdButtonReturn){[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://superhound.app/buy"]];return;}
 NSString *entered=[field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(answer!=NSAlertFirstButtonReturn || !entered.length)return;
 [self post:@"/api/activate" body:@{@"key":entered,@"device":_license.device,@"label":[@"Mac " stringByAppendingString:[_license.device substringToIndex:8]]} reply:^(NSDictionary *answer,NSString *error){
  if(!error && ![answer[@"token"] isKindOfClass:NSString.class])error=@"superhound.app sent an answer that Superhound cannot read.";
  if(!error && ![self->_license saveKey:entered token:answer[@"token"]])error=@"The activation from superhound.app is not valid for this Mac.";
  if(error){if(Ask(@"Superhound is not activated",error,@"Try Again",nil)==NSAlertFirstButtonReturn)[self enterKey:entered];return;}
  if(self.changed)self.changed();Ask(@"Superhound is licensed",@"Thank you for your purchase.",@"OK",nil);
 }];
}
- (void)deactivate {
 if(_busy || !_license.licensed)return;
 _busy=YES;NSInteger answer=Ask(@"Deactivate this Mac?",@"This frees one of the 3 activations of your license. Superhound keeps working and shows the unlicensed reminder again.",@"Deactivate",nil);_busy=NO;if(answer!=NSAlertFirstButtonReturn)return;
 [self post:@"/api/deactivate" body:@{@"key":_license.key,@"device":_license.device} reply:^(NSDictionary *answer,NSString *error){
  (void)answer;if(error && Ask(@"This Mac is still activated",[error stringByAppendingString:@" You can remove the license from this Mac anyway. Its activation then stays in use; write to support@superhound.app to free it."],@"Remove Anyway",nil)!=NSAlertFirstButtonReturn)return;
  [self->_license remove];if(self.changed)self.changed();
 }];
}
- (void)releaseThen:(void (^)(NSString *error))done {
 if(!_license.licensed){done(nil);return;}
 [self post:@"/api/deactivate" body:@{@"key":_license.key,@"device":_license.device} reply:^(NSDictionary *answer,NSString *error){(void)answer;[self->_license remove];done(error);}];
}
- (void)openURL:(NSURL *)url {
 NSURLComponents *parts=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];if(![parts.scheme isEqual:@"superhound"] || ![parts.host isEqual:@"activate"])return;
 NSString *key=nil;for(NSURLQueryItem *item in parts.queryItems)if([item.name isEqual:@"key"])key=item.value;
 // A link from any web page can open this, so the user always confirms in the key window.
 if(!_license.licensed)[self enterKey:key];else Ask(@"Superhound is already licensed",@"This Mac already has an active license.",@"OK",nil);
}
@end
