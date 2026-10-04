#import "SHHotKey.h"
#import <Carbon/Carbon.h>
@implementation SHHotKey {EventHotKeyRef _key;EventHandlerRef _handler;}
static OSStatus Invoked(EventHandlerCallRef next,EventRef event,void *context){(void)next;(void)event;SHHotKey *self=(__bridge SHHotKey *)context;if(self.invoked)self.invoked();return noErr;}
- (instancetype)init {
 if((self=[super init])){EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};InstallApplicationEventHandler(Invoked,1,&type,(__bridge void *)self,&_handler);
 [NSUserDefaults.standardUserDefaults registerDefaults:@{@"shortcutCode":@49,@"shortcutModifiers":@(cmdKey),@"shortcutLabel":@"⌘Space"}];}return self;
}
- (NSString *)label {return [NSUserDefaults.standardUserDefaults stringForKey:@"shortcutLabel"]?:@"⌘Space";}
- (BOOL)registerSaved {
 NSAssert(NSThread.isMainThread,@"hotkeys require main thread");if(_key){UnregisterEventHotKey(_key);_key=NULL;}
 UInt32 code=(UInt32)[NSUserDefaults.standardUserDefaults integerForKey:@"shortcutCode"],mods=(UInt32)[NSUserDefaults.standardUserDefaults integerForKey:@"shortcutModifiers"];
 OSStatus result=RegisterEventHotKey(code,mods,(EventHotKeyID){'SHND',1},GetApplicationEventTarget(),kEventHotKeyExclusive,&_key);
 _status=result==noErr?[NSString stringWithFormat:@"%@ registered. Try it from another app and confirm only Superhound opens.",self.label]:[NSString stringWithFormat:@"%@ is unavailable (error %d). Use Search in the menu bar, change the competing shortcut, then Retry.",self.label,(int)result];
 return result==noErr;
}
- (BOOL)recordEvent:(NSEvent *)event {
 NSEventModifierFlags flags=event.modifierFlags;UInt32 mods=0;
 if(flags&NSEventModifierFlagCommand)mods|=cmdKey;if(flags&NSEventModifierFlagOption)mods|=optionKey;if(flags&NSEventModifierFlagControl)mods|=controlKey;if(flags&NSEventModifierFlagShift)mods|=shiftKey;
 if(!(mods&(cmdKey|optionKey|controlKey))){_status=@"Use Command, Option, or Control with a key. Bare typing keys are not allowed.";return NO;}
 NSString *key=event.keyCode==49?@"Space":event.charactersIgnoringModifiers.uppercaseString;
 if(!key.length)return NO;
 NSString *label=[NSString stringWithFormat:@"%@%@%@%@%@",mods&controlKey?@"⌃":@"",mods&optionKey?@"⌥":@"",mods&shiftKey?@"⇧":@"",mods&cmdKey?@"⌘":@"",key];
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d setInteger:event.keyCode forKey:@"shortcutCode"];[d setInteger:mods forKey:@"shortcutModifiers"];[d setObject:label forKey:@"shortcutLabel"];return [self registerSaved];
}
- (void)useDefault {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d setInteger:49 forKey:@"shortcutCode"];[d setInteger:cmdKey forKey:@"shortcutModifiers"];[d setObject:@"⌘Space" forKey:@"shortcutLabel"];[self registerSaved];}
- (void)openKeyboardSettings {
 NSURL *url=[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts"];
 if(![NSWorkspace.sharedWorkspace openURL:url])[NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:@"/System/Applications/System Settings.app"]];
}
- (void)dealloc {if(_key)UnregisterEventHotKey(_key);if(_handler)RemoveEventHandler(_handler);}
@end
