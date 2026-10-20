#import "SHHotKey.h"
#import <Carbon/Carbon.h>
@implementation SHHotKey {EventHotKeyRef _key;EventHandlerRef _handler;UInt32 _identifier,_code,_modifiers;NSString *_name,*_menu;OSStatus _error;}
// Each shortcut has its own handler; a press of the other shortcut goes on to the next handler.
static OSStatus Invoked(EventHandlerCallRef next,EventRef event,void *context){
 (void)next;SHHotKey *self=(__bridge SHHotKey *)context;EventHotKeyID pressed={0,0};
 if(GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(pressed),NULL,&pressed)!=noErr || pressed.id!=self->_identifier)return eventNotHandledErr;
 if(self.invoked)self.invoked();return noErr;
}
- (instancetype)initWithName:(NSString *)name identifier:(UInt32)identifier code:(UInt32)code modifiers:(UInt32)modifiers label:(NSString *)label menu:(NSString *)menu {
 if((self=[super init])){_name=name;_identifier=identifier;_code=code;_modifiers=modifiers;_defaultLabel=label;_menu=menu;EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};InstallApplicationEventHandler(Invoked,1,&type,(__bridge void *)self,&_handler);
 [NSUserDefaults.standardUserDefaults registerDefaults:@{[name stringByAppendingString:@"Code"]:@(code),[name stringByAppendingString:@"Modifiers"]:@(modifiers),[name stringByAppendingString:@"Label"]:label}];}return self;
}
- (NSString *)key:(NSString *)suffix {return [_name stringByAppendingString:suffix];}
- (NSString *)label {return [NSUserDefaults.standardUserDefaults stringForKey:[self key:@"Label"]]?:_defaultLabel;}
- (BOOL)registerSaved {
 NSAssert(NSThread.isMainThread,@"hotkeys require main thread");if(_key){UnregisterEventHotKey(_key);_key=NULL;}
 UInt32 code=(UInt32)[NSUserDefaults.standardUserDefaults integerForKey:[self key:@"Code"]],mods=(UInt32)[NSUserDefaults.standardUserDefaults integerForKey:[self key:@"Modifiers"]];
 OSStatus result=_error=RegisterEventHotKey(code,mods,(EventHotKeyID){'SHND',_identifier},GetApplicationEventTarget(),kEventHotKeyExclusive,&_key);
 _status=result==noErr?[NSString stringWithFormat:@"%@ registered. Try it from another app and confirm only Superhound opens.",self.label]:result==eventHotKeyExistsErr?[NSString stringWithFormat:@"%@ is in use by another app. Use %@ in the menu bar, or choose other keys.",self.label,_menu]:[NSString stringWithFormat:@"%@ is unavailable (error %d). Use %@ in the menu bar, change the competing shortcut, then Retry.",self.label,(int)result,_menu];
 return result==noErr;
}
- (BOOL)recordEvent:(NSEvent *)event {
 NSEventModifierFlags flags=event.modifierFlags;UInt32 mods=0;
 if(flags&NSEventModifierFlagCommand)mods|=cmdKey;if(flags&NSEventModifierFlagOption)mods|=optionKey;if(flags&NSEventModifierFlagControl)mods|=controlKey;if(flags&NSEventModifierFlagShift)mods|=shiftKey;
 if(!(mods&(cmdKey|optionKey|controlKey))){_status=@"Use Command, Option, or Control with a key. Bare typing keys are not allowed.";return NO;}
 NSString *key=event.keyCode==49?@"Space":event.charactersIgnoringModifiers.uppercaseString;
 if(!key.length)return NO;
 NSString *label=[NSString stringWithFormat:@"%@%@%@%@%@",mods&controlKey?@"⌃":@"",mods&optionKey?@"⌥":@"",mods&shiftKey?@"⇧":@"",mods&cmdKey?@"⌘":@"",key];
 return [self saveCode:event.keyCode modifiers:mods label:label];
}
- (void)useDefault {[self saveCode:_code modifiers:_modifiers label:_defaultLabel];}
// New keys replace the saved ones only when they register, so a refused or taken shortcut leaves the previous one working.
- (BOOL)saveCode:(UInt32)code modifiers:(UInt32)mods label:(NSString *)label {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
 if(_other && (UInt32)[d integerForKey:[_other key:@"Code"]]==code && (UInt32)[d integerForKey:[_other key:@"Modifiers"]]==mods){_status=[NSString stringWithFormat:@"%@ is the %@ shortcut. Choose other keys.",label,_other->_menu];return NO;}
 NSInteger oldCode=[d integerForKey:[self key:@"Code"]],oldMods=[d integerForKey:[self key:@"Modifiers"]];NSString *oldLabel=self.label;
 [d setInteger:code forKey:[self key:@"Code"]];[d setInteger:mods forKey:[self key:@"Modifiers"]];[d setObject:label forKey:[self key:@"Label"]];
 if([self registerSaved])return YES;
 OSStatus error=_error;[d setInteger:oldCode forKey:[self key:@"Code"]];[d setInteger:oldMods forKey:[self key:@"Modifiers"]];[d setObject:oldLabel forKey:[self key:@"Label"]];
 if([self registerSaved])_status=error==eventHotKeyExistsErr?[NSString stringWithFormat:@"%@ is in use by another app. Superhound keeps %@.",label,oldLabel]:[NSString stringWithFormat:@"%@ is unavailable (error %d). Superhound keeps %@.",label,(int)error,oldLabel];
 return NO;
}
- (void)openKeyboardSettings {
 NSURL *url=[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts"];
 if(![NSWorkspace.sharedWorkspace openURL:url])[NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:@"/System/Applications/System Settings.app"]];
}
- (void)dealloc {if(_key)UnregisterEventHotKey(_key);if(_handler)RemoveEventHandler(_handler);}
@end
