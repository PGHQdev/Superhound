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
// action @"OK" is the only button; any other action gets a Cancel button too.
static NSInteger Ask(NSString *title,NSString *text,NSString *action,NSView *accessory){
 [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=title;alert.informativeText=text;alert.accessoryView=accessory;BOOL ok=[action isEqual:@"OK"];[alert addButtonWithTitle:ok?NSLocalizedString(@"OK",@"Alert button"):action];if(accessory || !ok)[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Alert button")];
 if(accessory)alert.window.initialFirstResponder=accessory;return [alert runModal];
}
// Posts JSON to the license server; reply gets the decoded answer, or nil and a message for the user.
- (void)post:(NSString *)path body:(NSDictionary *)body reply:(void (^)(NSDictionary *answer,NSString *error))reply {
 NSString *server=[NSUserDefaults.standardUserDefaults stringForKey:@"licenseServer"]?:@"https://superhound.app";
 NSURL *url=[NSURL URLWithString:[server stringByAppendingString:path]];if(!url){reply(nil,[NSString stringWithFormat:NSLocalizedString(@"The license server address %@ is not valid.",@"The argument is a web address"),server]);return;}
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];request.HTTPMethod=@"POST";[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
 _busy=YES;
 [[_session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
  NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;id answer=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;if(![answer isKindOfClass:NSDictionary.class])answer=nil;
  NSString *message=error?[NSString stringWithFormat:NSLocalizedString(@"superhound.app could not be reached. %@",@"The argument is the system network error text"),error.localizedDescription]:status!=200?([answer[@"error"] isKindOfClass:NSString.class]?answer[@"error"]:[NSString stringWithFormat:NSLocalizedString(@"superhound.app answered with error %ld.",@"The argument is an HTTP status code such as 500"),(long)status]):nil;
  dispatch_async(dispatch_get_main_queue(),^{self->_busy=NO;reply(message?nil:answer,message);});
 }] resume];
}
- (void)enterKey:(NSString *)key {
 if(_busy)return;
 NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,320,24)];field.stringValue=key?:@"";field.placeholderString=NSLocalizedString(@"License key",@"Placeholder of the license key field");
 [NSApp activateIgnoringOtherApps:YES];NSAlert *alert=NSAlert.new;alert.messageText=NSLocalizedString(@"Activate Superhound",nil);alert.informativeText=NSLocalizedString(@"Superhound sends the license key and a device ID to superhound.app. The device ID is a one-way hash, so it does not identify you. A license covers 3 Macs.",nil);alert.accessoryView=field;
 [alert addButtonWithTitle:NSLocalizedString(@"Activate",@"Alert button: activate the license key")];[alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Alert button")];[alert addButtonWithTitle:NSLocalizedString(@"Get a License",@"Button that opens the purchase page")];alert.window.initialFirstResponder=field;
 _busy=YES;NSInteger answer=[alert runModal];_busy=NO;
 if(answer==NSAlertThirdButtonReturn){[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://superhound.app/buy"]];return;}
 NSString *entered=[field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(answer!=NSAlertFirstButtonReturn || !entered.length)return;
 [self post:@"/api/activate" body:@{@"key":entered,@"device":_license.device,@"label":[@"Mac " stringByAppendingString:[_license.device substringToIndex:8]]} reply:^(NSDictionary *answer,NSString *error){
  if(!error && ![answer[@"token"] isKindOfClass:NSString.class])error=NSLocalizedString(@"superhound.app sent an answer that Superhound cannot read.",nil);
  if(!error && ![self->_license saveKey:entered token:answer[@"token"]])error=NSLocalizedString(@"The activation from superhound.app is not valid for this Mac.",nil);
  if(error){if(Ask(NSLocalizedString(@"Superhound is not activated",nil),error,NSLocalizedString(@"Try Again",@"Alert button"),nil)==NSAlertFirstButtonReturn)[self enterKey:entered];return;}
  if(self.changed)self.changed();Ask(NSLocalizedString(@"Superhound is licensed",nil),NSLocalizedString(@"Thank you for your purchase.",nil),@"OK",nil);
 }];
}
- (void)deactivate {
 if(_busy || !_license.licensed)return;
 _busy=YES;NSInteger answer=Ask(NSLocalizedString(@"Deactivate this Mac?",nil),NSLocalizedString(@"This frees one of the 3 activations of your license. Superhound keeps working and shows the unlicensed reminder again.",nil),NSLocalizedString(@"Deactivate",@"Alert button: free this Mac’s license activation"),nil);_busy=NO;if(answer!=NSAlertFirstButtonReturn)return;
 [self post:@"/api/deactivate" body:@{@"key":_license.key,@"device":_license.device} reply:^(NSDictionary *answer,NSString *error){
  (void)answer;if(error && Ask(NSLocalizedString(@"This Mac is still activated",nil),[NSString stringWithFormat:NSLocalizedString(@"%@ You can remove the license from this Mac anyway. Its activation then stays in use; write to support@superhound.app to free it.",@"The argument is an error sentence from the license server or the network"),error],NSLocalizedString(@"Remove Anyway",@"Alert button"),nil)!=NSAlertFirstButtonReturn)return;
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
 if(!_license.licensed)[self enterKey:key];else Ask(NSLocalizedString(@"Superhound is already licensed",nil),NSLocalizedString(@"This Mac already has an active license.",nil),@"OK",nil);
}
@end
